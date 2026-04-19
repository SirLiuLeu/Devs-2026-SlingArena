--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingMovement = require(script.Parent.SlingMovement)

local SlingService = {}
SlingService.__index = SlingService

local ABNORMAL_LOG_COOLDOWN = 2

local function sanitizeNumber(value: number, fallback: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

function SlingService.CalculateLaunchForce(chargeRatio: number, _minForce: number, maxForce: number, _launchMultiplier: number): number
	local safeCharge = math.clamp(sanitizeNumber(chargeRatio, 0), 0, 1)
	local safeMax = math.max(0, sanitizeNumber(maxForce, 0))
	local launchForce = safeMax * safeCharge
	if launchForce ~= launchForce then
		return 0
	end
	return math.clamp(launchForce, 0, safeMax)
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

local RELEASE_DISTANCE_MULTIPLIER = BalanceConfig.ReleaseDistanceMultiplier
local RELEASE_SPEED_MULTIPLIER = BalanceConfig.ReleaseSpeedMultiplier
local MAX_LAUNCH_DISTANCE = math.max(1, BalanceConfig.MaxLaunchDistance or 30)
local LAUNCH_SPEED_TO_MOVE_SPEED_RATIO = math.max(0.5, BalanceConfig.LaunchSpeedToMoveSpeedRatio or 3)
local MAX_LAUNCH_PLANAR_SPEED = math.max(1, BalanceConfig.MaxLaunchPlanarSpeed or (BalanceConfig.DefaultWalkSpeed * 3))

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
	self._inputStates = {}
	self._chargeState = {}
	self._releaseCooldown = {}
	self._releaseState = {}
	self._movementControllers = {}
	self._logCooldownByPlayer = {}
	return self
end

function SlingService:_getTrackedPlayers(): { any }
	local trackedPlayers = {}
	local seen = {}

	local stateService = self._context.Services.PlayerStateService
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
	for player in pairs(self._inputStates) do
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
	local moveRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest)
	local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge)
	local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge)

	moveRemote.OnServerEvent:Connect(function(player, directionInput)
		self:HandleMoveRequest(player, directionInput)
	end)

	startChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
		self:StartCharge(player, aimTarget)
	end)

	releaseChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
		self:ReleaseCharge(player, aimTarget)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._input[player] = nil
		self._inputStates[player] = nil
		self._chargeState[player] = nil
		self._releaseCooldown[player] = nil
		self._releaseState[player] = nil
		self._logCooldownByPlayer[player] = nil
		local movementController = self._movementControllers[player]
		if movementController then
			movementController:Destroy()
			self._movementControllers[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		self:_stepMovement(dt)
		self:_stepMovementStates()
	end)
end

function SlingService:_isRoundPlaying(): boolean
	return self._context.Services.RoundService:GetState() == GameStates.Round.ActiveRound
end

function SlingService:_canControl(player: Player): boolean
	local roundState = self._context.Services.RoundService:GetState()
	local canControlForRound = false
	if roundState == GameStates.Round.ActiveRound then
		canControlForRound = self._context.Services.RoundService:IsPlayerQueued(player)
	elseif roundState == GameStates.Round.Lobby then
		canControlForRound = true
	end
	if not canControlForRound then
		return false
	end
	if not self._context.Services.PlayerService:IsAlive(player) then
		return false
	end
	return true
end

function SlingService:_warnAbnormal(player: Player, logType: string, message: string)
	local now = os.clock()
	local logKey = string.format("%s:%d", logType, player.UserId)
	local nextLogAt = self._logCooldownByPlayer[logKey] or 0
	if now < nextLogAt then
		return
	end
	self._logCooldownByPlayer[logKey] = now + ABNORMAL_LOG_COOLDOWN
	warn(string.format("[SlingService] %s player=%s", message, player.Name))
end

function SlingService:HandleMoveRequest(player: Player, inputState)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return
	end
	if not RemoteContracts.Validate(RemoteContracts.Names.MoveRequest, inputState) then
		self:_warnAbnormal(player, "MoveInvalidPayload", "MoveRequest rejected: invalid payload type")
		return
	end
	local normalizedState = {
		W = inputState.W == true,
		A = inputState.A == true,
		S = inputState.S == true,
		D = inputState.D == true,
	}
	self._inputStates[player] = normalizedState
	if not self:_canControl(player) then
		self._input[player] = Vector3.zero
		self._inputStates[player] = { W = false, A = false, S = false, D = false }
		self:_warnAbnormal(player, "MoveBlocked", "MoveRequest rejected: player cannot control")
		return
	end

	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state or state.IsTeleporting then
		self._input[player] = Vector3.zero
		self._inputStates[player] = { W = false, A = false, S = false, D = false }
		self:_warnAbnormal(player, "MoveNoState", "MoveRequest rejected: missing/teleporting state")
		return
	end
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Recovering then
		self._input[player] = Vector3.zero
		return
	end

