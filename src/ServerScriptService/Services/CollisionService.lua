--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local CollisionService = {}
CollisionService.__index = CollisionService

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
	for _, player in Players:GetPlayers() do
		local root = self._context.Services.PlayerService:GetRoot(player)
		if root and self._context.Services.PlayerService:IsAlive(player) then
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
	local list = Players:GetPlayers()
	local hits = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local playerA = list[i]
			local playerB = list[j]
			local rootA = self._context.Services.PlayerService:GetRoot(playerA)
			local rootB = self._context.Services.PlayerService:GetRoot(playerB)
			if rootA and rootB and self._context.Services.PlayerService:IsAlive(playerA) and self._context.Services.PlayerService:IsAlive(playerB) then
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

-- Resolution only: physics + event emission; damage is applied by DamagePipelineService.
function CollisionService:_resolvePlayerCollisions(hits)
	for _, hit in ipairs(hits) do
		local stateA = self._context.Services.PlayerStateService:GetState(hit.playerA)
		local stateB = self._context.Services.PlayerStateService:GetState(hit.playerB)
		local sizeA = stateA and stateA.Size or 1
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
			local velocityMagnitude = winnerRoot.AssemblyLinearVelocity.Magnitude
			local impactDirection = loserRoot.Position - winnerRoot.Position
			local damage = self._context.Services.DamagePipelineService:ComputeCollisionDamage(attackerState, velocityMagnitude)
			local knockback = self._context.Services.DamagePipelineService:ComputeCollisionKnockback(attackerState, defenderState, impactDirection, velocityMagnitude)
			self._context.EventBus:Fire("CollisionDetected", "Sling", winner, loser, { Speed = velocityMagnitude, ChargeRatio = attackerState.ChargeValue })
			self._context.EventBus:Fire("CollisionPlayerHit", loser, winner, damage, knockback, { ChargeRatio = attackerState.ChargeValue, VelocityMagnitude = velocityMagnitude })
			local decay = math.clamp(BalanceConfig.VelocityDecayFactor, 0, 1)
			winnerRoot.AssemblyLinearVelocity *= decay
		end
	end
end


function CollisionService:_resolveGateCollisions()
	return
end

function CollisionService:_resolveTrapCollisions()
	for _, trap in self._context.Services.MapService:GetTrapBlocks() do
		for _, player in Players:GetPlayers() do
			local root = self._context.Services.PlayerService:GetRoot(player)
			if root and self._context.Services.PlayerService:IsAlive(player) then
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
