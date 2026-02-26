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

function TrapService:OnTrapCollision(player: Player, _trap: BasePart)
	local now = os.clock()
	local last = self._lastTriggeredAt[player] or 0
	if now - last < TrapConfig.TriggerCooldown then
		return
	end
	self._lastTriggeredAt[player] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)
end

return TrapService
