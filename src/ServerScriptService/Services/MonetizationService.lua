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
	local requestRespawn = self._context.Remotes:FindFirstChild(RemoteContracts.Names.RequestRespawn) :: RemoteEvent?
	local purchaseMatchBuff = self._context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseMatchBuff) :: RemoteEvent?
	local prestigeReset = self._context.Remotes:FindFirstChild(RemoteContracts.Names.PrestigeReset) :: RemoteEvent?

	if purchaseRespawn then
		purchaseRespawn.OnServerEvent:Connect(function(player)
			self:HandleRespawnPurchase(player)
		end)
	end
	if requestRespawn then
		requestRespawn.OnServerEvent:Connect(function(player)
			self:HandleFreeRespawn(player)
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

function MonetizationService:_applyRespawnRetention(player: Player, levelFactor: number, sizeFactor: number)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	state.Level = math.max(1, math.floor(state.Level * levelFactor))
	state.ScaleMultiplier = math.max(0.5, state.ScaleMultiplier * sizeFactor)
	state.RespawnCountThisMatch += 1
	self._context.Services.PlayerStateService:ResetForRespawn(player)
	self._context.Services.PlayerStateService:PublishState(player)
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
	self:_applyRespawnRetention(player, BalanceConfig.RespawnRetainLevelPaid, BalanceConfig.RespawnRetainSizePaid)
end

function MonetizationService:HandleFreeRespawn(player: Player)
	self._context.Services.PlayerService:SpawnPawn(player)
	self:_applyRespawnRetention(player, BalanceConfig.RespawnRetainLevelFree, BalanceConfig.RespawnRetainLevelFree)
end

function MonetizationService:HandleMatchBuffPurchase(player: Player)
	if not self._context.Services.PlayerStateService:SpendDiamonds(player, BalanceConfig.MatchBuffCost) then
		return
	end
	self._context.Services.PlayerStateService:ApplyMatchBuff(player)
end

return MonetizationService
