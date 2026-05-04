--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local PhysicsConfig = require(script.Parent.Parent.Config.PhysicsConfig)
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
	self._lastPosition = {}
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
				local previousA = self._lastPosition[playerA] or rootA.Position
				local previousB = self._lastPosition[playerB] or rootB.Position
				local sweepMidA = (previousA + rootA.Position) * 0.5
				local sweepMidB = (previousB + rootB.Position) * 0.5
				local distance = math.min((rootA.Position - rootB.Position).Magnitude, (sweepMidA - sweepMidB).Magnitude)
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
		self._lastPosition[playerA] = rootA and rootA.Position or self._lastPosition[playerA]
	end
	return hits
end

-- Resolution only: physics + event emission; damage is applied by DamagePipelineService.
function CollisionService:_resolvePlayerCollisions(hits)
	for _, hit in ipairs(hits) do
		local stateService = getService(self._context, "PlayerStateService")
		local damageService = getService(self._context, "DamagePipelineService")
		local launchSessionService = getService(self._context, "LaunchSessionService")
		local stateA = stateService and stateService:GetState(hit.playerA)
		local stateB = stateService and stateService:GetState(hit.playerB)
		local launchState = GameStates.PlayerState.Launching
		if not (stateA and stateB) or (stateA.MovementState ~= launchState and stateB.MovementState ~= launchState) then
			continue
		end
		local sizeA = stateA.Size or 1
		local sizeB = stateB and stateB.Size or 1
		local massA = Config.Mass * sizeA
		local massB = Config.Mass * sizeB
		local momentumA = hit.rootA.AssemblyLinearVelocity.Magnitude * massA
		local momentumB = hit.rootB.AssemblyLinearVelocity.Magnitude * massB

		local winner = if momentumA >= momentumB then hit.playerA else hit.playerB
		local loser = if winner == hit.playerA then hit.playerB else hit.playerA
		local loserRoot = if loser == hit.playerA then hit.rootA else hit.rootB
		local winnerRoot = if winner == hit.playerA then hit.rootA else hit.rootB
		local attackerState = if winner == hit.playerA then stateA else stateB
		local defenderState = if loser == hit.playerA then stateA else stateB
		if attackerState and defenderState then
			local attackerSession = launchSessionService and launchSessionService:GetSession(winner)
			if not (attackerSession and launchSessionService:IsHitValid(attackerSession)) then
				continue
			end
			local targetMarker = tostring(loser.UserId)
			local now = os.clock()
			local lastHitAt = attackerSession.HitTargets[targetMarker]
			if lastHitAt and (now - lastHitAt) < PhysicsConfig.LaunchModel.RepeatedTargetCooldown then
				continue
			end
			local velocityMagnitude = winnerRoot.AssemblyLinearVelocity.Magnitude
			local impactDirection = loserRoot.Position - winnerRoot.Position
			local damage = damageService and damageService:ComputeCollisionDamage(attackerState, velocityMagnitude, attackerSession) or 0
			local knockback = damageService and damageService:ComputeCollisionKnockback(attackerState, defenderState, impactDirection, velocityMagnitude, attackerSession) or Vector3.zero
			local impulseScale = PhysicsConfig.Collision and PhysicsConfig.Collision.PlayerImpulseScale or 45
			local minImpulse = PhysicsConfig.Collision and PhysicsConfig.Collision.MinImpulse or 500
			local maxImpulse = PhysicsConfig.Collision and PhysicsConfig.Collision.MaxImpulse or 9000
			local rawImpulse = math.clamp(knockback.Magnitude * impulseScale, minImpulse, maxImpulse)
			local impulseDir = impactDirection.Magnitude > 1e-4 and impactDirection.Unit or Vector3.new(0, 0, 1)
			loserRoot:ApplyImpulse(impulseDir * rawImpulse)
			self._context.EventBus:Fire("CollisionDetected", "Sling", winner, loser, { Speed = velocityMagnitude, ChargeRatio = attackerState.ChargeValue })
			self._context.EventBus:Fire("CollisionPlayerHit", loser, winner, damage, knockback, { ChargeRatio = attackerState.ChargeValue, VelocityMagnitude = velocityMagnitude })
			attackerSession.HitCount += 1
			attackerSession.LastHitTime = now
			attackerSession.HitTargets[targetMarker] = now
			attackerSession.EnergyLeft = math.max(0, attackerSession.EnergyLeft - (0.16 + (attackerSession.HitCount * 0.04)))
			local decay = math.clamp(BalanceConfig.VelocityDecayFactor * attackerSession.EnergyLeft, 0, 1)
			winnerRoot.AssemblyLinearVelocity *= decay
			local transferRatio = PhysicsConfig.LaunchModel.MinTransferRatio + ((PhysicsConfig.LaunchModel.MaxTransferRatio - PhysicsConfig.LaunchModel.MinTransferRatio) * attackerSession.ChargeRatio)
			local transferredSpeed = velocityMagnitude * transferRatio * attackerSession.EnergyLeft
			if transferRatio > 0 and launchSessionService then
				local dir = impactDirection.Magnitude > 0.001 and impactDirection.Unit or Vector3.new(1, 0, 0)
				launchSessionService:StartSession(loser, dir, attackerSession.ChargeRatio * 0.85, transferredSpeed)
			end
		end
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
