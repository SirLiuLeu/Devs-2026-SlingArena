--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingMovement = require(script.Parent.SlingMovement)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local LaunchMotionModel = require(script.Parent.LaunchMotionModel)

local LAUNCH_VALIDATION_GRACE_SECONDS = 0.15

local SlingService = {}
SlingService.__index = SlingService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function sanitizeNumber(value: number, fallback: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

function SlingService.CalculateChargeRatio(chargeStartTime: number, nowTime: number, maxChargeTime: number): number
	local safeDuration = math.max(0.001, sanitizeNumber(maxChargeTime, 0.001))
	local elapsed = math.max(0, sanitizeNumber(nowTime, 0) - sanitizeNumber(chargeStartTime, 0))
	return math.clamp(elapsed / safeDuration, 0, 1)
end

function SlingService.ResolveAimDirection(aimDirection: Vector3): Vector3
	local planarDirection = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	if planarDirection.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return planarDirection.Unit
end

function SlingService.ResolveLaunchDirectionFromRoot(root: BasePart): Vector3
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return forward.Unit
end

function SlingService.ResolveLaunchDirection(root: BasePart, aimDirection: Vector3?): Vector3
	if typeof(aimDirection) == "Vector3" then
		return SlingService.ResolveAimDirection(aimDirection)
	end
	return SlingService.ResolveLaunchDirectionFromRoot(root)
end

local function applyRootPhysicalProperties(root: BasePart)
	local physical = PhysicsConfig.PhysicalProperties
	root.CustomPhysicalProperties = PhysicalProperties.new(
		physical.Density,
		physical.Friction,
		physical.Elasticity,
		physical.FrictionWeight,
		physical.ElasticityWeight
	)
end

function SlingService.BuildLaunchVector(direction: Vector3, launchForce: number): Vector3
	local safeDirection = if direction.Magnitude < 0.01 then Vector3.new(0, 0, -1) else direction.Unit
	local safeForce = math.max(0, sanitizeNumber(launchForce, 0))
	local launchVector = safeDirection * safeForce
	if launchVector.X ~= launchVector.X or launchVector.Y ~= launchVector.Y or launchVector.Z ~= launchVector.Z then
		return Vector3.zero
	end
	return launchVector
end

function SlingService.GetCooldownRemaining(cooldownEndTime: number, nowTime: number): number
	local remaining = sanitizeNumber(cooldownEndTime, 0) - sanitizeNumber(nowTime, 0)
	return math.max(0, remaining)
end

function SlingService.BuildCooldownUiState(cooldownEndTime: number, nowTime: number): { CooldownRemaining: number }
	return {
		CooldownRemaining = SlingService.GetCooldownRemaining(cooldownEndTime, nowTime),
	}
end

local MOVEMENT_STATE = GameStates.PlayerState

function SlingService.new(context)
	local self = setmetatable({}, SlingService)
	self._context = context
	self._input = {}
	self._moveRateState = {}
	self._chargeState = {}
	self._releaseCooldown = {}
	self._releaseState = {}
	self._movementControllers = {}
	self._remoteConnections = {}
	self._heartbeatConnection = nil
	self._warnedInvalidRoot = {}
	self._loggedControllerRoot = {}
	self._aimTargets = {}
	self._launchVelocityControllers = {}
	self._activeLaunches = {}
	return self
end

local function resolveAlignOrientation(root: BasePart): AlignOrientation?
	local alignOrientation = root:FindFirstChild("AlignOrientation")
	if alignOrientation and alignOrientation:IsA("AlignOrientation") then
		return alignOrientation
	end
	return nil
end

function SlingService:_restoreLaunchVelocityControllers(player: Player)
	local controllerInfos = self._launchVelocityControllers[player]
	if not controllerInfos then
		return
	end
	for _, controllerInfo in ipairs(controllerInfos) do
		local controller = controllerInfo.instance
		if controller and controller.Parent and controller:IsA("LinearVelocity") then
			controller.Enabled = controllerInfo.enabled
		end
	end
	self._launchVelocityControllers[player] = nil
end

function SlingService:_prepareRootForLaunch(player: Player, root: BasePart)
	local movementController = self._movementControllers[player]
	if movementController then
		movementController:DisableLocomotion(true)
	end

	self:_restoreLaunchVelocityControllers(player)
	local velocityControllers = {}
	for _, controller in ipairs(root:GetDescendants()) do
		if controller:IsA("LinearVelocity") then
			table.insert(velocityControllers, {
				instance = controller,
				enabled = controller.Enabled,
			})
			if controller.VelocityConstraintMode == Enum.VelocityConstraintMode.Plane then
				controller.PlaneVelocity = Vector2.zero
			elseif controller.VelocityConstraintMode == Enum.VelocityConstraintMode.Line then
				controller.LineVelocity = 0
			else
				controller.VectorVelocity = Vector3.zero
			end
			controller.Enabled = false
		end
	end
	self._launchVelocityControllers[player] = velocityControllers

	-- Keep launch and transferred recoil server-authoritative so all clients see the
	-- same collision result, and so client-owned locomotion constraints cannot fight it.
	root:SetNetworkOwner(nil)
end

function SlingService:_getTrackedPlayers(): { any }
	local trackedPlayers = {}
	local seen = {}

	local stateService = getService(self._context, "PlayerStateService")
	if stateService and typeof(stateService.GetAllStates) == "function" then
		for player in pairs(stateService:GetAllStates()) do
			if not seen[player] then
				seen[player] = true
				table.insert(trackedPlayers, player)
			end
		end
	end

	for player in pairs(self._input) do
		if not seen[player] then
			seen[player] = true
			table.insert(trackedPlayers, player)
		end
	end

	for player in pairs(self._chargeState) do
		if not seen[player] then
			seen[player] = true
			table.insert(trackedPlayers, player)
		end
	end

	for player in pairs(self._releaseState) do
		if not seen[player] then
			seen[player] = true
			table.insert(trackedPlayers, player)
		end
	end

	if #trackedPlayers == 0 then
		for _, player in Players:GetPlayers() do
			if not seen[player] then
				seen[player] = true
				table.insert(trackedPlayers, player)
			end
		end
	end

	return trackedPlayers
end

function SlingService:Init()
	local remotes = self._context.Remotes
	local startChargeRemote = remotes:FindFirstChild(RemoteContracts.Names.StartCharge)
	local releaseChargeRemote = remotes:FindFirstChild(RemoteContracts.Names.ReleaseCharge)
	local moveRequestRemote = remotes:FindFirstChild(RemoteContracts.Names.MoveRequest)

	if startChargeRemote and startChargeRemote:IsA("RemoteEvent") then
		self._remoteConnections.StartCharge = startChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
			self:StartCharge(player, aimTarget)
		end)
	else
		warn(string.format("[SlingService] Missing remote %s; charge-start listener disabled.", RemoteContracts.Names.StartCharge))
	end

	if releaseChargeRemote and releaseChargeRemote:IsA("RemoteEvent") then
		self._remoteConnections.ReleaseCharge = releaseChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
			self:ReleaseCharge(player, aimTarget)
		end)
	else
		warn(string.format("[SlingService] Missing remote %s; charge-release listener disabled.", RemoteContracts.Names.ReleaseCharge))
	end

	if moveRequestRemote and moveRequestRemote:IsA("RemoteEvent") then
		self._remoteConnections.MoveRequest = moveRequestRemote.OnServerEvent:Connect(function(player, direction, aimTarget)
			self:HandleMoveRequest(player, direction, aimTarget)
		end)
	else
		warn(string.format("[SlingService] Missing remote %s; movement listener disabled.", RemoteContracts.Names.MoveRequest))
	end

	Players.PlayerRemoving:Connect(function(player)
		self._input[player] = nil
		self._moveRateState[player] = nil
		self._chargeState[player] = nil
		self._releaseCooldown[player] = nil
		self._releaseState[player] = nil
		self._activeLaunches[player] = nil
		self._warnedInvalidRoot[player] = nil
		self._loggedControllerRoot[player] = nil
		self._aimTargets[player] = nil
		self._launchVelocityControllers[player] = nil
		local movementController = self._movementControllers[player]
		if movementController then
			movementController:Destroy()
			self._movementControllers[player] = nil
		end
	end)
