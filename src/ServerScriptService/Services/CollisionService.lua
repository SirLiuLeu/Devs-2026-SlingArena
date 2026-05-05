--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local PhysicsConfig = require(script.Parent.Parent.Config.PhysicsConfig)
local LaunchConfig = require(script.Parent.Parent.Config.LaunchModelConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)

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
			local dragFactor = math.max(0, 1 - Config.AirDrag * dt)
			horizontal *= dragFactor
			if horizontal.Magnitude < Config.StopVelocityThreshold then
				horizontal = Vector3.zero
			end
			local pos = root.Position
			local hitWall = false
			if math.abs(pos.X) > Config.MaxArenaRadius - BalanceConfig.ArenaWallPadding then
				horizontal = Vector3.new(-horizontal.X * (1 - Config.BounceLoss), 0, horizontal.Z)
				hitWall = true
			end
			if math.abs(pos.Z) > Config.MaxArenaRadius - BalanceConfig.ArenaWallPadding then
				horizontal = Vector3.new(horizontal.X, 0, -horizontal.Z * (1 - Config.BounceLoss))
				hitWall = true
			end
			if hitWall then
				local now = os.clock()
				if not self._lastWallCollision[player] or now - self._lastWallCollision[player] >= BalanceConfig.WallCollisionCooldown then
					self._lastWallCollision[player] = now
					self._context.EventBus:Fire("CollisionDetected", "Wall", player, nil, { Speed = velocity.Magnitude })
				end
			end
			root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
		end
	end
end

-- Detection only: returns candidate collisions, no domain mutations.
function CollisionService:_detectPlayerCollisions()
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		return {}
	end
	local list = Players:GetPlayers()
	local hits = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local playerA = list[i]
			local playerB = list[j]
			local rootA = playerService:GetRoot(playerA)
			local rootB = playerService:GetRoot(playerB)
			if rootA and rootB and playerService:IsAlive(playerA) and playerService:IsAlive(playerB) then
				local distance = (rootA.Position - rootB.Position).Magnitude
				local hitDistance = (rootA.Size.X + rootB.Size.X) * BalanceConfig.PlayerCollisionDistanceFactor
				if distance <= hitDistance then
					local key = if playerA.UserId < playerB.UserId then `{playerA.UserId}:{playerB.UserId}` else `{playerB.UserId}:{playerA.UserId}`
					local now = os.clock()
					if not self._lastCollision[key] or now - self._lastCollision[key] >= BalanceConfig.CollisionCooldown then
						self._lastCollision[key] = now
						table.insert(hits, { playerA = playerA, playerB = playerB, rootA = rootA, rootB = rootB })
					end
				end
			end
		end
	end
	return hits
end

local function getHorizontalVelocity(root: BasePart): Vector3
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

local function applyHorizontalVelocity(root: BasePart, horizontal: Vector3)
	root.AssemblyLinearVelocity = Vector3.new(horizontal.X, root.AssemblyLinearVelocity.Y, horizontal.Z)
end

local function updateLaunchFromVelocity(launchState, velocity: Vector3, energy: number, now: number)
	local speed = velocity.Magnitude
	if speed <= LaunchConfig.Collision.MinPostCollisionSpeed or energy <= 0 then
		launchState.direction = Vector3.zero
		launchState.initialSpeed = 0
		launchState.currentSpeed = 0
		launchState.energy = 0
		launchState.startTime = now
		return
	end

	launchState.direction = velocity.Unit
	launchState.initialSpeed = speed
	launchState.currentSpeed = speed
	launchState.energy = energy
	launchState.startTime = now
end

