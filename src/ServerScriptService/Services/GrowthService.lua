--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

type Context = {
	EventBus: any,
	Services: any,
}

local GrowthService = {}
GrowthService.__index = GrowthService

local function getService(context: Context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

function GrowthService.new(context: Context)
	local self = setmetatable({}, GrowthService)
	self._context = context
	return self
end

function GrowthService:Init()
	self._context.EventBus:On("PlayerKilled", function(killer: Player)
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:GrantExp(killer, BalanceConfig.KillExp)
		else
			warn("[GrowthService] PlayerStateService unavailable; kill EXP skipped.")
		end
	end)

	self._context.EventBus:On("FoodConsumed", function(player: Player, expAmount: number)
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:GrantExp(player, expAmount)
		else
			warn("[GrowthService] PlayerStateService unavailable; food EXP skipped.")
		end
	end)
end

return GrowthService
