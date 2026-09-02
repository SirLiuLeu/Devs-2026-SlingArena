--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

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

function GrowthService:GrantExperience(player: Player, amount: number, _reason: string?)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService then stateService:GrantExp(player, math.max(0, amount)) end
end

function GrowthService:Init()
	self._context.EventBus:On("PlayerKilled", function(killer: Player)
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		if stateService then
			stateService:GrantExp(killer, BalanceConfig.KillExp)
		else
			warn("[GrowthService] PlayerStateService unavailable; kill EXP skipped.")
		end
	end)

	self._context.EventBus:On("FoodConsumed", function(player: Player, expAmount: number)
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		if stateService then
			stateService:GrantExp(player, expAmount)
		else
			warn("[GrowthService] PlayerStateService unavailable; food EXP skipped.")
		end
	end)
end

return GrowthService
