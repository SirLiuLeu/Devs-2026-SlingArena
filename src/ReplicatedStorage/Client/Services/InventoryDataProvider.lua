--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local MockData = require(ReplicatedStorage.Client.Services.MockData)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local consumeHpPotionRemote = remotes:FindFirstChild(RemoteContracts.Names.ConsumeHpPotion) :: RemoteEvent?
local equipEquipmentRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipEquipment) :: RemoteEvent?
local unequipEquipmentRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipEquipment) :: RemoteEvent?

local InventoryDataProvider = {}
InventoryDataProvider.__index = InventoryDataProvider

export type InventorySnapshot = {
	ownedItems: { [string]: number },
	ownedLaunchers: { { instanceId: string, definitionId: string, id: string, star: number, level: number, equipped: boolean, name: string?, icon: string?, stats: any? } },
	launcherCapacity: number,
	selectedItemId: string?,
	selectedLauncherId: string?,
	ownedEquipment: { any },
	equippedEquipment: { [any]: string },
	selectedEquipmentId: string?,
	lastUseResult: string?,
	pendingLauncherInstanceId: string?,
}


local function deepEqual(left: any, right: any): boolean
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key, leftValue in pairs(left) do
		if not deepEqual(leftValue, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function cloneItems(items: { [string]: number }): { [string]: number }
	local result = {}
	for itemId, quantity in pairs(items) do
		result[itemId] = quantity
	end
	return result
end

local function cloneLaunchers(launchers): any
	local result = {}
	local isArray = #launchers > 0
	if isArray then
		for _, launcherEntry in ipairs(launchers) do
			table.insert(result, table.clone(launcherEntry))
		end
		return result
	end
	for instanceId, launcherEntry in pairs(launchers) do
		local definitionId = launcherEntry.definitionId or launcherEntry.id
		table.insert(result, {
			instanceId = instanceId,
			definitionId = definitionId,
			id = definitionId,
			star = launcherEntry.star or 1,
			level = launcherEntry.level or 1,
			equipped = false,
			name = launcherEntry.name,
			icon = launcherEntry.icon,
			stats = launcherEntry.stats and table.clone(launcherEntry.stats) or nil,
		})
	end
	table.sort(result, function(a, b)
		return tostring(a.instanceId) < tostring(b.instanceId)
	end)
	return result
end

function InventoryDataProvider.new()
	local self = setmetatable({}, InventoryDataProvider)
	self._changed = Instance.new("BindableEvent")
	self._state = {
		ownedItems = {},
		ownedLaunchers = {},
		ownedEquipment = {},
		equippedEquipment = {},
		launcherCapacity = 40,
		selectedItemId = nil,
		selectedLauncherId = nil,
		selectedEquipmentId = nil,
		lastUseResult = nil,
		pendingLauncherInstanceId = nil,
		equipmentCapacity = 40,
		_launcherGiveCursor = 0,
	}
	return self
end

function InventoryDataProvider:Destroy()
	if self._playerDataConnection then
		self._playerDataConnection:Disconnect()
		self._playerDataConnection = nil
	end
	if self._changed then
		self._changed:Destroy()
	end
end

function InventoryDataProvider:GetSnapshot(): InventorySnapshot
	return {
		ownedItems = cloneItems(self._state.ownedItems),
		ownedLaunchers = cloneLaunchers(self._state.ownedLaunchers),
		launcherCapacity = self._state.launcherCapacity,
		selectedItemId = self._state.selectedItemId,
		selectedLauncherId = self._state.selectedLauncherId,
		lastUseResult = self._state.lastUseResult,
		ownedEquipment = cloneLaunchers(self._state.ownedEquipment),
		equippedEquipment = table.clone(self._state.equippedEquipment),
		selectedEquipmentId = self._state.selectedEquipmentId,
		equipmentCapacity = self._state.equipmentCapacity,
	}
end

function InventoryDataProvider:_emitChanged()
	print(string.format("[DIAG][InventoryData] emitChanged items=%d launchers=%d equipment=%d selectedEquipment=%s t=%.3f", (function() local count = 0; for _ in pairs(self._state.ownedItems) do count += 1 end; return count end)(), #self._state.ownedLaunchers, #self._state.ownedEquipment, tostring(self._state.selectedEquipmentId), os.clock()))
	self._changed:Fire(self:GetSnapshot())
end

function InventoryDataProvider:BindChanged(callback: (InventorySnapshot) -> ())
	return self._changed.Event:Connect(callback)
end

function InventoryDataProvider:SetFromState(state)
	print(string.format("[DIAG][InventoryData] SetFromState incomingType=%s ownedEquipment=%s equippedEquipment=%s t=%.3f", type(state), tostring(type(state) == "table" and type(state.OwnedEquipment) == "table" and (function() local count = 0; for _ in pairs(state.OwnedEquipment) do count += 1 end; return count end)() or "n/a"), tostring(type(state) == "table" and type(state.EquippedEquipment) == "table" and (function() local count = 0; for _ in pairs(state.EquippedEquipment) do count += 1 end; return count end)() or "n/a"), os.clock()))
	if type(state) ~= "table" then
		return
	end

	local nextItems = cloneItems(self._state.ownedItems)
	local incomingItems = state.OwnedItems
	if type(incomingItems) == "table" then
		nextItems = cloneItems(incomingItems)
	end
	if typeof(state.HpPotions) == "number" then
		nextItems.hp_potion = math.max(0, math.floor(state.HpPotions))
	end

	local nextLaunchers = self._state.ownedLaunchers
	local incomingLaunchers = state.OwnedLaunchers
	if type(incomingLaunchers) == "table" then
		nextLaunchers = cloneLaunchers(incomingLaunchers)
	end
	if type(state.EquippedLauncherInstanceId) == "string" then
		nextLaunchers = cloneLaunchers(nextLaunchers)
		for _, launcherEntry in ipairs(nextLaunchers) do
			launcherEntry.equipped = launcherEntry.instanceId == state.EquippedLauncherInstanceId
		end
	end

	local nextEquipment = self._state.ownedEquipment
	local incomingEquipment = state.OwnedEquipment
	if type(incomingEquipment) == "table" then
		nextEquipment = cloneLaunchers(incomingEquipment)
		for _, entry in ipairs(nextEquipment) do
			local def = EquipmentConfig.GetById(entry.definitionId or entry.id or "")
			entry.id = entry.definitionId or entry.id
			entry.name = entry.name or (def and def.name)
			entry.icon = entry.icon or (def and def.iconId)
		end
	end

	local nextEquippedEquipment = self._state.equippedEquipment
	if type(state.EquippedEquipment) == "table" then
		nextEquippedEquipment = table.clone(state.EquippedEquipment)
		nextEquipment = cloneLaunchers(nextEquipment)
		for _, entry in ipairs(nextEquipment) do
			entry.equipped = false
			entry.equippedSlot = nil
			for slot, instanceId in pairs(nextEquippedEquipment) do
				if instanceId == entry.instanceId then entry.equipped = true; entry.equippedSlot = tonumber(slot) or slot end
			end
		end
	end

	local nextLauncherCapacity = self._state.launcherCapacity
	if type(state.LauncherCapacity) == "number" then
		nextLauncherCapacity = math.max(0, math.floor(state.LauncherCapacity))
	end

	local changed = not deepEqual(nextItems, self._state.ownedItems)
		or not deepEqual(nextLaunchers, self._state.ownedLaunchers)
		or not deepEqual(nextEquipment, self._state.ownedEquipment)
		or not deepEqual(nextEquippedEquipment, self._state.equippedEquipment)
		or nextLauncherCapacity ~= self._state.launcherCapacity

	if type(state.EquippedLauncherInstanceId) == "string" and self._state.pendingLauncherInstanceId ~= nil then
		self._state.lastUseResult = (self._state.pendingLauncherInstanceId == state.EquippedLauncherInstanceId) and "LauncherEquipped" or "LauncherEquipRejected"
		self._state.pendingLauncherInstanceId = nil
		changed = true
	end

	if not changed then
		return
	end

	self._state.ownedItems = nextItems
	self._state.ownedLaunchers = nextLaunchers
	self._state.ownedEquipment = nextEquipment
	self._state.equippedEquipment = nextEquippedEquipment
	self._state.launcherCapacity = nextLauncherCapacity
	self:_emitChanged()
end

function InventoryDataProvider:LoadMockInventory()
	if not self._playerDataConnection then
		self._playerDataConnection = MockPlayerData.BindChanged(function()
			self:SetFromState(MockPlayerData.GetInventoryState())
		end)
	end
	self:SetFromState(MockData.GetInventoryState())
end

function InventoryDataProvider:_findLauncherIndex(launcherId: string): number?
	for index, launcherEntry in ipairs(self._state.ownedLaunchers) do
		if launcherEntry.instanceId == launcherId or launcherEntry.id == launcherId then
			return index
		end
	end
	return nil
end

function InventoryDataProvider:SelectItem(itemId: string?)
	self._state.selectedItemId = itemId
	self:_emitChanged()
end

function InventoryDataProvider:SelectEquipment(equipmentId: string?)
	self._state.selectedEquipmentId = equipmentId
	self:_emitChanged()
end

function InventoryDataProvider:SelectLauncher(launcherId: string?)
	self._state.selectedLauncherId = launcherId
	self:_emitChanged()
end

function InventoryDataProvider:GiveTestLauncher()
	local launcherIds = LauncherConfig.GetAllIds()
	if #launcherIds <= 0 then
		warn("[INVENTORY_DATA] LauncherConfig has no launcher ids")
		self:_emitChanged()
		return
	end

	self._state._launcherGiveCursor = (self._state._launcherGiveCursor % #launcherIds) + 1
	local launcherId = launcherIds[self._state._launcherGiveCursor]
	MockPlayerData.AddLauncher(launcherId, "InventoryGiveTestLauncher")
end

function InventoryDataProvider:GiveTestItem()
	local itemId = "hp_potion"
	if not ItemConfig.GetById(itemId) then
		warn("[INVENTORY_DATA] hp_potion missing from ItemConfig")
		self:_emitChanged()
		return
	end
	MockPlayerData.AddItem(itemId, 1, "InventoryGiveTestItem")
end

function InventoryDataProvider:UseSelectedItem(): boolean
	local itemId = self._state.selectedItemId
	if not itemId then
		self._state.lastUseResult = "Select an item first"
		self:_emitChanged()
		return false
	end

	if itemId == "hp_potion" and consumeHpPotionRemote then
		local quantity = math.max(0, math.floor(self._state.ownedItems.hp_potion or 0))
		if quantity <= 0 then
			self._state.lastUseResult = "NoPotion"
			self:_emitChanged()
			return false
		end
		consumeHpPotionRemote:FireServer()
		print("[System]: Successfully used HP Potion")
		self._state.lastUseResult = "Requested"
		self:_emitChanged()
		return true
	end

	local success, message = MockPlayerData.UseItem(itemId, "InventoryUseItem")
	self._state.lastUseResult = message
	if success then
		local itemDef = ItemConfig.GetById(itemId)
		print(string.format("[System]: Successfully used %s", itemDef and itemDef.name or itemId))
	else
		self:_emitChanged()
	end
	return success
end

function InventoryDataProvider:EquipSelectedLauncher(): boolean
	local launcherId = self._state.selectedLauncherId
	if not launcherId then
		self:_emitChanged()
		return false
	end

	local selectedIndex = self:_findLauncherIndex(launcherId)
	if not selectedIndex then
		self:_emitChanged()
		return false
	end

	local selected = self._state.ownedLaunchers[selectedIndex]
	local remotesFolder = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	local abilityTrigger = remotesFolder and remotesFolder:FindFirstChild(RemoteContracts.Names.AbilityTrigger)
	if not (abilityTrigger and abilityTrigger:IsA("RemoteEvent")) then
		self._state.lastUseResult = "LauncherEquipRemoteMissing"
		self:_emitChanged()
		return false
	end

	-- Injection point: optimistic launcher UI now mirrors equipment flow: request, mark loading, and wait for StateUpdate ack.
	self._state.pendingLauncherInstanceId = selected.instanceId
	self._state.lastUseResult = "LauncherEquipRequested"
	self:_emitChanged()
	abilityTrigger:FireServer({
		action = "EquipLauncher",
		launcherId = selected.id or selected.definitionId,
		instanceId = selected.instanceId,
	})
	return true
end

function InventoryDataProvider:UnequipSelectedLauncher(): boolean
	local launcherId = self._state.selectedLauncherId
	if not launcherId then
		self:_emitChanged()
		return false
	end
	local selectedIndex = self:_findLauncherIndex(launcherId)
	if not selectedIndex then
		self:_emitChanged()
		return false
	end
	self._state.ownedLaunchers[selectedIndex].equipped = false
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

function InventoryDataProvider:_findEquipmentIndex(equipmentId: string): number?
	for index, entry in ipairs(self._state.ownedEquipment) do
		if entry.instanceId == equipmentId or entry.id == equipmentId then return index end
	end
	return nil
end

function InventoryDataProvider:EquipSelectedEquipment(): boolean
	print(string.format("[DIAG][InventoryData] EquipSelectedEquipment selected=%s t=%.3f", tostring(self._state.selectedEquipmentId), os.clock()))
	local equipmentId = self._state.selectedEquipmentId
	local index = equipmentId and self:_findEquipmentIndex(equipmentId)
	if not index then self:_emitChanged(); return false end
	local selected = self._state.ownedEquipment[index]
	if selected.equipped and unequipEquipmentRemote then
		unequipEquipmentRemote:FireServer(selected.equippedSlot)
		return true
	end
	if equipEquipmentRemote then
		equipEquipmentRemote:FireServer(selected.instanceId)
		print(string.format("[System]: Successfully equipped %s", selected.name or selected.id or selected.instanceId))
		return true
	end
	return false
end

function InventoryDataProvider:UnequipSelectedEquipment(): boolean
	local equipmentId = self._state.selectedEquipmentId
	local index = equipmentId and self:_findEquipmentIndex(equipmentId)
	if not index then self:_emitChanged(); return false end
	local selected = self._state.ownedEquipment[index]
	if selected.equippedSlot and unequipEquipmentRemote then unequipEquipmentRemote:FireServer(selected.equippedSlot); return true end
	return false
end

return InventoryDataProvider
