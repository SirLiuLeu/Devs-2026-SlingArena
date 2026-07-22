--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local VelocityDecay = require(ReplicatedStorage.Shared.Utils.VelocityDecay)

local CollisionService = {}
CollisionService.__index = CollisionService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local SAME_TARGET_DEDUPE_SECONDS = 0.28

local function isLauncherMovementControlling(root: BasePart): boolean
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	return linearVelocity ~= nil and linearVelocity:IsA("LinearVelocity") and linearVelocity.Enabled
end

function CollisionService.new(context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._lastCollision = {}
	self._lastCollisionByLaunchTarget = {}
	self._lastWallCollision = {}
	self._positionHistory = {}
	return self
end

function CollisionService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_samplePositionHistory()
		self:_applyDragAndBounce(dt)
	end)
	self:_bindClientCollisionReports()
end

function CollisionService:_samplePositionHistory()
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		return
	end
	local now = os.clock()
	local oldestAllowed = now - PhysicsConfig.Collision.PositionHistoryWindow
	for _, player in Players:GetPlayers() do
		local root = playerService:GetRoot(player)
		if root then
			local history = self._positionHistory[player]
			if not history then
				history = {}
				self._positionHistory[player] = history
			end
			table.insert(history, {
				timestamp = now,
				position = root.Position,
				velocity = root.AssemblyLinearVelocity,
			})
			while history[1] and history[1].timestamp < oldestAllowed do
				table.remove(history, 1)
			end
		end
	end
	for player in pairs(self._positionHistory) do
		if not player.Parent then
			self._positionHistory[player] = nil
		end
	end
end

function CollisionService:_getClosestHistorySample(player: Player, timestamp: number): any
	local history = self._positionHistory[player]
	if not history or #history == 0 then
		return nil
	end
	local closest = history[1]
	local closestDelta = math.abs(closest.timestamp - timestamp)
	for i = 2, #history do
		local sample = history[i]
		local delta = math.abs(sample.timestamp - timestamp)
		if delta < closestDelta then
			closest = sample
			closestDelta = delta
		end
	end
	return closest
end

function CollisionService:_firePvpFeedback(player: Player, eventType: string, targetUserId: number?, root: BasePart?)
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, {
			EventType = eventType,
			targetUserId = targetUserId,
			authoritativeVelocity = root and root.AssemblyLinearVelocity or nil,
		})
	end
end

function CollisionService:_applyDragAndBounce(dt: number)
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		return
	end

	for _, player in Players:GetPlayers() do
		local root = playerService:GetRoot(player)
		if not (root and playerService:IsAlive(player)) then
			continue
		end

		local stateService = getService(self._context, "PlayerStateService")
		if stateService and stateService.IsHuman and stateService:IsHuman(player) then
			continue
		end
		local playerState = stateService and stateService:GetState(player)
		local movementState = playerState and playerState.MovementState
		local isLaunching = movementState == "Launching"
		local isNormalLocomotion = movementState == "Moving" or movementState == "Idle"

		if isNormalLocomotion or isLauncherMovementControlling(root) then
			continue
		end

		local velocity = root.AssemblyLinearVelocity
		local pos = root.Position
		local arenaLimit = PhysicsConfig.World.MaxArenaRadius - PhysicsConfig.World.ArenaWallPadding
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

		-- Wall bounce only applies while locomotion is not actively controlling velocity.
		local hitWall = false
		if math.abs(pos.X) > arenaLimit then
			horizontal = Vector3.new(
				-horizontal.X * PhysicsConfig.World.WallRestitution,
				0,
				horizontal.Z * PhysicsConfig.World.WallTangentialDamping
			)
			hitWall = true
		end
		if math.abs(pos.Z) > arenaLimit then
			horizontal = Vector3.new(
				horizontal.X * PhysicsConfig.World.WallTangentialDamping,
				0,
				-horizontal.Z * PhysicsConfig.World.WallRestitution
			)
			hitWall = true
		end
		if hitWall then
			local now = os.clock()
			if not self._lastWallCollision[player]
				or now - self._lastWallCollision[player] >= PhysicsConfig.World.WallCollisionCooldown
			then
				self._lastWallCollision[player] = now
				root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
				self._context.EventBus:Fire("CollisionDetected", "Wall", player, nil,
					{ Speed = horizontal.Magnitude })
			end
			continue
		end

		-- Launching players remain client-owned; only uncontrolled movement gets server drag.
		if isLaunching then
			continue
		end

		-- Drag is reserved for physics-driven states after locomotion releases velocity control.
		local dragFactor = math.max(0, 1 - (PhysicsConfig.World.LinearDragPerSecond * dt))
		horizontal = horizontal * dragFactor
		if horizontal.Magnitude < PhysicsConfig.World.StopSpeed then
			horizontal = Vector3.zero
		end
		root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
	end
