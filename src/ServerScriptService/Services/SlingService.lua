--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingMovement = require(script.Parent.SlingMovement)
local PhysicsConfig = require(script.Parent.Parent.Config.PhysicsConfig)

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

function SlingService.ResolveAimDirection(origin: Vector3, aimTarget: Vector3): Vector3
	local rawDirection = aimTarget - origin
	if rawDirection.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return rawDirection.Unit
end

function SlingService.ResolveLaunchDirectionFromRoot(root: BasePart): Vector3
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return forward.Unit
end

function SlingService.ResolveLaunchDirection(root: BasePart, aimTarget: Vector3?): Vector3
	if typeof(aimTarget) == "Vector3" then
		local aimDirection = SlingService.ResolveAimDirection(root.Position, aimTarget)
		local planarAim = Vector3.new(aimDirection.X, 0, aimDirection.Z)
		if planarAim.Magnitude >= 0.01 then
			return planarAim.Unit
		end
	end
	return SlingService.ResolveLaunchDirectionFromRoot(root)
end

local function applyRootPhysicalProperties(root: BasePart)
	local physical = PhysicsConfig.PhysicalProperties
	local elasticity = if PhysicsConfig.Stability.ZeroElasticity then 0 else physical.Elasticity
	root.CustomPhysicalProperties = PhysicalProperties.new(
		physical.Density,
		physical.Friction,
		elasticity,
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

local MOVEMENT_STATE = GameStates.Movement

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
		root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox")
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
	return roundService and roundService:GetState() == GameStates.Round.ActiveRound or false
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
	if roundState == GameStates.Round.ActiveRound then
		canControlForRound = roundService:IsPlayerQueued(player)
	elseif roundState == GameStates.Round.Lobby then
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
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Recovering then
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

function SlingService:StartCharge(player: Player, aimTarget: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.StartCharge, aimTarget) then
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
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Launched or state.MovementState == MOVEMENT_STATE.Recovering then
		return
	end
	if self._chargeState[player] then
		return
	end

	local direction = SlingService.ResolveLaunchDirection(root, aimTarget)

	self._chargeState[player] = {
		chargeStartTime = now,
		aimDirection = direction,
	}
	self._aimTargets[player] = direction
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
	self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Charging)
	self._context.EventBus:Fire("ChargeStarted", player)
end

function SlingService:ReleaseCharge(player: Player, aimTarget: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.ReleaseCharge, aimTarget) then
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

	local maxChargeTime = math.max(0.001, PhysicsConfig.Charge.MaxChargeTime)
	local chargeRatio = SlingService.CalculateChargeRatio(chargeState.chargeStartTime, os.clock(), maxChargeTime)

	local launchDirectionPlanar = SlingService.ResolveLaunchDirection(root, aimTarget)
	chargeState.aimDirection = launchDirectionPlanar
	self._aimTargets[player] = launchDirectionPlanar

	local minForce = math.max(0, PhysicsConfig.Charge.MinForce)
	local maxForce = math.max(minForce, PhysicsConfig.Charge.MaxForce)
	local chargeForce = minForce + ((maxForce - minForce) * chargeRatio)
	local launchForce = math.max(10, chargeForce * math.max(0, PhysicsConfig.Charge.ChargeForceMultiplier))
	local launchVector = SlingService.BuildLaunchVector(launchDirectionPlanar, launchForce)
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
			controller.VectorVelocity = Vector3.zero
			controller.Enabled = false
		end
	end
	self._launchVelocityControllers[player] = velocityControllers

	root:SetNetworkOwner(nil)
	root:ApplyImpulse(launchVector * mass)
	print("Before:", root.AssemblyLinearVelocity)

task.delay(0.1, function()
    print("After 0.1s:", root.AssemblyLinearVelocity)
end)

	state.CurrentVelocity = root.AssemblyLinearVelocity
	self._context.Services.PlayerStateService:SetCharging(player, false, chargeRatio)
	self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Launched)
	self._context.EventBus:Fire("SlingLaunched", player, chargeRatio, launchVector)

	if chargeRatio >= 0.999 then
		self._context.EventBus:Fire("MaxChargeReleased", player, BalanceConfig.MaxChargeSelfDamage)
	end

	self._chargeState[player] = nil
	self._releaseState[player] = {
		releaseStartTime = os.clock(),
	}
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
				warn(string.format("[SlingService] Root anchored; movement blocked for %s (%s)", player.Name, root:GetFullName()))
			end
			return
		end
	end

	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	if state.MovementState ~= MOVEMENT_STATE.Launched then
		self:_restoreLaunchVelocityControllers(player)
	end
	self._warnedInvalidRoot[player] = nil
	if state.MovementState == MOVEMENT_STATE.Launched then
		root:SetNetworkOwner(nil)
	else
		if root:GetNetworkOwner() ~= player then
			root:SetNetworkOwner(player)
			if not self._loggedControllerRoot[player] then
				self._loggedControllerRoot[player] = true
				warn(string.format("[SlingService] SetNetworkOwner player=%s root=%s", player.Name, root:GetFullName()))
			end
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

	if state.MovementState == MOVEMENT_STATE.Launched then
		-- Preserve launch momentum. We only disable the locomotion actuator so it does not
		-- counteract release velocity and create an artificial "drag/stretch" feeling.
		movementController:DisableLocomotion(true)
		self:_applyAimRotation(player, root, input, dt)
		return
	end
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Recovering then
		movementController:DisableLocomotion(false)
		self:_applyAimRotation(player, root, input, dt)
		return
	end

	if moveDirection.Magnitude < 0.001 then
		movementController:SetSpeed(math.max(PhysicsConfig.Movement.MoveSpeed, 0))
		movementController:Move(Vector3.zero, dt)
		self:_applyAimRotation(player, root, input, dt)
		if state.MovementState ~= MOVEMENT_STATE.Idle then
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
		end
		return
	end

	movementController:SetSpeed(math.max(PhysicsConfig.Movement.MoveSpeed, 0))
	movementController:Move(moveDirection.Unit, dt)
	self:_applyAimRotation(player, root, input, dt)
	if state.MovementState ~= MOVEMENT_STATE.Moving then
		self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Moving)
	end
end

function SlingService:_stepMovementStates()
	for _, player in self:_getTrackedPlayers() do
		local state = self._context.Services.PlayerStateService:GetState(player)
		local root = self._context.Services.PlayerService:GetRoot(player)
		if state and root then
			local now = os.clock()
			local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			if state.MovementState == MOVEMENT_STATE.Launched and horizontal <= BalanceConfig.VelocityStopThreshold then
				self:_restoreLaunchVelocityControllers(player)
				local releaseState = self._releaseState[player]
				local releaseDuration = 0
				if releaseState and typeof(releaseState.releaseStartTime) == "number" then
					releaseDuration = math.max(0, now - releaseState.releaseStartTime)
				end
				self._releaseCooldown[player] = now + releaseDuration
				self._context.Services.PlayerStateService:SetLastReleaseDuration(player, releaseDuration)
				self._context.Services.PlayerStateService:SetCooldownEndTime(player, self._releaseCooldown[player])
				self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Recovering)
			elseif state.MovementState == MOVEMENT_STATE.Recovering and now >= (self._releaseCooldown[player] or 0) then
				self._releaseState[player] = nil
				self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
				self._context.Services.PlayerStateService:SetCooldownEndTime(player, 0)
				self._context.Services.PlayerStateService:SetLastReleaseDuration(player, 0)
			end
		end
	end
end

return SlingService
