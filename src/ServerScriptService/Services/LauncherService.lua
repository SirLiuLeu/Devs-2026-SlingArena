--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local LauncherMovement = require(script.Parent.LauncherMovement)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local LaunchMotionModel = require(script.Parent.LaunchMotionModel)

local LauncherService = {}
LauncherService.__index = LauncherService

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

function LauncherService.ResolveAimDirection(aimDirection: Vector3): Vector3
	local planarDirection = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	if planarDirection.Magnitude < PhysicsConfig.Movement.AimDeadzone then
		return Vector3.new(0, 0, -1)
	end
	return planarDirection.Unit
end

function LauncherService.ResolveLaunchDirectionFromRoot(root: BasePart): Vector3
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < PhysicsConfig.Movement.AimDeadzone then
		return Vector3.new(0, 0, -1)
	end
	return forward.Unit
end

function LauncherService.ResolveLaunchDirection(root: BasePart, aimDirection: Vector3?): Vector3
	if typeof(aimDirection) == "Vector3" then
		return LauncherService.ResolveAimDirection(aimDirection)
	end
	return LauncherService.ResolveLaunchDirectionFromRoot(root)
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

function LauncherService.GetCooldownRemaining(cooldownEndTime: number, nowTime: number): number
	local remaining = sanitizeNumber(cooldownEndTime, 0) - sanitizeNumber(nowTime, 0)
	return math.max(0, remaining)
end

function LauncherService.BuildCooldownUiState(cooldownEndTime: number, nowTime: number): { CooldownRemaining: number }
	return {
		CooldownRemaining = LauncherService.GetCooldownRemaining(cooldownEndTime, nowTime),
	}
end

local MOVEMENT_STATE = GameStates.PlayerState
function LauncherService.new(context)
	local self = setmetatable({}, LauncherService)
	self._context = context
	self._input = {}
	self._moveRateState = {}
	self._chargeState = {}
	self._releaseCooldown = {}
	self._movementControllers = {}
	self._remoteConnections = {}
	self._clientDoLaunchRemote = nil :: RemoteEvent?
	self._reportLaunchStoppedRemote = nil :: RemoteEvent?
	self._heartbeatConnection = nil
	self._warnedInvalidRoot = {}
	self._aimTargets = {}
	self._activeLaunches = {}
	return self
end


function LauncherService:ResetPlayerRuntime(player: Player)
	self._input[player] = nil
	self._chargeState[player] = nil
	self._activeLaunches[player] = nil
	self._aimTargets[player] = nil
	self._releaseCooldown[player] = nil
	self._moveRateState[player] = nil

	local movementController = self._movementControllers[player]
	if movementController then
		movementController:Destroy()
		self._movementControllers[player] = nil
	end
end

function LauncherService:_isLauncherMode(player: Player): boolean
	local stateService = getService(self._context, "PlayerStateService")
	return stateService == nil or not stateService:IsHuman(player)
end

local function resolveAlignOrientation(root: BasePart): AlignOrientation?
	local alignOrientation = root:FindFirstChild("AlignOrientation")
	if alignOrientation and alignOrientation:IsA("AlignOrientation") then
		return alignOrientation
	end
	return nil
end

function LauncherService:_getTrackedPlayers(): { any }
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

