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

-- Brake deceleration rate (units/s per unit/s) applied when launch is stopping.
-- Đủ nhanh để dừng trong ~2-3 frames ở 60fps, nhưng không instant → không snap với PlayerB.
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
	-- [FIX 4] _launchVelocityControllers removed — không cần vì player vẫn own root.
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

	-- Disable locomotion actuator so WASD doesn't fight launch momentum.
	local movementController = self._movementControllers[player]
	if movementController then
		movementController:DisableLocomotion(true)
	end

	-- [FIX 1] Giữ player làm NetworkOwner — KHÔNG chuyển về server.
	-- Trước: root:SetNetworkOwner(nil)
	-- Lý do: server-owned BasePart replicates position từ server sau mỗi physics step (~16ms).
	-- PlayerB thấy root freeze 1-4 frames rồi jump → "snap".
	-- Player-owned root replicates trực tiếp từ client → cùng path với movement bình thường → mượt.
	--
	-- Server vẫn validate collision qua CollisionService (position check ± tolerance).
	-- Nếu cần server authority cho anti-cheat, dùng position validation sau launch thay vì ownership.
	if root:GetNetworkOwner() ~= player then
		root:SetNetworkOwner(player)
	end

	-- Client-authoritative launch: the player owns the root, so the client must
	-- apply the initial impulse locally. Server remains authoritative for state,
	-- validation, collision damage, and decay/clamp corrections after launch.
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

	-- [FIX 1 continued] Trong Launch, player vẫn own → không cần restore controllers.
	-- Chỉ update aim rotation để pawn face travel direction.
	if state.MovementState == "Launching" then
		self:_applyAimRotation(player, root, input, dt)
		-- Đảm bảo player vẫn là owner (có thể bị reset bởi code khác).
		if root:GetNetworkOwner() ~= player then
			root:SetNetworkOwner(player)
		end
		return
	end

	-- Đảm bảo player own khi không launch (đã là behavior cũ, giữ nguyên).
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
	_stepMovementStates (REFACTORED):

	[FIX 2] Client applies the initial impulse, then server enforces decay/clamp.
	  Server reads LaunchMotionModel.Sample() and only scales horizontal speed down
	  when actual physics velocity exceeds the sampled decay speed or SpeedMax.
	  Direction is preserved so Roblox physics can still handle bounce/deflection.
	[FIX 3] Smooth stop.
	  Trước: root.AssemblyLinearVelocity = (0, y, 0) — instant snap.
	  Sau:   Áp brake factor mạnh mỗi frame cho đến khi speed < StopSpeed thật sự.
	  Brake frame 1: speed * (1 - 15*dt) ≈ speed * 0.75 tại 60fps
	  Brake frame 2: speed * 0.75 * 0.75 ≈ speed * 0.56
	  ... dừng hẳn trong ~4-5 frames = ~80ms, không thấy snap.
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
		local horizontalSpeed = horizontalVelocity.Magnitude

		if state.MovementState == "Launching" and launchState then
			-- Sample launch decay and actively enforce it by only scaling speed down.
			local sampledSpeed, sampledEnergy, _ = LaunchMotionModel.Sample(launchState, now, horizontalVelocity)
			local targetSpeed = math.min(sampledSpeed, PhysicsConfig.Launch.SpeedMax)
			if horizontalSpeed > targetSpeed and horizontalSpeed > PhysicsConfig.Movement.InputDeadzone then
				local clampedHorizontal = horizontalVelocity.Unit * math.max(targetSpeed, 0)
				root.AssemblyLinearVelocity = Vector3.new(
					clampedHorizontal.X,
					fullVelocity.Y,
					clampedHorizontal.Z
				)
				fullVelocity = root.AssemblyLinearVelocity
				horizontalVelocity = Vector3.new(fullVelocity.X, 0, fullVelocity.Z)
				horizontalSpeed = horizontalVelocity.Magnitude
			end
			launchState.currentSpeed = horizontalSpeed
			launchState.energy = sampledEnergy

			-- Track direction cho collision service (không dùng để drive movement).
			if horizontalSpeed > PhysicsConfig.Movement.InputDeadzone then
				launchState.direction = horizontalVelocity.Unit
			end
		end

		-- Kiểm tra điều kiện dừng launch.
		local stopThreshold = PhysicsConfig.Launch.StopSpeed
		local shouldStop = state.MovementState == "Launching"
			and (horizontalSpeed <= stopThreshold or (launchState and launchState.energy <= 0))

		if shouldStop then
			-- [FIX 3] Smooth brake thay vì instant zero.
			-- Áp dụng brake factor mạnh — dừng trong ~4-5 frames ở 60fps thay vì 1 frame.
			local brakeFactor = math.max(0, 1 - LAUNCH_BRAKE_RATE * dt)
			local brakedHorizontal = horizontalVelocity * brakeFactor
			root.AssemblyLinearVelocity = Vector3.new(
				brakedHorizontal.X,
				fullVelocity.Y,
				brakedHorizontal.Z
			)

			-- Chỉ chuyển sang Recovering khi speed thực sự rất thấp (gần 0).
			-- Tránh chuyển state quá sớm → movement controller activate giữa chừng.
			if brakedHorizontal.Magnitude <= 0.5 then
				self._activeLaunches[player] = nil

				local recoveryEnd = now + PhysicsConfig.Launch.RecoveryDuration
				self._releaseCooldown[player] = recoveryEnd
				self._context.Services.PlayerStateService:SetLastReleaseDuration(
					player, PhysicsConfig.Launch.RecoveryDuration)
				self._context.Services.PlayerStateService:SetCooldownEndTime(player, recoveryEnd)
				player:SetAttribute("LaunchValidationGraceEndsAt", now + PhysicsConfig.Launch.ValidationGraceSeconds)
				self._context.Services.PlayerStateService:SetMovementState(player, "Recovering")
				warn(string.format("[SlingService] State player=%s -> Recovering (horizontal=%.2f)",
					player.Name, horizontalSpeed))
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