end

function SlingService:_resolveInputVector(player: Player): Vector3
	local inputState = self._inputStates[player]
	if not inputState then
		return Vector3.zero
	end
	local x = 0
	local z = 0
	if inputState.D then
		x += 1
	end
	if inputState.A then
		x -= 1
	end
	if inputState.W then
		z += 1
	end
	if inputState.S then
		z -= 1
	end
	local vector = Vector3.new(x, 0, z)
	if vector.Magnitude > 1 then
		return vector.Unit
	end
	return vector
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

	local root = self._context.Services.PlayerService:GetRoot(player)
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

	local direction = SlingService.ResolveAimDirection(root.Position, aimTarget)

	self._chargeState[player] = {
		chargeStartTime = now,
		aimDirection = direction,
	}
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
	local root = self._context.Services.PlayerService:GetRoot(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not root or not state then
		self._chargeState[player] = nil
		return
	end

	local chargeSpeed = math.max(state.ChargeSpeed or 1, 0.1)
	local maxChargeTime = (SlingshotConfig.MAX_CHARGE_TIME or SlingshotConfig.MaxChargeTime) / chargeSpeed
	local chargeRatio = SlingService.CalculateChargeRatio(chargeState.chargeStartTime, os.clock(), maxChargeTime)

	chargeState.aimDirection = SlingService.ResolveAimDirection(root.Position, aimTarget)
	local aimPlanar = Vector3.new(aimTarget.X - root.Position.X, 0, aimTarget.Z - root.Position.Z)
	if aimPlanar.Magnitude > MAX_LAUNCH_DISTANCE then
		chargeState.aimDirection = Vector3.new(aimPlanar.Unit.X, chargeState.aimDirection.Y, aimPlanar.Unit.Z).Unit
	end

	local maxForce = SlingshotConfig.MAX_LAUNCH_FORCE or (SlingshotConfig.BaseLaunchForce + Config.MaxExtraForce)
	local launchForce = SlingService.CalculateLaunchForce(chargeRatio, 0, maxForce, 1) * RELEASE_SPEED_MULTIPLIER
	local launchVector = SlingService.BuildLaunchVector(chargeState.aimDirection, launchForce)

	local maxFromMoveSpeed = math.max((state.MoveSpeed or Config.MoveSpeed) * LAUNCH_SPEED_TO_MOVE_SPEED_RATIO, 1)
	local planarSpeedCap = math.min(maxFromMoveSpeed, MAX_LAUNCH_PLANAR_SPEED)
	local planarLaunch = Vector3.new(launchVector.X, 0, launchVector.Z)
	if planarLaunch.Magnitude > planarSpeedCap then
		planarLaunch = planarLaunch.Unit * planarSpeedCap
	end
	root.AssemblyLinearVelocity = Vector3.new(planarLaunch.X, root.AssemblyLinearVelocity.Y, planarLaunch.Z)

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

function SlingService:_stepMovement(dt: number)
	for _, player in self:_getTrackedPlayers() do
		local root = self._context.Services.PlayerService:GetRoot(player)
		local input = self:_resolveInputVector(player)
		self._input[player] = input
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
		movementController = SlingMovement.new(root, {
			moveSpeed = Config.MoveSpeed,
			acceleration = BalanceConfig.GroundAcceleration or 18,
			deceleration = BalanceConfig.GroundDeceleration or 24,
		})
		self._movementControllers[player] = movementController
	end
	return movementController
end

function SlingService:_applyRootVelocity(player: Player, root: BasePart, input: Vector3, dt: number)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	local movementController = self:_getMovementController(player, root)

	if state.MovementState == MOVEMENT_STATE.Launched then
		-- Preserve launch momentum. We only disable the locomotion actuator so it does not
		-- counteract release velocity and create an artificial "drag/stretch" feeling.
		movementController:DisableLocomotion(true)
		return
	end
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Recovering then
		movementController:DisableLocomotion(false)
		return
	end

	if input.Magnitude < 0.001 then
		movementController:SetSpeed(math.max(state.MoveSpeed or Config.MoveSpeed, 0))
		movementController:Move(Vector3.zero, dt)
		if state.MovementState ~= MOVEMENT_STATE.Idle then
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
		end
		return
	end

	movementController:SetSpeed(math.max(state.MoveSpeed or Config.MoveSpeed, 0))
	movementController:Move(input.Unit, dt)
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
