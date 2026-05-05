--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local CollisionService = {}
CollisionService.__index = CollisionService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
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
		local playerHits = self:_detectPlayerCollisions()
		self:_resolvePlayerCollisions(playerHits)
		self:_resolveTrapCollisions()
	end)
end

function CollisionService:_applyDragAndBounce(dt)
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = playerService:GetRoot(player)
		if root and playerService:IsAlive(player) then
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
				if not self._lastWallCollision[player] or now - self._lastWallCollision[player] >= PhysicsConfig.World.WallCollisionCooldown then
					self._lastWallCollision[player] = now
					self._context.EventBus:Fire("CollisionDetected", "Wall", player, nil, { Speed = horizontal.Magnitude })
				end
			end
			root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
		end
	end
end

local function getCollisionKey(playerA: Player, playerB: Player): string
	return if playerA.UserId < playerB.UserId then `{playerA.UserId}:{playerB.UserId}` else `{playerB.UserId}:{playerA.UserId}`
end

-- Candidate phase only: detects possible contact without consuming cooldowns, damage, or momentum.
function CollisionService:_detectPlayerCollisions()
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		return {}
	end
	local list = Players:GetPlayers()
	local candidates = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local playerA = list[i]
			local playerB = list[j]
			local rootA = playerService:GetRoot(playerA)
			local rootB = playerService:GetRoot(playerB)
			if rootA and rootB and playerService:IsAlive(playerA) and playerService:IsAlive(playerB) then
				local offset = rootB.Position - rootA.Position
				local planarOffset = Vector3.new(offset.X, 0, offset.Z)
				local distance = planarOffset.Magnitude
				local contactDistance = ((rootA.Size.X + rootB.Size.X) * PhysicsConfig.Collision.CandidateDistanceFactor)
					+ PhysicsConfig.Collision.CandidateExtraPadding
				if distance <= contactDistance then
					local normal = if distance > 0.001 then planarOffset.Unit else Vector3.new(1, 0, 0)
					table.insert(candidates, {
						playerA = playerA,
						playerB = playerB,
						rootA = rootA,
						rootB = rootB,
						normal = normal,
						distance = distance,
						contactDistance = contactDistance,
						key = getCollisionKey(playerA, playerB),
					})
				end
			end
		end
	end
	return candidates
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

local function isRealHitCandidate(hit, launchA, launchB, stateA, stateB, closingSpeed: number): boolean
	if closingSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
		return false
	end
	local energyA = launchA and math.max(0, launchA.energy or 0) or 0
	local energyB = launchB and math.max(0, launchB.energy or 0) or 0
	if math.max(energyA, energyB) < PhysicsConfig.Collision.MinLaunchEnergy then
		return false
	end
	if stateA.MovementState ~= "Launching" and stateB.MovementState ~= "Launching" then
		return false
	end
	return hit.distance <= hit.contactDistance
end

local function resolveBilliardsVelocity(va: Vector3, vb: Vector3, normal: Vector3, massA: number, massB: number): (Vector3, Vector3, number, Vector3)
	local closingSpeed = math.max(0, (va - vb):Dot(normal))
	local inverseMassA = 1 / math.max(massA, 0.001)
	local inverseMassB = 1 / math.max(massB, 0.001)
	local impulseMagnitude = ((1 + PhysicsConfig.Collision.Restitution) * closingSpeed) / (inverseMassA + inverseMassB)
	local normalImpulse = normal * impulseMagnitude

	local vaOut = va - (normalImpulse * inverseMassA)
	local vbOut = vb + (normalImpulse * inverseMassB)

	local relativeVelocity = va - vb
	local tangentVelocity = relativeVelocity - (normal * relativeVelocity:Dot(normal))
	local tangentLoss = tangentVelocity * ((1 - PhysicsConfig.Collision.TangentialDamping) * 0.5)
	vaOut -= tangentLoss
	vbOut += tangentLoss

	return vaOut, vbOut, closingSpeed, tangentVelocity
end

local function chooseAttacker(playerA: Player, playerB: Player, launchA, launchB, normal: Vector3, va: Vector3, vb: Vector3): (Player, Player, any, any, Vector3)
	local energyA = launchA and math.max(0, launchA.energy or 0) or 0
	local energyB = launchB and math.max(0, launchB.energy or 0) or 0
	local contributionA = energyA + math.max(0, va:Dot(normal))
	local contributionB = energyB + math.max(0, vb:Dot(-normal))
	if contributionB > contributionA then
		return playerB, playerA, launchB, launchA, -normal
	end
	return playerA, playerB, launchA, launchB, normal
end