end

local function getCollisionKey(playerA: Player, playerB: Player): string
	return if playerA.UserId < playerB.UserId
		then `{playerA.UserId}:{playerB.UserId}`
		else `{playerB.UserId}:{playerA.UserId}`
end

local function getHorizontalVelocity(root: BasePart): Vector3
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end


local function getReportedHorizontalVelocity(payload: any): Vector3
	if payload and typeof(payload.velocity) == "Vector3" then
		local velocity = Vector3.new(payload.velocity.X, 0, payload.velocity.Z)
		if velocity.Magnitude <= PhysicsConfig.Collision.MaxAllowedSpeed then
			return velocity
		end
	end
	return Vector3.zero
end

local function resolveImpactVelocity(root: BasePart, payload: any, launchState: any): Vector3
	local rootVelocity = getHorizontalVelocity(root)
	local reportedVelocity = getReportedHorizontalVelocity(payload)
	local velocity = if rootVelocity.Magnitude >= reportedVelocity.Magnitude then rootVelocity else reportedVelocity

	local observedSpeed = if payload and typeof(payload.observedSpeed) == "number"
		then math.clamp(payload.observedSpeed, 0, PhysicsConfig.Collision.MaxAllowedSpeed)
		else 0
	local launchSpeed = math.max(launchState.currentSpeed or 0, launchState.initialSpeed or 0, observedSpeed)
	if velocity.Magnitude >= launchSpeed or typeof(launchState.direction) ~= "Vector3" then
		return velocity
	end
	local direction = Vector3.new(launchState.direction.X, 0, launchState.direction.Z)
	if direction.Magnitude < 0.001 then
		return velocity
	end
	return direction.Unit * launchSpeed
end

local function clampHorizontalVelocity(velocity: Vector3): Vector3
	local speed = velocity.Magnitude
	if speed <= PhysicsConfig.Collision.MinPostCollisionSpeed then
		return Vector3.zero
	end
	if speed > PhysicsConfig.Collision.MaxPostCollisionSpeed then
		return velocity.Unit * PhysicsConfig.Collision.MaxPostCollisionSpeed
	end
	return velocity
end

local function applyHorizontalVelocity(root: BasePart, horizontal: Vector3)
	local clamped = clampHorizontalVelocity(horizontal)
	root.AssemblyLinearVelocity = Vector3.new(clamped.X, root.AssemblyLinearVelocity.Y, clamped.Z)
end

local function updateLaunchFromVelocity(launchState, velocity: Vector3, energy: number, now: number)
	local speed = velocity.Magnitude
	if speed <= PhysicsConfig.Collision.MinPostCollisionSpeed or energy <= 0 then
		launchState.direction = Vector3.zero
		launchState.initialSpeed = 0
		launchState.currentSpeed = 0
		launchState.energy = 0
		launchState.startTime = now
		launchState.lastSampleTime = now
		return
	end
	launchState.direction = velocity.Unit
	launchState.initialSpeed = speed
	launchState.currentSpeed = speed
	launchState.energy = energy
	launchState.startTime = now
	launchState.lastSampleTime = now
end


