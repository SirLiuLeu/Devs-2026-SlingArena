--!strict
-- FIX SUMMARY (tele/snap nhìn từ PlayerB):
--
-- [FIX 1] KHÔNG transfer NetworkOwner về server khi Launch.
--   Trước: root:SetNetworkOwner(nil) → server own → PlayerB thấy freeze 1-4 frames rồi snap.
--   Sau:   Giữ nguyên player own suốt launch → replication path giống movement bình thường.
--
-- [FIX 2] Client-authoritative impulse; server enforces only decay/clamp.
--   Server no longer applies the initial impulse to a player-owned root.
--   Client applies the launch impulse locally, then server scales down excessive
--   horizontal speed using LaunchMotionModel.Sample().
--
-- [FIX 3] Smooth stop thay vì instant-zero velocity.
--   Trước: root.AssemblyLinearVelocity = Vector3.new(0, y, 0) → snap rõ nhất với PlayerB.
--   Sau:   Áp dụng brake factor mạnh (15/s) trong vài frame cho đến khi dừng hẳn.
--
-- [FIX 4] Bỏ lưu/restore LinearVelocity controllers khi launch (không cần vì không own server nữa).
--   MovementController vẫn bị DisableLocomotion để WASD không fight launch momentum.
--
-- [BUG FIX - State machine premature Idle transition]:
--   ROOT CAUSE: _stepMovementStates called LaunchMotionModel.Sample(launchState, now, horizontalVelocity)
--   where horizontalVelocity is read from root.AssemblyLinearVelocity on the SERVER.
--   Because the root is CLIENT-OWNED (FIX 1), the server's physics view of velocity
--   lags by network RTT. Immediately after ReleaseCharge, the server reads velocity≈0,
--   LaunchMotionModel.Sample returns speed=0, shouldStop triggers immediately, and the
--   state transitions to Recovering/Idle — BEFORE the food hit report even arrives.
--   FIX: _stepMovementStates uses time-based speed decay from launchState.initialSpeed
--   (computed at launch time) rather than reading root.AssemblyLinearVelocity as the
--   authoritative speed for decay/stop decisions. The server velocity is only used to
--   CLAMP from above (cap excessive speed) — never to drive the energy counter or stop trigger.
--   launchState.currentSpeed is now maintained purely by the decay model, not physics reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingMovement = require(script.Parent.SlingMovement)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local LaunchMotionModel = require(script.Parent.LaunchMotionModel)

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

function SlingService.ResolveAimDirection(aimDirection: Vector3): Vector3
	local planarDirection = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	if planarDirection.Magnitude < PhysicsConfig.Movement.AimDeadzone then
		return Vector3.new(0, 0, -1)
	end
	return planarDirection.Unit
end

function SlingService.ResolveLaunchDirectionFromRoot(root: BasePart): Vector3
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < PhysicsConfig.Movement.AimDeadzone then
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
local LAUNCH_BRAKE_RATE = 15

function SlingService.new(context)
	local self = setmetatable({}, SlingService)
	self._context = context
	self._input = {}
	self._moveRateState = {}
	self._chargeState = {}
	self._releaseCooldown = {}
	self._movementControllers = {}
	self._remoteConnections = {}
	self._clientDoLaunchRemote = nil :: RemoteEvent?
	self._heartbeatConnection = nil
	self._warnedInvalidRoot = {}
	self._loggedControllerRoot = {}
	self._aimTargets = {}
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
	local clientDoLaunchRemote = remotes:FindFirstChild(RemoteContracts.Names.ClientDoLaunch)

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

	if clientDoLaunchRemote and clientDoLaunchRemote:IsA("RemoteEvent") then
		self._clientDoLaunchRemote = clientDoLaunchRemote
	else
		warn(string.format("[SlingService] Missing remote %s; client launch impulse disabled.", RemoteContracts.Names.ClientDoLaunch))
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
		self._activeLaunches[player] = nil
		self._warnedInvalidRoot[player] = nil
		self._loggedControllerRoot[player] = nil
		self._aimTargets[player] = nil
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
	self._activeLaunches[player] = launchState
end