function LauncherService:Init()
	local remotes = self._context.Remotes
	local startChargeRemote = remotes:FindFirstChild(RemoteContracts.Names.StartCharge)
	local releaseChargeRemote = remotes:FindFirstChild(RemoteContracts.Names.ReleaseCharge)
	local moveRequestRemote = remotes:FindFirstChild(RemoteContracts.Names.MoveRequest)
	local requestLaunchRemote = remotes:FindFirstChild(RemoteContracts.Names.RequestLaunch)
	local clientDoLaunchRemote = remotes:FindFirstChild(RemoteContracts.Names.ClientDoLaunch)
	local reportLaunchStoppedRemote = remotes:FindFirstChild(RemoteContracts.Names.ReportLaunchStopped)

	if startChargeRemote and startChargeRemote:IsA("RemoteEvent") then
		self._remoteConnections.StartCharge = startChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
			self:StartCharge(player, aimTarget)
		end)
	else
		warn(string.format("[LauncherService] Missing remote %s; charge-start listener disabled.", RemoteContracts.Names.StartCharge))
	end

	if releaseChargeRemote and releaseChargeRemote:IsA("RemoteEvent") then
		self._remoteConnections.ReleaseCharge = releaseChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
			self:ReleaseCharge(player, aimTarget)
		end)
	else
		warn(string.format("[LauncherService] Missing remote %s; charge-release listener disabled.", RemoteContracts.Names.ReleaseCharge))
	end

	if requestLaunchRemote and requestLaunchRemote:IsA("RemoteEvent") then
		self._remoteConnections.RequestLaunch = requestLaunchRemote.OnServerEvent:Connect(function(player, payload)
			self:RequestLaunch(player, payload)
		end)
	else
		warn(string.format("[LauncherService] Missing remote %s; launch-request listener disabled.", RemoteContracts.Names.RequestLaunch))
	end

	if clientDoLaunchRemote and clientDoLaunchRemote:IsA("RemoteEvent") then
		self._clientDoLaunchRemote = clientDoLaunchRemote
	else
		warn(string.format("[LauncherService] Missing remote %s; client launch impulse disabled.", RemoteContracts.Names.ClientDoLaunch))
	end

	if reportLaunchStoppedRemote and reportLaunchStoppedRemote:IsA("RemoteEvent") then
		self._reportLaunchStoppedRemote = reportLaunchStoppedRemote
		self._remoteConnections.ReportLaunchStopped = reportLaunchStoppedRemote.OnServerEvent:Connect(function(player, payload)
			self:HandleLaunchStopped(player, payload)
		end)
	else
		warn(string.format("[LauncherService] Missing remote %s; launch-stop cleanup relies on timeout only.", RemoteContracts.Names.ReportLaunchStopped))
	end

	if moveRequestRemote and moveRequestRemote:IsA("RemoteEvent") then
		self._remoteConnections.MoveRequest = moveRequestRemote.OnServerEvent:Connect(function(player, direction, aimTarget)
			self:HandleMoveRequest(player, direction, aimTarget)
		end)
	else
		warn(string.format("[LauncherService] Missing remote %s; movement listener disabled.", RemoteContracts.Names.MoveRequest))
	end

	Players.PlayerRemoving:Connect(function(player)
		self._input[player] = nil
		self._moveRateState[player] = nil
		self._chargeState[player] = nil
		self._releaseCooldown[player] = nil
		self._activeLaunches[player] = nil
		self._warnedInvalidRoot[player] = nil
		self._aimTargets[player] = nil
		local movementController = self._movementControllers[player]
		if movementController then
			movementController:Destroy()
			self._movementControllers[player] = nil
		end
	end)
end

function LauncherService:_resolvePawnAndRoot(player: Player): (Model?, BasePart?)
	if not self:_isLauncherMode(player) then
		return nil, nil
	end
	local playerService = self._context.Services.PlayerService
	local pawn = if playerService then playerService:GetPawn(player) else nil
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

function LauncherService:GetLaunchState(player: Player): any?
	return self._activeLaunches[player]
end

function LauncherService:SetLaunchState(player: Player, launchState: any?)
	player:SetAttribute("LaunchValidationGraceEndsAt", 0)
	self._activeLaunches[player] = launchState
end

function LauncherService:_finishLaunch(player: Player, reason: string)
	local now = os.clock()
	self._activeLaunches[player] = nil
	local recoveryEnd = now + PhysicsConfig.Launch.RecoveryDuration
	self._releaseCooldown[player] = recoveryEnd
	self._context.Services.PlayerStateService:SetLastReleaseDuration(player, PhysicsConfig.Launch.RecoveryDuration)
	self._context.Services.PlayerStateService:SetCooldownEndTime(player, recoveryEnd)
	player:SetAttribute("LaunchValidationGraceEndsAt", 0)
	self._context.Services.PlayerStateService:SetMovementState(player, "Recovering")
end

function LauncherService:ValidateLaunchReport(player: Player, payload: any): (boolean, any?, string)
	local launchState = self._activeLaunches[player]
	if not launchState then
		return false, nil, "missing_launch"
	end
	if type(payload) ~= "table" or payload.launchId ~= launchState.launchId then
		return false, nil, "launch_id_mismatch"
	end
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state or state.MovementState ~= "Launching" then
		return false, nil, "not_launching"
	end
	local observedSpeed = if typeof(payload.observedSpeed) == "number" then payload.observedSpeed else 0
	local reportedVelocity = if typeof(payload.velocity) == "Vector3" then payload.velocity else Vector3.zero
	local reportedSpeed = math.max(Vector3.new(reportedVelocity.X, 0, reportedVelocity.Z).Magnitude, observedSpeed)
	if reportedSpeed ~= reportedSpeed or reportedSpeed == math.huge or reportedSpeed == -math.huge then
		return false, nil, "invalid_speed"
	end
	local ceiling = launchState.maxReportSpeed or PhysicsConfig.Collision.MaxAllowedSpeed
	if reportedSpeed > ceiling then
		return false, nil, "speed_above_launch_ceiling"
	end
	return true, launchState, "ok"
end