function CollisionService:_validatePlayerReport(
	player: Player, payload: any
): (boolean, Player?, BasePart?, BasePart?, Vector3)
	local playerService = getService(self._context, "PlayerService")
	local stateService = getService(self._context, "PlayerStateService")
	if not (playerService and stateService) then
		return false, nil, nil, nil, Vector3.new(1, 0, 0)
	end

	local defender = Players:GetPlayerByUserId(payload.targetUserId)
	local root = playerService:GetRoot(player)
	local targetRoot = defender and playerService:GetRoot(defender)
	local attackerState = stateService:GetState(player)

	if not (defender and defender ~= player and root and targetRoot and attackerState
		and attackerState.MovementState == "Launching")
	then
		return false, nil, nil, nil, Vector3.new(1, 0, 0)
	end

	if not (playerService:IsAlive(player) and playerService:IsAlive(defender)) then
		return false, nil, nil, nil, Vector3.new(1, 0, 0)
	end

	local attackerReportedPos = if typeof(payload.currPos) == "Vector3" then payload.currPos else root.Position
	local rewindSeconds = math.clamp(player:GetNetworkPing(), 0, PhysicsConfig.Collision.PositionHistoryWindow)
	local defenderSample = self:_getClosestHistorySample(defender, os.clock() - rewindSeconds)
	local defenderPosition = if defenderSample then defenderSample.position else targetRoot.Position
	local reportedOffset = Vector3.new(attackerReportedPos.X - defenderPosition.X, 0, attackerReportedPos.Z - defenderPosition.Z)
	local maxPlanarDistance = PhysicsConfig.Collision.Range + PhysicsConfig.Collision.ValidationTolerance
	if reportedOffset.Magnitude > maxPlanarDistance then
		return false, defender, root, targetRoot, Vector3.new(1, 0, 0)
	end

	local offset = targetRoot.Position - root.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)
	local normal = if planar.Magnitude > PhysicsConfig.Movement.InputDeadzone
		then planar.Unit
		else Vector3.new(1, 0, 0)

	return true, defender, root, targetRoot, normal
end