function SlingService:Start()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self:_stepMovement(dt)
		self:_stepMovementStates(dt)
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
	if lastEventAt and (now - lastEventAt) < PhysicsConfig.Movement.MoveRequestCooldown then
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
		if planarAim.Magnitude > PhysicsConfig.Movement.InputDeadzone then
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
		if providedDirection.Magnitude >= PhysicsConfig.Launch.DirectionDeadzone then
			launchDirectionPlanar = providedDirection
		end
	end
	chargeState.aimDirection = launchDirectionPlanar
	self._aimTargets[player] = launchDirectionPlanar

	local now = os.clock()
	local launchState = LaunchMotionModel.BuildState(launchDirectionPlanar, chargeRatio, now, player)

	local movementController = self._movementControllers[player]
	if movementController then
		movementController:DisableLocomotion(true)
	end

	if root:GetNetworkOwner() ~= player then
		root:SetNetworkOwner(player)
	end

	local launchRemote = self._clientDoLaunchRemote
	if launchRemote then
		launchRemote:FireClient(player, launchState.direction, launchState.initialSpeed, root.AssemblyMass)
	end
	player:SetAttribute("LaunchValidationGraceEndsAt", now + PhysicsConfig.Launch.ValidationGraceSeconds * 20)

	self._activeLaunches[player] = launchState
	warn(string.format("[SlingService] Launch player=%s charge=%.2f speed=%.2f energy=%.2f",
		player.Name, chargeRatio, launchState.initialSpeed, launchState.energy))

	state.CurrentVelocity = launchState.direction * launchState.initialSpeed
	self._context.Services.PlayerStateService:SetCharging(player, false, chargeRatio)
	self._context.Services.PlayerStateService:SetMovementState(player, "Launching")
	warn(string.format("[SlingService] State player=%s -> Launching", player.Name))
	self._context.EventBus:Fire("SlingLaunched", player, chargeRatio, launchState)

	if chargeRatio >= PhysicsConfig.Charge.MaxChargeRatioThreshold then
		self._context.EventBus:Fire("MaxChargeReleased", player, BalanceConfig.MaxChargeSelfDamage)
	end

	self._chargeState[player] = nil
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
	if desiredPlanar.Magnitude < PhysicsConfig.Movement.AimDeadzone then
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if forward.Magnitude > PhysicsConfig.Movement.AimDeadzone then
			desiredPlanar = forward.Unit
		elseif input.Magnitude > PhysicsConfig.Movement.AimDeadzone then
			desiredPlanar = input.Unit
		end
	end
	if desiredPlanar.Magnitude < PhysicsConfig.Movement.AimDeadzone then
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

local function resolveMovementSpeed(state): number
	local speed = math.max(state.MoveSpeed or PhysicsConfig.Movement.MoveSpeed, 0)
	local slowFlag = state.ActiveFlags and state.ActiveFlags.Slow
	if slowFlag then
		local stacks = math.max(1, slowFlag.Stacks or 1)
		speed *= math.max(0, 1 - (PhysicsConfig.Movement.SlowPerStack * stacks))
	end
	return speed
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

	self._warnedInvalidRoot[player] = nil

	if state.MovementState == "Launching" then
		self:_applyAimRotation(player, root, input, dt)
		if root:GetNetworkOwner() ~= player then
			root:SetNetworkOwner(player)
		end
		return
	end

	if root:GetNetworkOwner() ~= player then
		root:SetNetworkOwner(player)
		if not self._loggedControllerRoot[player] then
			self._loggedControllerRoot[player] = true
			warn(string.format("[SlingService] SetNetworkOwner player=%s root=%s", player.Name, root:GetFullName()))
		end
	end

	local movementController = self:_getMovementController(player, root)
	local moveDirection = Vector3.zero
	if input.Magnitude > PhysicsConfig.Movement.InputDeadzone then
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
		if forward.Magnitude > PhysicsConfig.Movement.InputDeadzone and right.Magnitude > PhysicsConfig.Movement.InputDeadzone then
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

	if moveDirection.Magnitude < PhysicsConfig.Movement.InputDeadzone then
		movementController:SetSpeed(resolveMovementSpeed(state))
		movementController:Move(Vector3.zero, dt)
		self:_applyAimRotation(player, root, input, dt)
		if state.MovementState ~= MOVEMENT_STATE.Idle then
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
		end
		return
	end

	movementController:SetSpeed(resolveMovementSpeed(state))
	movementController:Move(moveDirection.Unit, dt)
	self:_applyAimRotation(player, root, input, dt)
	if state.MovementState ~= MOVEMENT_STATE.Moving then
		self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Moving)
	end
end

