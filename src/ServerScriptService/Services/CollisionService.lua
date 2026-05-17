--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local CollisionService = {}
CollisionService.__index = CollisionService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function applyHorizontalVelocityWithImpulse(root: BasePart, horizontal: Vector3)
	local velocity = root.AssemblyLinearVelocity
	local currentHorizontal = Vector3.new(velocity.X, 0, velocity.Z)
	root:ApplyImpulse((horizontal - currentHorizontal) * root.AssemblyMass)
end

function CollisionService.new(context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._lastCollision = {}
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

--[[
	CHANGED: Skip drag for players in "Launching" state.

	Launching players are excluded from world drag. SlingService applies launch-specific
	VectorForce drag so launch deceleration remains physics-driven.

	Wall bounce logic is unchanged — it correctly flips velocity components and fires
	the CollisionDetected event. Launching players can still wall-bounce.
]]
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

		-- CHANGED: Skip linear drag for Launching players.
		-- SlingService owns physics-based VectorForce drag during launch.
		if playerState and playerState.MovementState == "Launching" then
			-- Still apply wall bounce for Launching players (they should bounce off walls).
			local velocity = root.AssemblyLinearVelocity
			local pos = root.Position
			local arenaLimit = PhysicsConfig.World.MaxArenaRadius - PhysicsConfig.World.ArenaWallPadding
			local hitWall = false
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

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
					applyHorizontalVelocityWithImpulse(root, horizontal)
					self._context.EventBus:Fire("CollisionDetected", "Wall", player, nil,
						{ Speed = horizontal.Magnitude })
				end
			end
			continue
		end

		-- Normal movement drag (unchanged from original).
		local velocity = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		local dragFactor = math.max(0, 1 - (PhysicsConfig.World.LinearDragPerSecond * dt))
		horizontal *= dragFactor
		if horizontal.Magnitude < PhysicsConfig.World.StopSpeed then
			horizontal = Vector3.zero
		end

		local pos = root.Position
		local arenaLimit = PhysicsConfig.World.MaxArenaRadius - PhysicsConfig.World.ArenaWallPadding
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
				self._context.EventBus:Fire("CollisionDetected", "Wall", player, nil,
					{ Speed = horizontal.Magnitude })
			end
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
	applyHorizontalVelocityWithImpulse(root, clamped)
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

local function reportPosition(payload: any, fallback: Vector3): Vector3
	return if payload and typeof(payload.currPos) == "Vector3" then payload.currPos else fallback
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
	local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local targetRadius = math.max(targetRoot.Size.X, targetRoot.Size.Z) * 0.5
	local tolerance = PhysicsConfig.Collision.ValidationTolerance
	local range = playerRadius + targetRadius + tolerance
	local pos = reportPosition(payload, root.Position)
	if sqrDistanceXZ(root.Position, targetRoot.Position) > range * range
		and sqrDistanceXZ(pos, targetRoot.Position) > range * range
	then
		return false, nil, nil, nil, Vector3.new(1, 0, 0)
	end
	local offset = targetRoot.Position - root.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)
	local normal = if planar.Magnitude > PhysicsConfig.Movement.InputDeadzone then planar.Unit else Vector3.new(1, 0, 0)
	return true, defender, root, targetRoot, normal
end

function CollisionService:_resolveClientPlayerHit(player: Player, payload: any)
	local ok, defender, root, targetRoot, normal = self:_validatePlayerReport(player, payload)
	if not (ok and defender and root and targetRoot) then
		return
	end
	local key = getCollisionKey(player, defender)
	local now = os.clock()
	if self._lastCollision[key]
		and now - self._lastCollision[key] < PhysicsConfig.Collision.Cooldown
	then
		return
	end
	self._lastCollision[key] = now

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
		return
	end

	local attackerVelocity = getHorizontalVelocity(root)
	local impactSpeed = attackerVelocity.Magnitude
	if impactSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
		return
	end

	-- Use the collision normal (from server-computed hit direction) for
	-- bounce direction rather than arbitrary velocity reversal.
	local transferSpeed = math.clamp(
		impactSpeed * PhysicsConfig.Collision.EnergyTransferRatio,
		0, PhysicsConfig.Collision.MaxPostCollisionSpeed
	)
	local defenderOut = normal * transferSpeed
	local attackerOut = attackerVelocity * (1 - PhysicsConfig.Collision.CollisionEnergyLossRatio)

	applyHorizontalVelocity(root, attackerOut)
	applyHorizontalVelocity(targetRoot, defenderOut)

	updateLaunchFromVelocity(
		launchState,
		attackerOut,
		math.max(0, (launchState.energy or 0) * (1 - PhysicsConfig.Collision.CollisionEnergyLossRatio)),
		now
	)
	launchState.collisions = (launchState.collisions or 0) + 1

	local transferEnergy = math.max(0, (launchState.energy or 0) * PhysicsConfig.Collision.EnergyTransferRatio)
	if transferEnergy >= PhysicsConfig.Collision.MinTransferEnergy
		and defenderOut.Magnitude > PhysicsConfig.Collision.MinPostCollisionSpeed
	then
		slingService:SetLaunchState(defender, {
			direction = defenderOut.Unit,
			initialSpeed = defenderOut.Magnitude,
			currentSpeed = defenderOut.Magnitude,
			energy = transferEnergy,
			startTime = now,
			lastSampleTime = now,
			chargeRatio = 0,
			collisions = launchState.collisions,
			sourcePlayer = player,
		})
		stateService:SetMovementState(defender, "Launching")
	end

	self._context.EventBus:Fire("CollisionDetected", "Sling", player, defender, {
		Speed = impactSpeed,
		ImpactNormal = normal,
		LaunchEnergy = launchState.energy,
		CollisionCount = launchState.collisions,
	})
	self._context.EventBus:Fire("CollisionPlayerHit", defender, player, impactSpeed, normal, {
		LaunchEnergy = launchState.energy,
		CollisionCount = launchState.collisions,
		ImpactSpeed = impactSpeed,
		TransferredEnergy = transferEnergy,
	})
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