function LauncherService:RegisterLaunchDamageTarget(player: Player, targetKey: string): boolean
	local launchState = self._activeLaunches[player]
	if not launchState or type(targetKey) ~= "string" or targetKey == "" then
		return false
	end
	launchState.damageTargets = launchState.damageTargets or {}
	if launchState.damageTargets[targetKey] then
		return true
	end
	if (launchState.damageTargetCount or 0) >= PhysicsConfig.Launch.MaxDamageTargetsPerLaunch then
		return false
	end
	launchState.damageTargets[targetKey] = true
	launchState.damageTargetCount = (launchState.damageTargetCount or 0) + 1
	return true
end

function LauncherService:RegisterLaunchKnockbackTarget(player: Player, targetKey: string): boolean
	local launchState = self._activeLaunches[player]
	if not launchState or type(targetKey) ~= "string" or targetKey == "" then
		return false
	end
	launchState.knockbackTargets = launchState.knockbackTargets or {}
	if launchState.knockbackTargets[targetKey] then
		return true
	end
	if (launchState.knockbackTargetCount or 0) >= PhysicsConfig.Launch.MaxKnockbackTargetsPerLaunch then
		return false
	end
	launchState.knockbackTargets[targetKey] = true
	launchState.knockbackTargetCount = (launchState.knockbackTargetCount or 0) + 1
	return true
end

function LauncherService:Start()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self:_stepMovement(dt)
		self:_stepMovementStates(dt)
	end)
end

function LauncherService:_isRoundPlaying(): boolean
	local roundService = getService(self._context, "RoundService")
	if not roundService then
		return false
	end
	local roundState = roundService:GetState()
	return roundState == GameStates.MapRoundState.EarlyGame or roundState == GameStates.MapRoundState.FinalPhase
end

function LauncherService:_canControl(player: Player): boolean
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
	if stateService:IsHuman(player) then
		return false
	end
	if stateService:IsStunned(player) then
		return false
	end
	return true
end

function LauncherService:HandleMoveRequest(player: Player, moveInput: Vector3, aimDirection: Vector3?)
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

function LauncherService:StartCharge(player: Player, aimDirection: Vector3)
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

	local direction = LauncherService.ResolveLaunchDirection(root, aimDirection)

	self._chargeState[player] = {
		chargeStartTime = now,
		aimDirection = direction,
	}
	self._aimTargets[player] = direction
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
	self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Charging)
	self._context.EventBus:Fire("ChargeStarted", player)
end

function LauncherService:_authorizeLaunch(player: Player, aimDirection: Vector3)
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
	if not root:IsA("BasePart") or root.Anchored or root.AssemblyMass <= 0 then
		self._chargeState[player] = nil
		return
	end

	local launchDirectionPlanar = chargeState.aimDirection
	if typeof(aimDirection) == "Vector3" then
		local providedDirection = LauncherService.ResolveAimDirection(aimDirection)
		if providedDirection.Magnitude >= PhysicsConfig.Launch.DirectionDeadzone then
			launchDirectionPlanar = providedDirection
		end
	end
	chargeState.aimDirection = launchDirectionPlanar
	self._aimTargets[player] = launchDirectionPlanar

	local now = os.clock()
	local chargeRatio = LaunchMotionModel.ComputeChargeRatio(chargeState.chargeStartTime, now)
	local launchSpeed = state.LaunchSpeed or PhysicsConfig.Launch.SpeedMax
	local launchState = LaunchMotionModel.BuildState(launchDirectionPlanar, chargeRatio, now, player, launchSpeed)
	local launchId = HttpService:GenerateGUID(false)

	launchState.launchId = launchId
	launchState.maxEndsAt = now + PhysicsConfig.Launch.MaxLaunchDuration
	launchState.maxReportSpeed = math.min(
		PhysicsConfig.Collision.MaxAllowedSpeed,
		math.max(
			launchState.initialSpeed * PhysicsConfig.Launch.SpeedCeilingMultiplier,
			launchState.initialSpeed + PhysicsConfig.Launch.SpeedCeilingPadding
		)
	)
	launchState.damageTargets = {}
	launchState.damageTargetCount = 0
	launchState.knockbackTargets = {}
	launchState.knockbackTargetCount = 0

	local movementController = self._movementControllers[player]
	if movementController then
		movementController:DisableLocomotion(true)
	end

	if root:GetNetworkOwner() ~= player then
		root:SetNetworkOwner(player)
	end

	self._activeLaunches[player] = launchState
	state.CurrentVelocity = launchState.direction * launchState.initialSpeed
	self._context.Services.PlayerStateService:SetCharging(player, false, chargeRatio)
	self._context.Services.PlayerStateService:SetMovementState(player, "Launching")
	player:SetAttribute("LaunchValidationGraceEndsAt", 0)

	local launchRemote = self._clientDoLaunchRemote
	if launchRemote then
		launchRemote:FireClient(player, launchState.direction, launchState.initialSpeed, root.AssemblyMass, launchId)
	end

	self._context.EventBus:Fire("LauncherLaunched", player, chargeRatio, launchState)
	if chargeRatio >= PhysicsConfig.Charge.MaxChargeRatioThreshold then
		self._context.EventBus:Fire("MaxChargeReleased", player, BalanceConfig.MaxChargeSelfDamage)
	end

	self._chargeState[player] = nil
	self._releaseCooldown[player] = 0
	self._context.Services.PlayerStateService:SetLastReleaseDuration(player, 0)
	self._context.Services.PlayerStateService:SetCooldownEndTime(player, 0)