--[[
	_stepMovementStates (BUG FIX):

	ROOT CAUSE OF PREMATURE IDLE/RECOVERING:
	The original code called LaunchMotionModel.Sample(launchState, now, horizontalVelocity)
	where horizontalVelocity = root.AssemblyLinearVelocity read from the SERVER.
	Because the root is CLIENT-OWNED, the server's physics view lags by network RTT.
	Immediately after ReleaseCharge fires clientDoLaunchRemote, the server reads
	velocity ≈ 0 (replication hasn't arrived). LaunchMotionModel.Sample sees rawSpeed=0,
	returns sampledSpeed=0, shouldStop triggers, and state becomes Recovering/Idle
	before any food report can arrive — causing the "state=Idle speed=20" log.

	FIX: Decay launchState.currentSpeed using time-based math (DecayPerSecond applied
	to the RECORDED initialSpeed over elapsed time), not from root.AssemblyLinearVelocity.
	The server velocity is only used to CLAMP excessive speed downward (cap cheating),
	never as the authoritative value for stop/energy decisions.

	Energy is also decayed purely time-based (PassiveEnergyDecayPerSecond × elapsed).
	shouldStop only triggers when the TIME-BASED currentSpeed drops below StopSpeed,
	or when the grace window expires and server velocity is also low.
]]
function SlingService:_stepMovementStates(dt: number)
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
		local serverHorizontalSpeed = horizontalVelocity.Magnitude

		if state.MovementState == "Launching" and launchState then
			-- BUG FIX: Use time-based decay for currentSpeed and energy.
			-- Do NOT use root.AssemblyLinearVelocity as the speed for decay/stop
			-- because the server reads 0 immediately after a client-authoritative launch.
			local lastSampleTime = launchState.lastSampleTime or launchState.startTime or now
			local elapsed = math.max(0, now - lastSampleTime)
			launchState.lastSampleTime = now

			-- Time-based speed decay: apply DecayPerSecond to currentSpeed each frame.
			-- currentSpeed starts at initialSpeed and decays monotonically.
			local previousSpeed = launchState.currentSpeed or launchState.initialSpeed or 0
			local decayFactor = math.max(0, 1 - (PhysicsConfig.Launch.DecayPerSecond * elapsed))
			local decayedSpeed = previousSpeed * decayFactor

			-- Time-based energy decay.
			local energyDecayFactor = math.max(0, 1 - (PhysicsConfig.Launch.PassiveEnergyDecayPerSecond * elapsed))
			local decayedEnergy = math.max(0, (launchState.energy or 0) * energyDecayFactor)

			-- Server velocity is only used to CLAMP from above: if the client somehow
			-- exceeds the decayed speed cap, we bring it down. We never set currentSpeed
			-- to the server velocity when server reads low (0), since that's a lag artifact.
			-- Only clamp if server speed has had time to replicate (check grace window).
			local graceEndsAt = player:GetAttribute("LaunchValidationGraceEndsAt")
			local graceActive = typeof(graceEndsAt) == "number" and os.clock() <= graceEndsAt
			local targetSpeed
			if graceActive then
				-- During the grace window: trust time-based decay only.
				-- Server hasn't received physics replication yet.
				targetSpeed = decayedSpeed
			else
				-- After grace: server velocity is now reliable; clamp from above only.
				targetSpeed = math.min(decayedSpeed, math.max(serverHorizontalSpeed, PhysicsConfig.Launch.StopSpeed))
			end

			-- Only apply the clamp downward — never accelerate.
			if serverHorizontalSpeed > targetSpeed and serverHorizontalSpeed > PhysicsConfig.Movement.InputDeadzone and not graceActive then
				local clampedHorizontal = horizontalVelocity.Unit * math.max(targetSpeed, 0)
				root.AssemblyLinearVelocity = Vector3.new(
					clampedHorizontal.X,
					fullVelocity.Y,
					clampedHorizontal.Z
				)
				fullVelocity = root.AssemblyLinearVelocity
				horizontalVelocity = Vector3.new(fullVelocity.X, 0, fullVelocity.Z)
				serverHorizontalSpeed = horizontalVelocity.Magnitude
			end

			launchState.currentSpeed = targetSpeed
			launchState.energy = decayedEnergy

			-- Track direction for collision service (only update when server velocity is reliable).
			if not graceActive and serverHorizontalSpeed > PhysicsConfig.Movement.InputDeadzone then
				launchState.direction = horizontalVelocity.Unit
			end
		end

		-- Stop condition: use time-based currentSpeed, not server velocity.
		-- This prevents premature stop when server reads 0 immediately after launch.
		local stopThreshold = PhysicsConfig.Launch.StopSpeed
		local timeBasedSpeed = launchState and (launchState.currentSpeed or 0) or 0
		local shouldStop = state.MovementState == "Launching"
			and (timeBasedSpeed <= stopThreshold or (launchState and launchState.energy <= 0))

		if shouldStop then
			local brakeFactor = math.max(0, 1 - LAUNCH_BRAKE_RATE * dt)
			local brakedHorizontal = horizontalVelocity * brakeFactor
			root.AssemblyLinearVelocity = Vector3.new(
				brakedHorizontal.X,
				fullVelocity.Y,
				brakedHorizontal.Z
			)

			if brakedHorizontal.Magnitude <= 0.5 then
				self._activeLaunches[player] = nil

				local recoveryEnd = now + PhysicsConfig.Launch.RecoveryDuration
				self._releaseCooldown[player] = recoveryEnd
				self._context.Services.PlayerStateService:SetLastReleaseDuration(
					player, PhysicsConfig.Launch.RecoveryDuration)
				self._context.Services.PlayerStateService:SetCooldownEndTime(player, recoveryEnd)
				player:SetAttribute("LaunchValidationGraceEndsAt", now + PhysicsConfig.Launch.ValidationGraceSeconds)
				self._context.Services.PlayerStateService:SetMovementState(player, "Recovering")
				warn(string.format("[SlingService] State player=%s -> Recovering (timeBasedSpeed=%.2f)",
					player.Name, timeBasedSpeed))
			end

		elseif state.MovementState == "Recovering" and now >= (self._releaseCooldown[player] or 0) then
			self._activeLaunches[player] = nil
			player:SetAttribute("LaunchValidationGraceEndsAt", 0)
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
			self._context.Services.PlayerStateService:SetCooldownEndTime(player, 0)
			self._context.Services.PlayerStateService:SetLastReleaseDuration(player, 0)
		end
	end
end

return SlingService