end

function SlingService:_resolvePawnAndRoot(player: Player): (Model?, BasePart?)
	local playerService = self._context.Services.PlayerService
	local pawn = player.Character
	if not (pawn and pawn:IsA("Model")) and playerService then
		pawn = playerService:GetPawn(player)
	end
	if not (pawn and pawn:IsA("Model")) then
		return nil, nil
	end

	if player.Character ~= pawn then
		player.Character = pawn
	end

	local root = pawn:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox", true)
	end
	if root and root:IsA("BasePart") then
		if pawn.PrimaryPart == nil then
			pawn.PrimaryPart = root
		end
		applyRootPhysicalProperties(root)
		return pawn, root
	end
	return pawn, nil
end

function SlingService:GetLaunchState(player: Player): any?
	return self._activeLaunches[player]
end

function SlingService:SetLaunchState(player: Player, launchState: any?)
	player:SetAttribute("LaunchValidationGraceEndsAt", 0)
	local root = self._context.Services.PlayerService:GetRoot(player)
	if root then
		if launchState then
			self:_prepareRootForLaunch(player, root)
		else
			self:_restoreLaunchVelocityControllers(player)
		end
	end
	self._activeLaunches[player] = launchState
end

function SlingService:Start()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self:_stepMovement(dt)
		self:_stepMovementStates()
	end)
