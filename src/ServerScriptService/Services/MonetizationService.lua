--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local MonetizationService = {}
MonetizationService.__index = MonetizationService

type Context = {
	Services: any,
	Remotes: Folder,
	EventBus: any,
}

function MonetizationService.new(context: Context)
	local self = setmetatable({}, MonetizationService)
	self._context = context
	return self
end

function MonetizationService:Init()
	local purchaseRespawn = self._context.Remotes:FindFirstChild("PurchaseRespawn") :: RemoteEvent
	local purchaseMatchBuff = self._context.Remotes:FindFirstChild("PurchaseMatchBuff") :: RemoteEvent
	local prestigeReset = self._context.Remotes:FindFirstChild("PrestigeReset") :: RemoteEvent

	purchaseRespawn.OnServerEvent:Connect(function(player)
		self:HandleRespawnPurchase(player)
	end)

	purchaseMatchBuff.OnServerEvent:Connect(function(player)
		self:HandleMatchBuffPurchase(player)
	end)

	prestigeReset.OnServerEvent:Connect(function(player)
		self._context.Services.PlayerStateService:PrestigeReset(player)
	end)
end

function MonetizationService:HandleRespawnPurchase(player: Player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	if state.RespawnCountThisMatch >= #BalanceConfig.RespawnDiamondCosts then
		return
	end
	local cost = BalanceConfig.RespawnDiamondCosts[state.RespawnCountThisMatch + 1]
	if not self._context.Services.PlayerStateService:SpendDiamonds(player, cost) then
		return
	end
	self._context.Services.PlayerStateService:ResetForRespawn(player, true)
	player:LoadCharacter()
end

function MonetizationService:HandleFreeRespawn(player: Player)
	self._context.Services.PlayerStateService:ResetForRespawn(player, false)
	player:LoadCharacter()
end

function MonetizationService:HandleMatchBuffPurchase(player: Player)
	if not self._context.Services.PlayerStateService:SpendDiamonds(player, BalanceConfig.MatchBuffCost) then
		return
	end
	self._context.Services.PlayerStateService:ApplyMatchBuff(player)
end

return MonetizationService
