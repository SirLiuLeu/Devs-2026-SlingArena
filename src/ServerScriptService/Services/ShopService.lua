--!strict

-- Server-authoritative shop gateway. The client submits only catalog identifiers;
-- prices, rewards, and inventory grants are resolved and validated on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
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

local ITEMS = {
	item_hp_potion = { priceX1 = 1, priceX10 = 9 },
	item_buff_exp = { priceX1 = 4, priceX10 = 36 },
	item_size_up = { priceX1 = 5, priceX10 = 45 },
	item_speed_boost = { priceX1 = 2, priceX10 = 18 },
	item_invisible = { priceX1 = 3, priceX10 = 27 },
}

local LAUNCHERS = {
	NormalLauncher = { price = 100 },
	TitanBulwarkLauncher = { price = 900 },
	ZephyrDartLauncher = { price = 1200 },
	RavagerCoreLauncher = { price = 1800 },
}

function ShopService.new(context)
	local self = setmetatable({}, ShopService)
	self._context = context
	self._purchaseDinamondPackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseDinamondPack) :: RemoteEvent?
	self._purchaseItemRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseItem) :: RemoteEvent?
	self._purchaseLauncherRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseLauncher) :: RemoteEvent?
	return self
end

function ShopService:_publishState(player: Player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService then
		stateService:_syncInventoryFromData(player)
		stateService:RecalculateDerivedStats(player)
	end
end

function ShopService:PurchaseDinamondPack(player: Player, packId: string)
	local pack = DIAMOND_PACKS[packId]
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not pack or not dataService then
		return false
	end

	dataService:GrantReward(player, { Diamonds = pack.dinamondAmount }, "ShopPurchaseDiamonds")
	self:_publishState(player)
	return true
end

function ShopService:PurchaseItem(player: Player, itemId: string, quantity: number)
	local item = ITEMS[itemId]
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not item or not dataService then
		return false
	end

	local price = if quantity == 10 then item.priceX10 else item.priceX1
	if not dataService:SpendDiamonds(player, price, "ShopPurchaseItem") then
		return false
	end

	dataService:GrantReward(player, { Items = { { Id = itemId, Quantity = quantity } } }, "ShopPurchaseItem")
	self:_publishState(player)
	return true
end

function ShopService:PurchaseLauncher(player: Player, launcherId: string)
	local launcher = LAUNCHERS[launcherId]
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not launcher or not dataService then
		return false
	end
	if not dataService:SpendDiamonds(player, launcher.price, "ShopPurchaseLauncher") then
		return false
	end

	local granted = dataService:GrantLauncher(player, launcherId)
	if not granted then
		-- Launcher IDs are validated by PlayerDataService before any inventory mutation.
		dataService:GrantReward(player, { Diamonds = launcher.price }, "ShopPurchaseLauncherRefund")
		self:_publishState(player)
		return false
	end

	self:_publishState(player)
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
end

return ShopService