end

function SlingService:_isRoundPlaying(): boolean
	local roundService = getService(self._context, "RoundService")
	if not roundService then
		return false
	end
	local roundState = roundService:GetState()
	return roundState == GameStates.MapRoundState.EarlyGame or roundState == GameStates.MapRoundState.FinalPhase
end

function SlingService:_canControl(player: Player): boolean
	local roundService = getService(self._context, "RoundService")
	local playerService = getService(self._context, "PlayerService")
	local stateService = getService(self._context, "PlayerStateService")
	if not roundService or not playerService or not stateService then
		return false
	end
	local roundState = roundService:GetState()
	local canControlForRound = false
	if roundState == GameStates.MapRoundState.Awaits
		or roundState == GameStates.MapRoundState.EarlyGame
		or roundState == GameStates.MapRoundState.FinalPhase
	then
		canControlForRound = roundService:IsPlayerQueued(player)
	elseif roundState == GameStates.MapRoundState.Lobby then
		canControlForRound = true
	end
	if not canControlForRound then
		return false
	end
	if not playerService:IsAlive(player) then
		return false
	end
	if stateService:IsStunned(player) then
		return false
	end
	return true
end

function SlingService:HandleMoveRequest(player: Player, moveInput: Vector3, aimDirection: Vector3?)
	if typeof(moveInput) ~= "Vector3" then
		return
	end

	local now = os.clock()
	local lastEventAt = self._moveRateState[player]
	if lastEventAt and (now - lastEventAt) < 0.03 then
		return
	end

	if not RemoteContracts.Validate(RemoteContracts.Names.MoveRequest, moveInput) then
		return
	end
	if not self:_canControl(player) then
		self._input[player] = Vector3.zero
		return
	end

	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state or state.IsTeleporting then
		self._input[player] = Vector3.zero
		return
	end
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == "Recovering" then
		self._input[player] = Vector3.zero
		return
	end

	local planar = Vector3.new(moveInput.X, 0, moveInput.Z)
	self._input[player] = if planar.Magnitude > 1 then planar.Unit else planar
	if typeof(aimDirection) == "Vector3" then
		local planarAim = Vector3.new(aimDirection.X, 0, aimDirection.Z)
		if planarAim.Magnitude > 0.001 then
			self._aimTargets[player] = planarAim.Unit
		end
	end
	self._moveRateState[player] = now
end

function SlingService:StartCharge(player: Player, aimDirection: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.StartCharge, aimDirection) then
		return
	end
	if not self:_canControl(player) then
		return
	end

	local now = os.clock()
	local cooldownUntil = self._releaseCooldown[player] or 0
	if now < cooldownUntil then
		return
	end

	local _, root = self:_resolvePawnAndRoot(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not root or not state then
		return
	end
	if state.MovementState == MOVEMENT_STATE.Charging
		or state.MovementState == "Launching"
		or state.MovementState == "Recovering"
	then
		return
	end
	if self._chargeState[player] then
		return
	end

	local direction = SlingService.ResolveLaunchDirection(root, aimDirection)

	self._chargeState[player] = {
		chargeStartTime = now,
		aimDirection = direction,
	}
	self._aimTargets[player] = direction
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
	self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Charging)
	self._context.EventBus:Fire("ChargeStarted", player)
end

