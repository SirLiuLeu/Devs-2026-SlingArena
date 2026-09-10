--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MockData = require(ReplicatedStorage.Client.Services.MockData)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local ShopLogicService = {}
ShopLogicService.__index = ShopLogicService

local function cloneEntry(entry)
	local result = {}
	for key, value in pairs(entry) do
		result[key] = value
	end
	return result
end

function ShopLogicService.new()
	local self = setmetatable({}, ShopLogicService)
	self._changed = Instance.new("BindableEvent")
	self._balance = 0
	self._items = {}
	self._launchers = {}
	self._dinamondPacks = {}
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._purchaseDinamondPackRemote = remotes:FindFirstChild(RemoteContracts.Names.PurchaseDinamondPack) :: RemoteEvent?
	self._purchaseItemRemote = remotes:FindFirstChild(RemoteContracts.Names.PurchaseItem) :: RemoteEvent?
	self._purchaseLauncherRemote = remotes:FindFirstChild(RemoteContracts.Names.PurchaseLauncher) :: RemoteEvent?
	return self
end

function ShopLogicService:Destroy()
	if self._playerDataConnection then
		self._playerDataConnection:Disconnect()
		self._playerDataConnection = nil
	end
	if self._changed then
		self._changed:Destroy()
	end
end

function ShopLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function ShopLogicService:_emitChanged()
	self._changed:Fire(self:GetSnapshot())
end

function ShopLogicService:_syncBalance()
	self._balance = math.max(0, math.floor(MockPlayerData.GetPlayerData().Diamonds or 0))
end

function ShopLogicService:GetSnapshot()
	self:_syncBalance()
	local items = {}
	for i, entry in ipairs(self._items) do
		items[i] = cloneEntry(entry)
	end

	local launchers = {}
	for i, entry in ipairs(self._launchers) do
		launchers[i] = cloneEntry(entry)
	end

	local packs = {}
	for i, entry in ipairs(self._dinamondPacks) do
		packs[i] = cloneEntry(entry)
	end

	return {
		currencyName = "Dinamond",
		balance = self._balance,
		itemEntries = items,
		launcherEntries = launchers,
		dinamondEntries = packs,
	}
end

function ShopLogicService:LoadMockData()
	local data = MockData.GetShopState()
	self._balance = math.max(0, math.floor(MockPlayerData.GetPlayerData().Diamonds or data.balance or 0))
	self._items = data.items or {}
	self._launchers = data.launchers or {}
	self._dinamondPacks = data.dinamondPacks or {}
	if not self._playerDataConnection then
		self._playerDataConnection = MockPlayerData.BindChanged(function()
			self:_emitChanged()
		end)
	end
	self:_emitChanged()
end

function ShopLogicService:_findById(entries, id: string)
	for _, entry in ipairs(entries) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function ShopLogicService:PurchaseItem(itemId: string, quantity: number): (boolean, string)
	local item = self:_findById(self._items, itemId)
	if not item then
		return false, "ITEM_NOT_FOUND"
	end

	local selectedQuantity = if quantity >= 10 then 10 else 1
	if not self._purchaseItemRemote then
		return false, "PURCHASE_REMOTE_UNAVAILABLE"
	end

	self._purchaseItemRemote:FireServer(item.id, selectedQuantity)
	return true, string.format("Purchase requested: %s x%d", tostring(item.name), selectedQuantity)
end

function ShopLogicService:PurchaseLauncher(launcherId: string): (boolean, string)
	local launcher = self:_findById(self._launchers, launcherId)
	if not launcher then
		return false, "LAUNCHER_NOT_FOUND"
	end
	if not self._purchaseLauncherRemote then
		return false, "PURCHASE_REMOTE_UNAVAILABLE"
	end

	self._purchaseLauncherRemote:FireServer(launcher.id)
	return true, string.format("Purchase requested: %s", tostring(launcher.name))
end

function ShopLogicService:PurchaseDinamondPack(packId: string): (boolean, string)
	local pack = self:_findById(self._dinamondPacks, packId)
	if not pack then
		return false, "PACK_NOT_FOUND"
	end
	if not self._purchaseDinamondPackRemote then
		return false, "PURCHASE_REMOTE_UNAVAILABLE"
	end

	-- Diamond grants are server-authoritative; StateUpdate publishes the new balance.
	self._purchaseDinamondPackRemote:FireServer(pack.id)
	return true, string.format("Purchase requested: +%d Dinamond", pack.dinamondAmount)
end

local defaultInstance = nil

function ShopLogicService.GetDefault()
	if not defaultInstance then
		defaultInstance = ShopLogicService.new()
	end
	return defaultInstance
end

return ShopLogicService