-- Real-hit phase only: validates relative motion/cooldown/energy, then applies momentum and emits damage events.
function CollisionService:_resolvePlayerCollisions(candidates)
	local slingService = getService(self._context, "SlingService")
	local stateService = getService(self._context, "PlayerStateService")
	if not (slingService and stateService) then
		return
	end

	for _, hit in ipairs(candidates) do
		local stateA = stateService:GetState(hit.playerA)
		local stateB = stateService:GetState(hit.playerB)
		if not (stateA and stateB) then
			continue
		end

		local va = getHorizontalVelocity(hit.rootA)
		local vb = getHorizontalVelocity(hit.rootB)
		local closingSpeed = math.max(0, (va - vb):Dot(hit.normal))
		local launchA = slingService:GetLaunchState(hit.playerA)
		local launchB = slingService:GetLaunchState(hit.playerB)
		if not isRealHitCandidate(hit, launchA, launchB, stateA, stateB, closingSpeed) then
			continue
		end

		local now = os.clock()
		if self._lastCollision[hit.key] and now - self._lastCollision[hit.key] < PhysicsConfig.Collision.Cooldown then
			continue
		end
		self._lastCollision[hit.key] = now

		local massA = hit.rootA.AssemblyMass
		local massB = hit.rootB.AssemblyMass
		local vaOut, vbOut, impactSpeed, tangentVelocity = resolveBilliardsVelocity(va, vb, hit.normal, massA, massB)
		applyHorizontalVelocity(hit.rootA, vaOut)
		applyHorizontalVelocity(hit.rootB, vbOut)

		local attacker, defender, attackerLaunch, defenderLaunch, impactNormal = chooseAttacker(hit.playerA, hit.playerB, launchA, launchB, hit.normal, va, vb)
		if not attackerLaunch then
			continue
		end

		local originalLaunchStartTime = attackerLaunch.startTime or now
		local preCollisionEnergy = math.max(0, attackerLaunch.energy or 0)
		local angleFactor = math.clamp(impactSpeed / math.max((if attacker == hit.playerA then va else vb).Magnitude, 0.001), 0, 1)
		local remainingEnergy = preCollisionEnergy * (1 - PhysicsConfig.Collision.CollisionEnergyLossRatio)
		local transferEnergy = preCollisionEnergy * PhysicsConfig.Collision.EnergyTransferRatio * angleFactor
		local attackerVelocityOut = if attacker == hit.playerA then vaOut else vbOut
		local defenderVelocityOut = if defender == hit.playerA then vaOut else vbOut
		updateLaunchFromVelocity(attackerLaunch, attackerVelocityOut, remainingEnergy, now)
		attackerLaunch.collisions = (attackerLaunch.collisions or 0) + 1

		if transferEnergy >= PhysicsConfig.Collision.MinTransferEnergy and defenderVelocityOut.Magnitude > PhysicsConfig.Collision.MinPostCollisionSpeed then
			local nextDefenderEnergy = transferEnergy * PhysicsConfig.Collision.ChainHitEnergyRetention
			if defenderLaunch then
				updateLaunchFromVelocity(defenderLaunch, defenderVelocityOut, math.max(defenderLaunch.energy or 0, nextDefenderEnergy), now)
			else
				slingService:SetLaunchState(defender, {
					direction = defenderVelocityOut.Unit,
					initialSpeed = defenderVelocityOut.Magnitude,
					currentSpeed = defenderVelocityOut.Magnitude,
					energy = nextDefenderEnergy,
					startTime = now,
					lastSampleTime = now,
					chargeRatio = 0,
					collisions = (attackerLaunch.collisions or 0),
					sourcePlayer = attacker,
				})
				stateService:SetMovementState(defender, "Launching")
			end
		end

		self._context.EventBus:Fire("CollisionDetected", "Sling", attacker, defender, {
			Speed = impactSpeed,
			ImpactNormal = impactNormal,
			LaunchEnergy = attackerLaunch.energy,
			CollisionCount = attackerLaunch.collisions,
			TangentialSpeed = tangentVelocity.Magnitude,
		})
		self._context.EventBus:Fire("CollisionPlayerHit", defender, attacker, impactSpeed, impactNormal, {
			LaunchEnergy = attackerLaunch.energy,
			CollisionCount = attackerLaunch.collisions,
			ElapsedLaunchTime = now - originalLaunchStartTime,
			ImpactSpeed = impactSpeed,
			AngleFactor = angleFactor,
			TransferredEnergy = transferEnergy,
		})
	end
end

function CollisionService:_resolveGateCollisions()
	return
end

function CollisionService:_resolveTrapCollisions()
	local mapService = getService(self._context, "MapService")
	if not mapService or typeof(mapService.GetTrapBlocks) ~= "function" then
		return
	end
	for _, trap in mapService:GetTrapBlocks() do
		local playerService = getService(self._context, "PlayerService")
		if not playerService then
			return
		end
		for _, player in Players:GetPlayers() do
			local root = playerService:GetRoot(player)
			if root and playerService:IsAlive(player) then
				local localPos = trap.CFrame:PointToObjectSpace(root.Position)
				local half = trap.Size * 0.5
				if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
					local key = `{player.UserId}:{trap:GetDebugId(0)}`
					local now = os.clock()
					if not self._lastTrapCollision[key] or now - self._lastTrapCollision[key] > BalanceConfig.TrapCollisionCooldown then
						self._lastTrapCollision[key] = now
						self._context.EventBus:Fire("CollisionDetected", "Trap", player, trap, {})
						self._context.EventBus:Fire("TrapCollisionCandidate", player, trap)
					end
				end
			end
		end
	end
end


function CollisionService:_resolveExitZones()
	return
end

return CollisionService
