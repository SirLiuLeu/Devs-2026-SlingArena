--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local MockData = require(ReplicatedStorage.Client.Services.MockData)

local InventoryDataProvider = {}
InventoryDataProvider.__index = InventoryDataProvider

export type InventorySnapshot = {
	ownedItems: { [string]: number },
	ownedSlings: { { id: string, level: number, equipped: boolean } },
	slingCapacity: number,
	selectedItemId: string?,
	selectedSlingId: string?,
	lastUseResult: string?,
}

local function cloneItems(items: { [string]: number }): { [string]: number }
	local result = {}
	for itemId, quantity in pairs(items) do
		result[itemId] = quantity
	end
	return result
end

local function cloneSlings(slings: { { id: string, level: number, equipped: boolean } }): { { id: string, level: number, equipped: boolean } }
	local result = {}
	for _, slingEntry in ipairs(slings) do
		table.insert(result, {
			id = slingEntry.id,
			level = slingEntry.level,
			equipped = slingEntry.equipped,
		})
	end
	return result
end

function InventoryDataProvider.new()
	local self = setmetatable({}, InventoryDataProvider)
	self._changed = Instance.new("BindableEvent")
	self._state = {
		ownedItems = {},
		ownedSlings = {},
		slingCapacity = 40,
		selectedItemId = nil,
		selectedSlingId = nil,
		lastUseResult = nil,
		_slingGiveCursor = 0,
	}
	return self
end

function InventoryDataProvider:Destroy()
	if self._changed then
		self._changed:Destroy()
	end
end

function InventoryDataProvider:GetSnapshot(): InventorySnapshot
	return {
		ownedItems = cloneItems(self._state.ownedItems),
		ownedSlings = cloneSlings(self._state.ownedSlings),
		slingCapacity = self._state.slingCapacity,
		selectedItemId = self._state.selectedItemId,
		selectedSlingId = self._state.selectedSlingId,
		lastUseResult = self._state.lastUseResult,
	}
end

function InventoryDataProvider:_emitChanged()
	self._changed:Fire(self:GetSnapshot())
end

function InventoryDataProvider:BindChanged(callback: (InventorySnapshot) -> ())
	return self._changed.Event:Connect(callback)
end

function InventoryDataProvider:SetFromState(state)
	if type(state) ~= "table" then
		return
	end
	local incomingItems = state.OwnedItems
	if type(incomingItems) == "table" then
		self._state.ownedItems = cloneItems(incomingItems)
	end

	local incomingSlings = state.OwnedSlings
	if type(incomingSlings) == "table" then
		self._state.ownedSlings = cloneSlings(incomingSlings)
	end

	if type(state.SlingCapacity) == "number" then
		self._state.slingCapacity = math.max(0, math.floor(state.SlingCapacity))
	end

	self:_emitChanged()
end

function InventoryDataProvider:LoadMockInventory()
	self:SetFromState(MockData.GetInventoryState())
end

function InventoryDataProvider:_findSlingIndex(slingId: string): number?
	for index, slingEntry in ipairs(self._state.ownedSlings) do
		if slingEntry.id == slingId then
			return index
		end
	end
	return nil
end

function InventoryDataProvider:SelectItem(itemId: string?)
	self._state.selectedItemId = itemId
	self:_emitChanged()
end

function InventoryDataProvider:SelectSling(slingId: string?)
	self._state.selectedSlingId = slingId
	self:_emitChanged()
end

function InventoryDataProvider:GiveTestSling()
	local slingIds = SlingConfig.GetAllIds()
	if #slingIds <= 0 then
		warn("[INVENTORY_DATA] SlingConfig has no sling ids")
		self:_emitChanged()
		return
	end

	self._state._slingGiveCursor = (self._state._slingGiveCursor % #slingIds) + 1
	local slingId = slingIds[self._state._slingGiveCursor]
	local existingIndex = self:_findSlingIndex(slingId)
	if existingIndex then
		self._state.ownedSlings[existingIndex].level = self._state.ownedSlings[existingIndex].level + 1
	else
		table.insert(self._state.ownedSlings, {
			id = slingId,
			level = 1,
			equipped = false,
		})
	end
	if #self._state.ownedSlings == 1 then
		self._state.ownedSlings[1].equipped = true
	end
	self:_emitChanged()
end

function InventoryDataProvider:GiveTestItem()
	local itemId = "hp_potion"
	if not ItemConfig.GetById(itemId) then
		warn("[INVENTORY_DATA] hp_potion missing from ItemConfig")
		self:_emitChanged()
		return
	end
	self._state.ownedItems[itemId] = (self._state.ownedItems[itemId] or 0) + 1
	self:_emitChanged()
end

function InventoryDataProvider:UseSelectedItem(): boolean
	local itemId = self._state.selectedItemId
	if not itemId then
		self._state.lastUseResult = "Select an item first"
		self:_emitChanged()
		return false
	end
	local quantity = self._state.ownedItems[itemId] or 0
	if quantity <= 0 then
		self._state.lastUseResult = string.format("%s is out of stock", itemId)
		self:_emitChanged()
		return false
	end

	self._state.ownedItems[itemId] = quantity - 1
	if self._state.ownedItems[itemId] <= 0 then
		self._state.ownedItems[itemId] = nil
		if self._state.selectedItemId == itemId then
			self._state.selectedItemId = nil
		end
	end

	if itemId == "hp_potion" then
		self._state.lastUseResult = "HP Potion used: simulated +500 HP over time"
	else
		self._state.lastUseResult = string.format("Used %s", itemId)
	end
	self:_emitChanged()
	return true
end

function InventoryDataProvider:EquipSelectedSling(): boolean
	local slingId = self._state.selectedSlingId
	if not slingId then
		self:_emitChanged()
		return false
	end

	local selectedIndex = self:_findSlingIndex(slingId)
	if not selectedIndex then
		self:_emitChanged()
		return false
	end

	for _, slingEntry in ipairs(self._state.ownedSlings) do
		slingEntry.equipped = false
	end
	self._state.ownedSlings[selectedIndex].equipped = true
	self:_emitChanged()
	return true
end

function InventoryDataProvider:UnequipSelectedSling(): boolean
	local slingId = self._state.selectedSlingId
	if not slingId then
		self:_emitChanged()
		return false
	end
	local selectedIndex = self:_findSlingIndex(slingId)
	if not selectedIndex then
		self:_emitChanged()
		return false
	end
	self._state.ownedSlings[selectedIndex].equipped = false
	self:_emitChanged()
	return true
end

local defaultProvider: any = nil

function InventoryDataProvider.GetDefault()
	if not defaultProvider then
		defaultProvider = InventoryDataProvider.new()
	end
	return defaultProvider
end

return InventoryDataProvider
