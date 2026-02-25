--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local CollisionService = {}
CollisionService.__index = CollisionService

function CollisionService.new(context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._lastCollision = {}
	return self
end

function CollisionService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_applyDragAndBounce(dt)
		self:_resolvePlayerCollisions()
		self:_checkGateCollisions()
	end)
end

function CollisionService:_applyDragAndBounce(dt)
	for _, player in Players:GetPlayers() do
		local root = self._context.Services.PlayerService:GetRoot(player)
		if root then
			local velocity = root.AssemblyLinearVelocity
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
			local dragFactor = math.max(0, 1 - Config.AirDrag * dt)
			horizontal *= dragFactor
			if horizontal.Magnitude < Config.StopVelocityThreshold then
				horizontal = Vector3.zero
			end

			local pos = root.Position
			if math.abs(pos.X) > Config.MaxArenaRadius - 6 then
				horizontal = Vector3.new(-horizontal.X * (1 - Config.BounceLoss), 0, horizontal.Z)
			end
			if math.abs(pos.Z) > Config.MaxArenaRadius - 6 then
				horizontal = Vector3.new(horizontal.X, 0, -horizontal.Z * (1 - Config.BounceLoss))
			end
			root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
		end
	end
end

function CollisionService:_resolvePlayerCollisions()
	local list = Players:GetPlayers()
	for i = 1, #list do
		for j = i + 1, #list do
			self:_resolvePair(list[i], list[j])
		end
	end
end

function CollisionService:_resolvePair(playerA, playerB)
	local rootA = self._context.Services.PlayerService:GetRoot(playerA)
	local rootB = self._context.Services.PlayerService:GetRoot(playerB)
	if not rootA or not rootB then
		return
	end

	local distance = (rootA.Position - rootB.Position).Magnitude
	local sizeA = (self._context.Services.PlayerService:GetState(playerA) or {}).Size or 1
	local sizeB = (self._context.Services.PlayerService:GetState(playerB) or {}).Size or 1
	local hitDistance = (rootA.Size.X + rootB.Size.X) * 0.25
	if distance > hitDistance then
		return
	end

	local key = if playerA.UserId < playerB.UserId then `{playerA.UserId}:{playerB.UserId}` else `{playerB.UserId}:{playerA.UserId}`
	if self._lastCollision[key] and os.clock() - self._lastCollision[key] < 0.2 then
		return
	end
	self._lastCollision[key] = os.clock()

	local massA = Config.Mass * sizeA
	local massB = Config.Mass * sizeB
	local momentumA = rootA.AssemblyLinearVelocity.Magnitude * massA
	local momentumB = rootB.AssemblyLinearVelocity.Magnitude * massB

	local winner = if momentumA >= momentumB then playerA else playerB
	local loser = if winner == playerA then playerB else playerA
	local loserRoot = if loser == playerA then rootA else rootB
	local winnerRoot = if winner == playerA then rootA else rootB
	local damage = loserRoot.AssemblyLinearVelocity.Magnitude * 0.15

	self._context.Services.PlayerService:ApplyDamage(loser, damage)
	local knockbackDirection = (loserRoot.Position - winnerRoot.Position)
	if knockbackDirection.Magnitude < 0.01 then
		knockbackDirection = Vector3.new(1, 0, 0)
	end
	loserRoot.AssemblyLinearVelocity += knockbackDirection.Unit * 45
end

function CollisionService:_checkGateCollisions()
	for _, gate in self._context.Services.MapService:GetGates() do
		for _, player in Players:GetPlayers() do
			local root = self._context.Services.PlayerService:GetRoot(player)
			local state = self._context.Services.PlayerService:GetState(player)
			if root and state then
				local localPos = gate.CFrame:PointToObjectSpace(root.Position)
				local half = gate.Size * 0.5
				if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
					if self._context.Services.MapService:IsGateBlocking(gate, state.Size) then
						root.AssemblyLinearVelocity = -Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) * (1 - Config.BounceLoss)
					end
				end
			end
		end
	end
end

return CollisionService
