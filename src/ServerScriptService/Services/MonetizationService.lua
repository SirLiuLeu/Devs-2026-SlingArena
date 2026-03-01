--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

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
	local purchaseRespawn = self._context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseRespawn) :: RemoteEvent?
	local purchaseMatchBuff = self._context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseMatchBuff) :: RemoteEvent?
	local prestigeReset = self._context.Remotes:FindFirstChild(RemoteContracts.Names.PrestigeReset) :: RemoteEvent?

	if purchaseRespawn then
		purchaseRespawn.OnServerEvent:Connect(function(player)
			self:HandleRespawnPurchase(player)
		end)
	end

	if purchaseMatchBuff then
		purchaseMatchBuff.OnServerEvent:Connect(function(player)
			self:HandleMatchBuffPurchase(player)
		end)
	end

	if prestigeReset then
		prestigeReset.OnServerEvent:Connect(function(player)
			self._context.Services.PlayerStateService:PrestigeReset(player)
		end)
	end
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
	self._context.Services.PlayerService:SpawnPawn(player)
end

function MonetizationService:HandleMatchBuffPurchase(player: Player)
	if not self._context.Services.PlayerStateService:SpendDiamonds(player, BalanceConfig.MatchBuffCost) then
		return
	end
	self._context.Services.PlayerStateService:ApplyMatchBuff(player)
end

return MonetizationService
