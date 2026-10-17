--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type Context = {
	EventBus: any,
	Services: any,
	Remotes: Folder?,
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

	local debugLevelUpRemote = self._context.Remotes and self._context.Remotes:FindFirstChild(RemoteContracts.Names.DebugLevelUp5)
	if debugLevelUpRemote and debugLevelUpRemote:IsA("RemoteEvent") then
		debugLevelUpRemote.OnServerEvent:Connect(function(player: Player)
			if not RunService:IsStudio() or not RemoteContracts.Validate(RemoteContracts.Names.DebugLevelUp5) then return end
			local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
			if not (stateService and typeof(stateService.GrantLevelsForDebug) == "function") then
				warn("[GrowthService] PlayerStateService cannot grant debug levels.")
				return
			end
			local granted = stateService:GrantLevelsForDebug(player, 5)
			local state = stateService:GetState(player)
			print(string.format("[DEBUG_LEVEL_UP5] player=%s levelsGranted=%d level=%s", player.Name, granted, tostring(state and state.Level)))
		end)
	end
end

return GrowthService
