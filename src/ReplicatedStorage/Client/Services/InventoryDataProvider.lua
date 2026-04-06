--!strict

local InventoryDataProvider = {}
InventoryDataProvider.__index = InventoryDataProvider

export type InventorySnapshot = {
	ownedItems: { [string]: number },
	ownedSlings: { { id: string, level: number, equipped: boolean } },
	slingCapacity: number,
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
	}
end

function InventoryDataProvider:_emitChanged()
	self._changed:Fire(self:GetSnapshot())
end

function InventoryDataProvider:BindChanged(callback: (InventorySnapshot) -> ())
	return self._changed.Event:Connect(callback)
end

function InventoryDataProvider:SetFromState(state)
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

function InventoryDataProvider:GiveTestSling()
	local slingId = "SlingModel"
	local hasSling = false
	for _, slingEntry in ipairs(self._state.ownedSlings) do
		if slingEntry.id == slingId then
			hasSling = true
			break
		end
	end
	if not hasSling then
		table.insert(self._state.ownedSlings, {
			id = slingId,
			level = 1,
			equipped = #self._state.ownedSlings == 0,
		})
	end
	self:_emitChanged()
end

function InventoryDataProvider:GiveTestItem()
	self._state.ownedItems.hp_potion = (self._state.ownedItems.hp_potion or 0) + 1
	self:_emitChanged()
end


local defaultProvider: any = nil

function InventoryDataProvider.GetDefault()
	if not defaultProvider then
		defaultProvider = InventoryDataProvider.new()
	end
	return defaultProvider
end

return InventoryDataProvider