function CollisionService:_resolveClientPlayerHit(player: Player, payload: any)
	local ok, defender, root, targetRoot, normal = self:_validatePlayerReport(player, payload)
	if not (ok and defender and root and targetRoot) then
		self:_firePvpFeedback(player, "PvpHitRejected", payload.targetUserId, root)
		return
	end
	local function reject()
		self:_firePvpFeedback(player, "PvpHitRejected", defender.UserId, root)
	end

	local key = getCollisionKey(player, defender)
	local now = os.clock()

	local launcherService = getService(self._context, "LauncherService")
	local stateService = getService(self._context, "PlayerStateService")
	if not (launcherService and stateService) then
		reject()
		return
	end
	if (stateService.IsHuman and stateService:IsHuman(player)) or stateService.HasFlag and (
		stateService:HasFlag(player, "Ghost") or stateService:HasFlag(defender, "Ghost")
	) then
		reject()
		return
	end
	local validLaunch, launchState = launcherService:ValidateLaunchReport(player, payload)
	if not validLaunch or not launchState then
		reject()
		return
	end
	local launchId = launchState.launchId
	if type(launchId) ~= "string" or launchId == "" then
		reject()
		return
	end
	self._lastCollisionByLaunchTarget[launchId] = self._lastCollisionByLaunchTarget[launchId] or {}
	local launchTargetKey = `Player:{defender.UserId}`
	local lastHitAt = self._lastCollisionByLaunchTarget[launchId][launchTargetKey]
	if lastHitAt and (now - lastHitAt) < SAME_TARGET_DEDUPE_SECONDS then
		reject()
		return
	end
	local attackerVelocity = resolveImpactVelocity(root, payload, launchState)
	local defenderVelocity = getHorizontalVelocity(targetRoot)
	local collisionResult = VelocityDecay.ResolvePlayerCollision(attackerVelocity, defenderVelocity, normal)
	local impactSpeed = collisionResult.ClosingSpeed
	if impactSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
		reject()
		return
	end
	if self._lastCollision[key] and now - self._lastCollision[key] < PhysicsConfig.Collision.Cooldown then
		reject()
		return
	end
	self._lastCollision[key] = now
	self._lastCollisionByLaunchTarget[launchId][launchTargetKey] = now

	local attackerAbsoluteSpeed = attackerVelocity.Magnitude
	local defenderOutRaw = collisionResult.DefenderVelocity
	local defenderOutRawSpeed = defenderOutRaw.Magnitude
	local maxDefenderOutSpeed = attackerAbsoluteSpeed * PhysicsConfig.Collision.DefenderVelocityTransferScale
	local defenderOut = if defenderOutRawSpeed <= maxDefenderOutSpeed
		then defenderOutRaw
		elseif maxDefenderOutSpeed <= 0
		then Vector3.zero
		else defenderOutRaw.Unit * maxDefenderOutSpeed
	local attackerOut = collisionResult.AttackerVelocity

	local canDamage = launcherService:RegisterLaunchDamageTarget(player, launchTargetKey)
	local canKnockback = launcherService:RegisterLaunchKnockbackTarget(player, launchTargetKey)
	if not canDamage and not canKnockback then
		reject()
		return
	end

	if canKnockback then
		applyHorizontalVelocity(root, attackerOut)
		updateLaunchFromVelocity(
			launchState,
			attackerOut,
			math.max(0, (launchState.energy or 0) * collisionResult.RemainingEnergyScale),
			now
		)
	end
	launchState.collisions = (launchState.collisions or 0) + 1

	local transferEnergy = math.max(0, (launchState.energy or 0) * collisionResult.TransferredEnergyScale)
	local shouldKnockback = canKnockback
		and transferEnergy >= PhysicsConfig.Collision.MinTransferEnergy
		and defenderOut.Magnitude > PhysicsConfig.Collision.MinPostCollisionSpeed
	if shouldKnockback then
		stateService:SetMovementState(defender, "Knockback")
		task.delay(PhysicsConfig.Collision.KnockbackImpulseDuration, function()
			local defenderState = stateService:GetState(defender)
			if defenderState and defenderState.MovementState == "Knockback" then
				stateService:SetMovementState(defender, "Idle")
			end
		end)
	end

	self._context.EventBus:Fire("CollisionDetected", "Launcher", player, defender, {
		Speed = impactSpeed,
		ImpactNormal = normal,
		AngleFactor = collisionResult.AngleFactor,
		NormalSpeed = collisionResult.NormalSpeed,
		TangentialSpeed = collisionResult.TangentialSpeed,
		LaunchEnergy = launchState.energy,
		AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
		CollisionCount = launchState.collisions,
		ChargeRatio = launchState.chargeRatio or 0,
		ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
	})
	if canDamage then
		self._context.EventBus:Fire("CollisionPlayerHit", defender, player, impactSpeed, normal, {
			SourceType = "PhysicalLauncherCollision",
			Duration = PhysicsConfig.Collision.KnockbackImpulseDuration,
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			AngleFactor = collisionResult.AngleFactor,
			NormalSpeed = collisionResult.NormalSpeed,
			TangentialSpeed = collisionResult.TangentialSpeed,
			InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			CollisionCount = launchState.collisions,
			LaunchEnergy = launchState.energy,
			ChargeRatio = launchState.chargeRatio or 0,
			ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
			TransferredEnergy = transferEnergy,
			TransferredVelocity = defenderOut.Magnitude,
			TransferredVelocityVector = defenderOut,
		})
	end
	if shouldKnockback then
		self._context.EventBus:Fire("CollisionPlayerKnockback", defender, player, defenderOut, {
			Duration = PhysicsConfig.Collision.KnockbackImpulseDuration,
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			AngleFactor = collisionResult.AngleFactor,
			NormalSpeed = collisionResult.NormalSpeed,
			TangentialSpeed = collisionResult.TangentialSpeed,
			InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			CollisionCount = launchState.collisions,
			TransferredEnergy = transferEnergy,
		})
	end
	self:_firePvpFeedback(player, "PvpHitConfirmed", defender.UserId, root)
end


function CollisionService:_bindClientCollisionReports()
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ReportCollision)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		if not RemoteContracts.Validate(RemoteContracts.Names.ReportCollision, payload) then
			return
		end
		if payload.targetType == "Player" then
			self:_resolveClientPlayerHit(player, payload)
		end
	end)
end

return CollisionService
