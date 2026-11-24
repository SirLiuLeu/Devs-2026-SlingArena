--!strict

-- Server-authoritative shop gateway. The client submits only catalog identifiers;
-- prices, rewards, and inventory grants are resolved and validated on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local PurchasePetConfig = require(ReplicatedStorage.Shared.Config.PurchasePetConfig)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local ShopService = {}
ShopService.__index = ShopService

local DIAMOND_PACKS = {
	pack_1usd = { dinamondAmount = 125 },
	pack_10usd = { dinamondAmount = 1300 },
	pack_50usd = { dinamondAmount = 7000 },
	pack_100usd = { dinamondAmount = 15000 },
	pack_400usd = { dinamondAmount = 50000 },
}


function ShopService.new(context)
	local self = setmetatable({}, ShopService)
	self._context = context
	self._purchaseDinamondPackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseDinamondPack) :: RemoteEvent?
	self._purchaseItemRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseItem) :: RemoteEvent?
	self._purchaseLauncherRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseLauncher) :: RemoteEvent?
	self._purchasePetRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchasePet) :: RemoteEvent?
	self._feedbackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	return self
end

function ShopService:_publishState(player: Player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService then
		stateService:_syncInventoryFromData(player)
		stateService:RecalculateDerivedStats(player)
	end
end

function ShopService:_sendPurchaseFeedback(player: Player, success: boolean, purchaseType: string, itemId: string, reason: string?)
	if self._feedbackRemote and self._feedbackRemote:IsA("RemoteEvent") then
		self._feedbackRemote:FireClient(player, {
			EventType = "ShopPurchaseResult",
			Payload = { Success = success, PurchaseType = purchaseType, ItemId = itemId, Reason = reason },
		})
	end
end

function ShopService:PurchasePet(player: Player, abilityId: string): boolean
	local price = PurchasePetConfig.GetPrice(abilityId)
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if price == nil or not dataService then
		self:_sendPurchaseFeedback(player, false, "Pet", abilityId, "Unavailable")
		return false
	end

	local success, reason, instanceId = dataService:PurchasePet(player, abilityId, price)
	if not success then
		self:_sendPurchaseFeedback(player, false, "Pet", abilityId, reason or "PurchaseRejected")
		return false
	end

	self:_publishState(player)
	self:_sendPurchaseFeedback(player, true, "Pet", abilityId)
	return instanceId ~= nil
end

function ShopService:PurchaseDinamondPack(player: Player, packId: string)
	local pack = DIAMOND_PACKS[packId]
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not pack or not dataService then
		self:_sendPurchaseFeedback(player, false, "Diamonds", packId, "Unavailable")
		return false
	end

	dataService:GrantReward(player, { Diamonds = pack.dinamondAmount }, "ShopPurchaseDiamonds")
	self:_publishState(player)
	self:_sendPurchaseFeedback(player, true, "Diamonds", packId)
	return true
end

function ShopService:PurchaseItem(player: Player, itemId: string, quantity: number)
	local item = ItemConfig.GetById(itemId)
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local selectedQuantity = if quantity == 10 then 10 else 1
	if not item or not dataService then
		self:_sendPurchaseFeedback(player, false, "Item", itemId, "Unavailable")
		return false
	end

	local price = if selectedQuantity == 10 then item.shopPriceX10 else item.shopPriceX1
	if type(price) ~= "number" then
		self:_sendPurchaseFeedback(player, false, "Item", itemId, "InvalidPrice")
		return false
	end
	if not dataService:SpendDiamonds(player, price, "ShopPurchaseItem") then
		self:_sendPurchaseFeedback(player, false, "Item", itemId, "InsufficientDiamonds")
		return false
	end

	dataService:GrantReward(player, { Items = { { Id = item.id, Quantity = selectedQuantity } } }, "ShopPurchaseItem")
	self:_publishState(player)
	self:_sendPurchaseFeedback(player, true, "Item", itemId)
	return true
end

function ShopService:PurchaseLauncher(player: Player, launcherId: string)
	local launcher = LauncherConfig.GetById(launcherId)
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not launcher or type(launcher.shopPrice) ~= "number" or not dataService then
		self:_sendPurchaseFeedback(player, false, "Launcher", launcherId, "Unavailable")
		return false
	end
	if not dataService:SpendDiamonds(player, launcher.shopPrice, "ShopPurchaseLauncher") then
		self:_sendPurchaseFeedback(player, false, "Launcher", launcherId, "InsufficientDiamonds")
		return false
	end

	local granted = dataService:GrantLauncher(player, launcherId)
	if not granted then
		-- Launcher IDs are validated by PlayerDataService before any inventory mutation.
		dataService:GrantReward(player, { Diamonds = launcher.shopPrice }, "ShopPurchaseLauncherRefund")
		self:_publishState(player)
		self:_sendPurchaseFeedback(player, false, "Launcher", launcherId, "GrantFailed")
		return false
	end

	self:_publishState(player)
	self:_sendPurchaseFeedback(player, true, "Launcher", launcherId)
	return true
end

function ShopService:Init()
	if self._initialized then
		return
	end
	self._initialized = true

	if self._purchaseDinamondPackRemote then
		self._purchaseDinamondPackRemote.OnServerEvent:Connect(function(player: Player, packId: any)
			if RemoteContracts.Validate(RemoteContracts.Names.PurchaseDinamondPack, packId) then
				self:PurchaseDinamondPack(player, packId)
			end
		end)
	end
	if self._purchaseItemRemote then
		self._purchaseItemRemote.OnServerEvent:Connect(function(player: Player, itemId: any, quantity: any)
			if RemoteContracts.Validate(RemoteContracts.Names.PurchaseItem, itemId, quantity) then
				self:PurchaseItem(player, itemId, quantity)
			end
		end)
	end
	if self._purchaseLauncherRemote then
		self._purchaseLauncherRemote.OnServerEvent:Connect(function(player: Player, launcherId: any)
			if RemoteContracts.Validate(RemoteContracts.Names.PurchaseLauncher, launcherId) then
				self:PurchaseLauncher(player, launcherId)
			end
		end)
	end
	if self._purchasePetRemote then
		self._purchasePetRemote.OnServerEvent:Connect(function(player: Player, abilityId: any)
			if RemoteContracts.Validate(RemoteContracts.Names.PurchasePet, abilityId) then
				self:PurchasePet(player, abilityId)
			end
		end)
	end
end

return ShopService