end

function LauncherService:RequestLaunch(player: Player, payload: any)
	if not RemoteContracts.Validate(RemoteContracts.Names.RequestLaunch, payload) then
		return
	end
	self:_authorizeLaunch(player, payload.aimTarget)
end

function LauncherService:ReleaseCharge(player: Player, aimDirection: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.ReleaseCharge, aimDirection) then
		return
	end
	self:_authorizeLaunch(player, aimDirection)
end

function LauncherService:HandleLaunchStopped(player: Player, payload: any)
	if not RemoteContracts.Validate(RemoteContracts.Names.ReportLaunchStopped, payload) then
		return
	end
	local launchState = self._activeLaunches[player]
	if not launchState or payload.launchId ~= launchState.launchId then
		return
	end
	local observedSpeed = if typeof(payload.observedSpeed) == "number" then payload.observedSpeed else 0
	if observedSpeed > PhysicsConfig.Launch.StopSpeed + PhysicsConfig.Launch.SpeedCeilingPadding then
		return
	end
	self:_finishLaunch(player, "client_stopped")
end

function LauncherService:_applyAimRotation(player: Player, root: BasePart, input: Vector3, _dt: number)
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

function LauncherService:_stepMovement(dt: number)
	for _, player in self:_getTrackedPlayers() do
		if not self:_isLauncherMode(player) then
			self:ResetPlayerRuntime(player)
			continue
		end
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

function LauncherService:_getMovementController(player: Player, root: BasePart)
	if not self:_isLauncherMode(player) then
		return nil
	end
	local movementController = self._movementControllers[player]
	if movementController and movementController._root ~= root then
		movementController:Destroy()
		movementController = nil
	end
	if not movementController then
		movementController = LauncherMovement.new(root)
		self._movementControllers[player] = movementController
	end
	return movementController
end

local function resolveMovementSpeed(state): number
	local speed = math.max(state.MoveSpeed or PhysicsConfig.Movement.MoveSpeed, 0)
	local slowFlag = state.ActiveFlags and state.ActiveFlags.Slow
	if slowFlag then
		local slowAmount = math.max(0, slowFlag.SlowAmount or PhysicsConfig.Movement.SlowPerStack)
		speed *= math.max(0, 1 - slowAmount)
	end
	return speed
end

function LauncherService:_applyRootVelocity(player: Player, root: BasePart, input: Vector3, dt: number)
	if not self:_isLauncherMode(player) then
		self:ResetPlayerRuntime(player)
		return
	end

	if root.Anchored then
		root.Anchored = false
		if root.Anchored then
			if not self._warnedInvalidRoot[player] then
				self._warnedInvalidRoot[player] = true
				warn(string.format("[LauncherService] Root anchored; movement blocked for %s (%s)",
					player.Name, root:GetFullName()))
			end
			return
		end
	end

	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state or state.ActivePlayerMode == GameStates.PlayerMode.Human then
		self:ResetPlayerRuntime(player)
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
	end

	local movementController = self:_getMovementController(player, root)
	if not movementController then
		return
	end
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
	_stepMovementStates keeps only server-authoritative launch lifecycle cleanup.
	Movement decay/braking is intentionally absent: launch motion is client-impulse
	physics, and the server verifies reports against launchId/state/speed ceilings.
]]
function LauncherService:_stepMovementStates(_dt: number)
	local now = os.clock()
	for _, player in self:_getTrackedPlayers() do
		local state = self._context.Services.PlayerStateService:GetState(player)
		if not state or state.ActivePlayerMode == GameStates.PlayerMode.Human then
			continue
		end

		local launchState = self._activeLaunches[player]
		if state.MovementState == "Launching" and launchState then
			if now >= (launchState.maxEndsAt or math.huge) then
				self:_finishLaunch(player, string.format("hard_timeout (max=%.1fs)", PhysicsConfig.Launch.MaxLaunchDuration))
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

return LauncherService
