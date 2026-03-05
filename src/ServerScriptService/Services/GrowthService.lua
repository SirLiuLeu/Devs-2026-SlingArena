--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

type Context = {
	EventBus: any,
	Services: any,
}

local GrowthService = {}
GrowthService.__index = GrowthService

function GrowthService.new(context: Context)
	local self = setmetatable({}, GrowthService)
	self._context = context
	return self
end

function GrowthService:Init()
	self._context.EventBus:On("DamageDealt", function(attacker: Player, _defender: Player, damage: number)
		local playerStateService = self._context.Services.PlayerStateService
		playerStateService:GrantExp(attacker, damage * BalanceConfig.DamageToExpRatio)
	end)

	self._context.EventBus:On("PlayerKilled", function(killer: Player)
		self._context.Services.PlayerStateService:GrantExp(killer, BalanceConfig.KillExp)
	end)

	self._context.EventBus:On("FoodConsumed", function(player: Player, expAmount: number)
		self._context.Services.PlayerStateService:GrantExp(player, expAmount)
	end)
end

return GrowthService