function SlingService:ReleaseCharge(player: Player, aimDirection: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.ReleaseCharge, aimDirection) then
		return
	end
	if not self:_canControl(player) then
		return
	end
	local chargeState = self._chargeState[player]
	if not chargeState then
		return
	end
	local _, root = self:_resolvePawnAndRoot(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not root or not state then
		self._chargeState[player] = nil
		return
	end
	if not root:IsA("BasePart") then
		self._chargeState[player] = nil
		return
	end
	if root.Anchored then
		self._chargeState[player] = nil
		return
	end
	local mass = root.AssemblyMass
	if mass <= 0 then
		self._chargeState[player] = nil
		return
	end

	local chargeRatio = LaunchMotionModel.ComputeChargeRatio(chargeState.chargeStartTime, os.clock())

	local launchDirectionPlanar = chargeState.aimDirection
	if typeof(aimDirection) == "Vector3" then
		local providedDirection = SlingService.ResolveAimDirection(aimDirection)
		if providedDirection.Magnitude >= 0.01 then
			launchDirectionPlanar = providedDirection
		end
	end
	chargeState.aimDirection = launchDirectionPlanar
	self._aimTargets[player] = launchDirectionPlanar

	local now = os.clock()
	local launchState = LaunchMotionModel.BuildState(launchDirectionPlanar, chargeRatio, now, player)

	self:_prepareRootForLaunch(player, root)

	-- Stamp the initial velocity. This is the ONLY direct AssemblyLinearVelocity write
	-- at launch start. After this, _stepMovementStates() decays speed but no longer
	-- continuously overwrites velocity — it only corrects the speed magnitude, preserving
	-- collision-modified direction (see _stepMovementStates comments below).
	local launchVelocity = Vector3.new(
		launchDirectionPlanar.X * launchState.initialSpeed,
		root.AssemblyLinearVelocity.Y,
		launchDirectionPlanar.Z * launchState.initialSpeed
	)
	root.AssemblyLinearVelocity = launchVelocity
	player:SetAttribute("LaunchValidationGraceEndsAt", 0)

	self._activeLaunches[player] = launchState
	warn(string.format("[SlingService] Launch player=%s charge=%.2f speed=%.2f energy=%.2f",
		player.Name, chargeRatio, launchState.initialSpeed, launchState.energy))

	state.CurrentVelocity = root.AssemblyLinearVelocity
	self._context.Services.PlayerStateService:SetCharging(player, false, chargeRatio)
	self._context.Services.PlayerStateService:SetMovementState(player, "Launching")
	warn(string.format("[SlingService] State player=%s -> Launching", player.Name))
	self._context.EventBus:Fire("SlingLaunched", player, chargeRatio, launchState)

	if chargeRatio >= 0.999 then
		self._context.EventBus:Fire("MaxChargeReleased", player, BalanceConfig.MaxChargeSelfDamage)
	end

	self._chargeState[player] = nil
	self._releaseState[player] = { releaseStartTime = now }

	-- CHANGED: Fixed cooldown end time. Old code set it to 0 and then computed
	-- recovery = launch duration in _stepMovementStates, making full-charge launches
	-- very punishing. Now recovery is always RecoveryDuration (0.4 s).
	self._releaseCooldown[player] = 0
	self._context.Services.PlayerStateService:SetLastReleaseDuration(player, 0)
	self._context.Services.PlayerStateService:SetCooldownEndTime(player, 0)
end

function SlingService:_applyAimRotation(player: Player, root: BasePart, input: Vector3, _dt: number)
	local alignOrientation = resolveAlignOrientation(root)
	if not alignOrientation then
		return
	end
	local aimDirection = self._aimTargets[player]
	local desiredPlanar = Vector3.zero
	if typeof(aimDirection) == "Vector3" then
		desiredPlanar = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	end
	if desiredPlanar.Magnitude < 0.01 then
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if forward.Magnitude > 0.01 then
			desiredPlanar = forward.Unit
		elseif input.Magnitude > 0.01 then
			desiredPlanar = input.Unit
		end
	end
	if desiredPlanar.Magnitude < 0.01 then
		return
	end
	alignOrientation.CFrame = CFrame.lookAt(root.Position, root.Position + desiredPlanar.Unit, Vector3.yAxis)
end

function SlingService:_stepMovement(dt: number)
	for _, player in self:_getTrackedPlayers() do
		local root = self._context.Services.PlayerService:GetRoot(player)
		local input = self._input[player] or Vector3.zero
		if root then
			self:_applyRootVelocity(player, root, input, dt)
		else
			local movementController = self._movementControllers[player]
			if movementController then
				movementController:Destroy()
				self._movementControllers[player] = nil
			end
		end
	end
end

function SlingService:_getMovementController(player: Player, root: BasePart)
	local movementController = self._movementControllers[player]
	if movementController and movementController._root ~= root then
		movementController:Destroy()
		movementController = nil
	end
	if not movementController then
		movementController = SlingMovement.new(root)
		warn(string.format("[SlingService] movementController ready player=%s root=%s", player.Name, root:GetFullName()))
		self._movementControllers[player] = movementController
	end
	return movementController
end

function SlingService:_applyRootVelocity(player: Player, root: BasePart, input: Vector3, dt: number)
	if root.Anchored then
		root.Anchored = false
		if root.Anchored then
			if not self._warnedInvalidRoot[player] then
				self._warnedInvalidRoot[player] = true
				warn(string.format("[SlingService] Root anchored; movement blocked for %s (%s)",
					player.Name, root:GetFullName()))
			end
			return
		end
	end

	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	if state.MovementState ~= "Launching" then
		self:_restoreLaunchVelocityControllers(player)
	end
	self._warnedInvalidRoot[player] = nil

	if state.MovementState == "Launching" then
		-- Server owns during launch; do not return ownership to client here.
		-- Aim rotation still updates so the pawn faces the travel direction.
		self:_applyAimRotation(player, root, input, dt)
		return
	end

	-- Return ownership to client when not launching.
	if root:GetNetworkOwner() ~= player then
		root:SetNetworkOwner(player)
		if not self._loggedControllerRoot[player] then
			self._loggedControllerRoot[player] = true
			warn(string.format("[SlingService] SetNetworkOwner player=%s root=%s", player.Name, root:GetFullName()))
		end
	end

	local movementController = self:_getMovementController(player, root)
	local moveDirection = Vector3.zero
	if input.Magnitude > 0.001 then
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
		if forward.Magnitude > 0.001 and right.Magnitude > 0.001 then
			moveDirection = (forward.Unit * input.Z) + (right.Unit * input.X)
		end
	end

	if state.MovementState == MOVEMENT_STATE.Charging then
		movementController:DisableLocomotion(false)
		return
	end
	if state.MovementState == "Recovering" then
		movementController:DisableLocomotion(false)
		self:_applyAimRotation(player, root, input, dt)
		return
	end

	if moveDirection.Magnitude < 0.001 then
		local speed = math.max(state.MoveSpeed or PhysicsConfig.Movement.MoveSpeed, 0)
		local slowFlag = state.ActiveFlags and state.ActiveFlags.Slow
		if slowFlag then
			speed *= math.max(0, 1 - (0.25 * math.max(1, slowFlag.Stacks or 1)))
		end
		movementController:SetSpeed(speed)
		movementController:Move(Vector3.zero, dt)
		self:_applyAimRotation(player, root, input, dt)
		if state.MovementState ~= MOVEMENT_STATE.Idle then
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
		end
		return
	end

	local speed = math.max(state.MoveSpeed or PhysicsConfig.Movement.MoveSpeed, 0)
	local slowFlag = state.ActiveFlags and state.ActiveFlags.Slow
	if slowFlag then
		speed *= math.max(0, 1 - (0.25 * math.max(1, slowFlag.Stacks or 1)))
	end
	movementController:SetSpeed(speed)
	movementController:Move(moveDirection.Unit, dt)
	self:_applyAimRotation(player, root, input, dt)
	if state.MovementState ~= MOVEMENT_STATE.Moving then
		self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Moving)
	end
