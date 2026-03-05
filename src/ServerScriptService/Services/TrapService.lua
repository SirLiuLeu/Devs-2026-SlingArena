--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)

local TrapService = {}
TrapService.__index = TrapService

function TrapService.new(context)
	local self = setmetatable({}, TrapService)
	self._context = context
	self._lastTriggeredAt = {}
	return self
end

function TrapService:Init()
	self._context.EventBus:On("TrapCollisionCandidate", function(player: Player, trap: BasePart)
		self:OnTrapCollision(player, trap)
	end)
end

function TrapService:OnTrapCollision(player: Player, trap: BasePart)
	local now = os.clock()
	local last = self._lastTriggeredAt[player] or 0
	if now - last < TrapConfig.TriggerCooldown then
		return
	end
	self._lastTriggeredAt[player] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)

	local root = self._context.Services.PlayerService:GetRoot(player)
	if root and trap then
		local away = (root.Position - trap.Position)
		if away.Magnitude < 0.01 then
			away = Vector3.new(1, 0, 0)
		end
		root.AssemblyLinearVelocity += away.Unit * 55 + Vector3.new(0, 10, 0)
	end
	self._context.Services.DamagePipelineService:ApplyDamage(player, 15, nil, nil)

	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") then
		popup:FireClient(player, { Type = "Trap", Text = "Trap hit! -15 HP" })
	end
end

return TrapService