-- Resolution only: physics + event emission; damage is applied by DamagePipelineService.
function CollisionService:_resolvePlayerCollisions(hits)
	local slingService = getService(self._context, "SlingService")
	for _, hit in ipairs(hits) do
		local stateService = getService(self._context, "PlayerStateService")
		local stateA = stateService and stateService:GetState(hit.playerA)
		local stateB = stateService and stateService:GetState(hit.playerB)
		if not (stateA and stateB) then
			continue
		end
		local va = getHorizontalVelocity(hit.rootA)
		local vb = getHorizontalVelocity(hit.rootB)
		local normal = hit.rootB.Position - hit.rootA.Position
		normal = Vector3.new(normal.X, 0, normal.Z)
		if normal.Magnitude < 0.001 then
			normal = Vector3.new(1, 0, 0)
		end
		normal = normal.Unit
		local rel = va - vb
		local impactSpeed = math.max(0, rel:Dot(normal))
		if impactSpeed < LaunchConfig.Collision.MinImpactSpeed then
			continue
		end
		local launchA = slingService and slingService._activeLaunches and slingService._activeLaunches[hit.playerA]
		local launchB = slingService and slingService._activeLaunches and slingService._activeLaunches[hit.playerB]
		local energyA = launchA and launchA.energy or 0
		local energyB = launchB and launchB.energy or 0
		local attacker, defender = hit.playerA, hit.playerB
		local attackerRoot, defenderRoot = hit.rootA, hit.rootB
		local attackerLaunch = launchA
		local attackerVelocity, defenderVelocity = va, vb
		if energyB > energyA then
			attacker, defender = defender, attacker
			attackerRoot, defenderRoot = defenderRoot, attackerRoot
			attackerLaunch = launchB
			attackerVelocity, defenderVelocity = defenderVelocity, attackerVelocity
			normal = -normal
			rel = -rel
		end
		if not attackerLaunch then
			continue
		end
		
		local now = os.clock()
		local originalLaunchStartTime = attackerLaunch.startTime or now
		local preCollisionEnergy = math.max(0, attackerLaunch.energy or 0)
		local relativeNormalVelocity = normal * rel:Dot(normal)
		local relativeTangentVelocity = rel - relativeNormalVelocity
		local outgoingRelativeVelocity = (relativeTangentVelocity * LaunchConfig.Collision.TangentialDamping)
			- (relativeNormalVelocity * LaunchConfig.Collision.Restitution)
		local remainingEnergy = preCollisionEnergy * (1 - LaunchConfig.Energy.CollisionLossRatio)
		local energyRetention = if preCollisionEnergy > 0 then remainingEnergy / preCollisionEnergy else 0
		local outgoingVelocity = defenderVelocity + (outgoingRelativeVelocity * energyRetention)
		local postSpeed = outgoingVelocity.Magnitude
		if postSpeed <= LaunchConfig.Collision.MinPostCollisionSpeed or remainingEnergy <= 0 then
			outgoingVelocity = Vector3.zero
		end

		attackerLaunch.collisions += 1
				updateLaunchFromVelocity(attackerLaunch, outgoingVelocity, remainingEnergy, now)
		applyHorizontalVelocity(attackerRoot, outgoingVelocity)

		local angleFactor = math.clamp(impactSpeed / math.max(attackerVelocity.Magnitude, 0.001), 0, 1)
		local energyFactor = math.clamp(preCollisionEnergy / math.max(LaunchConfig.Energy.Max, 1), 0, 1)
		local transferEnergy = math.max(0, preCollisionEnergy * LaunchConfig.Collision.EnergyTransferRatio * angleFactor)
		local transferSpeed = math.min(
			LaunchConfig.Collision.MaxTransferSpeed,
			impactSpeed * LaunchConfig.Collision.EnergyTransferRatio * angleFactor * energyFactor
		)
		if transferSpeed > 0 then
			local transferredVelocity = defenderVelocity + (normal * transferSpeed)
			applyHorizontalVelocity(defenderRoot, transferredVelocity)
			if slingService
				and slingService._activeLaunches
				and transferEnergy >= LaunchConfig.Energy.MinTransferEnergy
				and transferSpeed > LaunchConfig.Collision.MinPostCollisionSpeed
			then
				local transferredSpeed = transferredVelocity.Magnitude
				slingService._activeLaunches[defender] = {
										direction = if transferredSpeed > 0.001 then transferredVelocity.Unit else normal,
					initialSpeed = transferredSpeed,
					currentSpeed = transferredSpeed,
					energy = transferEnergy * LaunchConfig.Energy.ChainHitDecayMultiplier,
					startTime = now,
					duration = 1.1,
					chargeRatio = 0.3,
					collisions = attackerLaunch.collisions,
					sourcePlayer = attacker,
				}
			end
		end
		self._context.EventBus:Fire("CollisionDetected", "Sling", attacker, defender, {
			Speed = impactSpeed,
			ImpactNormal = normal,
			LaunchEnergy = attackerLaunch.energy,
			CollisionCount = attackerLaunch.collisions,
		})
		self._context.EventBus:Fire("CollisionPlayerHit", defender, attacker, impactSpeed, normal, {
			LaunchEnergy = attackerLaunch.energy,
			CollisionCount = attackerLaunch.collisions,
			ElapsedLaunchTime = now - originalLaunchStartTime,
			ImpactSpeed = impactSpeed,
			TransferredSpeed = transferSpeed,
			ImpactSpeed = impactSpeed,
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