end

--[[
	CHANGED: Launch velocity management during flight.

	OLD behaviour (the "tốc biến" problem):
	  Every Heartbeat, the server would:
	    1. Read AssemblyLinearVelocity
	    2. Get the speed from LaunchMotionModel.Sample()
	    3. Write root.AssemblyLinearVelocity = direction.Unit * decayedSpeed
	  This stamped a brand new vector every frame, overriding any direction change
	  caused by collision recoil, wall bounce, or the physics engine.
	  The result was that collisions felt nullified — the pawn resumed its original
	  direction on the very next frame.

	NEW behaviour:
	  - Read the ACTUAL AssemblyLinearVelocity from the physics engine.
	  - Extract horizontal speed from it (preserving whatever direction physics chose).
	  - Apply decay to that speed value only.
	  - Scale the existing velocity vector by (decayedSpeed / currentSpeed) so
	    direction is fully preserved and only the magnitude is controlled.
	  - The server only corrects speed, not direction.
	  - CollisionService._applyDragAndBounce() now skips Launching players,
	    so this is the single decay authority.
]]
function SlingService:_stepMovementStates()
	for _, player in self:_getTrackedPlayers() do
		local state = self._context.Services.PlayerStateService:GetState(player)
		local root = self._context.Services.PlayerService:GetRoot(player)
		if not (state and root) then
			continue
		end

		local now = os.clock()
		local launchState = self._activeLaunches[player]
		local fullVelocity = root.AssemblyLinearVelocity
		local horizontalVelocity = Vector3.new(fullVelocity.X, 0, fullVelocity.Z)
		local horizontalSpeed = horizontalVelocity.Magnitude

		if state.MovementState == "Launching" and launchState then
			-- Sample decay to get the target speed this frame.
			local targetSpeed, sampledEnergy = LaunchMotionModel.Sample(launchState, now, horizontalVelocity)
			launchState.currentSpeed = targetSpeed
			launchState.energy = sampledEnergy

			-- Clamp speed to configured max (handles post-collision spikes).
			targetSpeed = math.min(targetSpeed, PhysicsConfig.Launch.SpeedMax)

			if horizontalSpeed > 0.001 then
				-- Scale the existing velocity vector by (targetSpeed / horizontalSpeed).
				-- This preserves whatever direction Roblox physics chose (including
				-- collision normals, wall reflections, etc.) and only controls magnitude.
				local scale = targetSpeed / horizontalSpeed
				local scaledHorizontal = horizontalVelocity * scale
				local nextVelocity = Vector3.new(
					scaledHorizontal.X,
					fullVelocity.Y,
					scaledHorizontal.Z
				)
				root.AssemblyLinearVelocity = nextVelocity
				fullVelocity = nextVelocity
				horizontalVelocity = scaledHorizontal
				horizontalSpeed = scaledHorizontal.Magnitude
				launchState.direction = horizontalVelocity.Unit
			else
				-- No horizontal movement — zero it cleanly.
				local nextVelocity = Vector3.new(0, fullVelocity.Y, 0)
				root.AssemblyLinearVelocity = nextVelocity
				fullVelocity = nextVelocity
				horizontalVelocity = Vector3.zero
				horizontalSpeed = 0
			end
			state.CurrentVelocity = fullVelocity
		end

		-- CHANGED: StopSpeed raised from 0.5 → 2 (from PhysicsConfig.Launch.StopSpeed).
		-- Old: pawn drifted for a long time at very low speed before stopping.
		-- New: clean commit to stop when below 2 studs/s.
		local stopThreshold = PhysicsConfig.Launch.StopSpeed -- 2.0
		local graceExpired = not launchState
			or now >= ((launchState.startTime or now) + LAUNCH_VALIDATION_GRACE_SECONDS)

		if state.MovementState == "Launching" and graceExpired
			and (horizontalSpeed <= stopThreshold or (launchState and launchState.energy <= 0))
		then
			self:_restoreLaunchVelocityControllers(player)

			-- CHANGED: Fixed recovery duration.
			-- Old: recovery = however long the launch lasted → full-charge = long recovery.
			-- New: always PhysicsConfig.Launch.RecoveryDuration (0.4 s).
			local recoveryEnd = now + PhysicsConfig.Launch.RecoveryDuration
			self._releaseCooldown[player] = recoveryEnd
			self._context.Services.PlayerStateService:SetLastReleaseDuration(
				player, PhysicsConfig.Launch.RecoveryDuration)
			self._context.Services.PlayerStateService:SetCooldownEndTime(player, recoveryEnd)
			player:SetAttribute("LaunchValidationGraceEndsAt", now + LAUNCH_VALIDATION_GRACE_SECONDS)
			self._context.Services.PlayerStateService:SetMovementState(player, "Recovering")
			warn(string.format("[SlingService] State player=%s -> Recovering (horizontal=%.2f)",
				player.Name, horizontalSpeed))

		elseif state.MovementState == "Recovering" and now >= (self._releaseCooldown[player] or 0) then
			self._releaseState[player] = nil
			self._activeLaunches[player] = nil
			player:SetAttribute("LaunchValidationGraceEndsAt", 0)
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
			self._context.Services.PlayerStateService:SetCooldownEndTime(player, 0)
			self._context.Services.PlayerStateService:SetLastReleaseDuration(player, 0)
		end
	end
end

return SlingService
