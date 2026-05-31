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

local MAX_COLLISIONS_PER_LAUNCH = 3
local SAME_TARGET_DEDUPE_SECONDS = 0.28

function CollisionService.new(context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._lastCollision = {}
	self._lastCollisionByLaunchTarget = {}
	self._lastTrapCollision = {}
	self._lastWallCollision = {}
	return self
end

function CollisionService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_applyDragAndBounce(dt)
	end)
	self:_bindClientCollisionReports()
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
		local playerState = stateService and stateService:GetState(player)
		local isLaunching = playerState and playerState.MovementState == "Launching"

		local velocity = root.AssemblyLinearVelocity
		local pos = root.Position
		local arenaLimit = PhysicsConfig.World.MaxArenaRadius - PhysicsConfig.World.ArenaWallPadding
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

		-- Wall bounce is checked for all players so collision events still fire.
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

		-- Launching players remain client-owned; only normal movement gets server drag.
		if isLaunching then
			continue
		end

		-- Normal movement drag (unchanged).
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

local function sqrDistanceXZ(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end


local function isLaunchValidationActive(player: Player, movementState: string?): boolean
	if movementState == "Launching" then
		return true
	end
	local graceEndsAt = player:GetAttribute("LaunchValidationGraceEndsAt")
	return typeof(graceEndsAt) == "number" and os.clock() <= graceEndsAt
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
		and isLaunchValidationActive(player, attackerState.MovementState))
	then
		return false, nil, nil, nil, Vector3.new(1, 0, 0)
	end

	if not (playerService:IsAlive(player) and playerService:IsAlive(defender)) then
		return false, nil, nil, nil, Vector3.new(1, 0, 0)
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
		return
	end
	local key = getCollisionKey(player, defender)
	local now = os.clock()

	local slingService = getService(self._context, "SlingService")
	local stateService = getService(self._context, "PlayerStateService")
	if not (slingService and stateService) then
		return
	end
	if stateService.HasFlag and (
		stateService:HasFlag(player, "Ghost") or stateService:HasFlag(defender, "Ghost")
	) then
		return
	end
	local launchState = slingService:GetLaunchState(player)
	if not launchState then
		launchState = {
			direction = Vector3.zero,
			initialSpeed = 0,
			currentSpeed = 0,
			energy = 0,
			startTime = now,
			lastSampleTime = now,
			collisions = 0,
		}
	end
	launchState.collisions = launchState.collisions or 0
	launchState.startTime = launchState.startTime or now
	if launchState.collisions >= MAX_COLLISIONS_PER_LAUNCH then
		return
	end
	local launchId = string.format("%d:%.6f", player.UserId, launchState.startTime)
	self._lastCollisionByLaunchTarget[launchId] = self._lastCollisionByLaunchTarget[launchId] or {}
	local launchTargetKey = tostring(defender.UserId)
	local lastHitAt = self._lastCollisionByLaunchTarget[launchId][launchTargetKey]
	if lastHitAt and (now - lastHitAt) < SAME_TARGET_DEDUPE_SECONDS then
		return
	end

	local attackerVelocity = resolveImpactVelocity(root, payload, launchState)
	local impactSpeed = attackerVelocity.Magnitude
	if impactSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
		return
	end
	if self._lastCollision[key] and now - self._lastCollision[key] < PhysicsConfig.Collision.Cooldown then
		return
	end
	self._lastCollision[key] = now
	self._lastCollisionByLaunchTarget[launchId][launchTargetKey] = now

	local collision = VelocityDecay.ResolvePlayerCollision(attackerVelocity, normal)
	local transferRatio = collision.TransferredEnergyScale
	local defenderOut = collision.DefenderVelocity
	local attackerOut = collision.AttackerVelocity

	-- [FIX 3 note] Server write velocity sau collision vẫn OK:
	-- Với player-owned root, client nhận correction sau ~1 frame.
	-- Collision là event đặc biệt — 1 frame correction acceptable và ít thấy hơn stamp mỗi frame.
	applyHorizontalVelocity(root, attackerOut)
	if typeof(slingService._sendVelocityCorrection) == "function" then
		slingService:_sendVelocityCorrection(player, attackerOut, "collision_reduction")
	end

	updateLaunchFromVelocity(
		launchState,
		attackerOut,
		math.max(0, (launchState.energy or 0) * collision.RemainingEnergyScale),
		now
	)
	launchState.collisions = (launchState.collisions or 0) + 1

	local transferEnergy = math.max(0, (launchState.energy or 0) * transferRatio)
	local shouldKnockback = transferEnergy >= PhysicsConfig.Collision.MinTransferEnergy
		and defenderOut.Magnitude > PhysicsConfig.Collision.MinPostCollisionSpeed
	if shouldKnockback then
		stateService:SetMovementState(defender, "Knockback")
		task.delay(0.1, function()
			local defenderState = stateService:GetState(defender)
			if defenderState and defenderState.MovementState == "Knockback" then
				stateService:SetMovementState(defender, "Idle")
			end
		end)
	end

	self._context.EventBus:Fire("CollisionDetected", "Sling", player, defender, {
		Speed = impactSpeed,
		ImpactNormal = normal,
		LaunchEnergy = launchState.energy,
		CollisionCount = launchState.collisions,
		ChargeRatio = launchState.chargeRatio or 0,
		ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
	})
	self._context.EventBus:Fire("CollisionPlayerHit", defender, player, impactSpeed, normal, {
		Duration = 0.1,
		ImpactNormal = normal,
		ImpactSpeed = impactSpeed,
		InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
		CollisionCount = launchState.collisions,
		LaunchEnergy = launchState.energy,
		ChargeRatio = launchState.chargeRatio or 0,
		ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
		TransferredEnergy = transferEnergy,
	})
	if shouldKnockback then
		self._context.EventBus:Fire("CollisionPlayerKnockback", defender, player, defenderOut, {
			Duration = 0.1,
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
			CollisionCount = launchState.collisions,
			TransferredEnergy = transferEnergy,
		})
	end
end

function CollisionService:_resolveClientTrapHit(player: Player, payload: any)
	local playerService = getService(self._context, "PlayerService")
	local mapService = getService(self._context, "MapService")
	if not (playerService and mapService and typeof(mapService.GetTrapBlocks) == "function") then
		return
	end
	local root = playerService:GetRoot(player)
	if not (root and playerService:IsAlive(player)) then
		return
	end
	local reported = payload.targetPosition
	local tolerance = PhysicsConfig.Collision.ValidationTolerance
	for _, trap in mapService:GetTrapBlocks() do
		local halfRange = math.max(trap.Size.X, trap.Size.Z) * 0.5
			+ math.max(root.Size.X, root.Size.Z) * 0.5
			+ tolerance
		if sqrDistanceXZ(reported, trap.Position) <= halfRange * halfRange
			or sqrDistanceXZ(root.Position, trap.Position) <= halfRange * halfRange
		then
			local key = `{player.UserId}:{trap:GetDebugId(0)}`
			local now = os.clock()
			if not self._lastTrapCollision[key]
				or now - self._lastTrapCollision[key] > PhysicsConfig.Collision.TrapCooldown
			then
				self._lastTrapCollision[key] = now
				self._context.EventBus:Fire("CollisionDetected", "Trap", player, trap, {})
				self._context.EventBus:Fire("TrapCollisionCandidate", player, trap)
			end
			return
		end
	end
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
		elseif payload.targetType == "Trap" then
			self:_resolveClientTrapHit(player, payload)
		end
	end)
end

return CollisionService
