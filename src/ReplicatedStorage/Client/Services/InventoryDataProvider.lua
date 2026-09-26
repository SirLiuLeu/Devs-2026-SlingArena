--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local MockData = require(ReplicatedStorage.Client.Services.MockData)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)

local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local consumeItemRemote = remotes:FindFirstChild(RemoteContracts.Names.ConsumeItem) :: RemoteEvent?
local equipPetRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipPet) :: RemoteEvent?
local unequipPetRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipPet) :: RemoteEvent?
local equipLauncherRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
local unequipLauncherRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipLauncher) :: RemoteEvent?

local InventoryDataProvider = {}
InventoryDataProvider.__index = InventoryDataProvider

export type InventorySnapshot = {
	ownedItems: { [string]: number },
	ownedLaunchers: { { instanceId: string, definitionId: string, id: string, star: number, level: number, equipped: boolean, name: string?, icon: string?, stats: any? } },
	launcherCapacity: number,
	selectedItemId: string?,
	selectedLauncherId: string?,
	ownedPets: { any },
	equippedPets: { [any]: string },
	selectedPetId: string?,
	lastUseResult: string?,
	itemCooldownEnds: { [string]: number },
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
		ownedPets = {},
		equippedPets = {},
		launcherCapacity = 40,
		selectedItemId = nil,
		selectedLauncherId = nil,
		selectedPetId = nil,
		lastUseResult = nil,
		itemCooldownEnds = {},
		pendingLauncherInstanceId = nil,
		petCapacity = 40,
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
		itemCooldownEnds = table.clone(self._state.itemCooldownEnds),
		ownedPets = cloneLaunchers(self._state.ownedPets),
		equippedPets = table.clone(self._state.equippedPets),
		selectedPetId = self._state.selectedPetId,
		petCapacity = self._state.petCapacity,
	}
end

function InventoryDataProvider:_emitChanged()
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryData] emitChanged items=%d launchers=%d pet=%d selectedPet=%s t=%.3f", (function() local count = 0; for _ in pairs(self._state.ownedItems) do count += 1 end; return count end)(), #self._state.ownedLaunchers, #self._state.ownedPets, tostring(self._state.selectedPetId), os.clock())) end
	self._changed:Fire(self:GetSnapshot())
end

function InventoryDataProvider:BindChanged(callback: (InventorySnapshot) -> ())
	return self._changed.Event:Connect(callback)
end

function InventoryDataProvider:SetFromState(state)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryData] SetFromState incomingType=%s ownedPets=%s equippedPets=%s t=%.3f", type(state), tostring(type(state) == "table" and type(state.OwnedPets) == "table" and (function() local count = 0; for _ in pairs(state.OwnedPets) do count += 1 end; return count end)() or "n/a"), tostring(type(state) == "table" and type(state.EquippedPets) == "table" and (function() local count = 0; for _ in pairs(state.EquippedPets) do count += 1 end; return count end)() or "n/a"), os.clock())) end
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

	local nextItemCooldownEnds = self._state.itemCooldownEnds
	if type(state.ItemCooldownEnds) == "table" then nextItemCooldownEnds = table.clone(state.ItemCooldownEnds) end

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

	local nextPet = self._state.ownedPets
	local incomingPet = state.OwnedPets
	if type(incomingPet) == "table" then
		nextPet = cloneLaunchers(incomingPet)
		for _, entry in ipairs(nextPet) do
			local def = PetsConfig.GetById(entry.definitionId or entry.id or "")
			entry.id = entry.definitionId or entry.id
			entry.name = entry.name or (def and def.DisplayName)
			entry.icon = entry.icon or (def and def.iconId)
		end
	end

	local nextEquippedPets = self._state.equippedPets
	if type(state.EquippedPets) == "table" then
		nextEquippedPets = table.clone(state.EquippedPets)
		nextPet = cloneLaunchers(nextPet)
		for _, entry in ipairs(nextPet) do
			entry.equipped = false
			entry.equippedSlot = nil
			for slot, instanceId in pairs(nextEquippedPets) do
				if instanceId == entry.instanceId then entry.equipped = true; entry.equippedSlot = tonumber(slot) or slot end
			end
		end
	end

	local nextLauncherCapacity = self._state.launcherCapacity
	if type(state.LauncherCapacity) == "number" then
		nextLauncherCapacity = math.max(0, math.floor(state.LauncherCapacity))
	end

	local changed = not deepEqual(nextItems, self._state.ownedItems)
		or not deepEqual(nextItemCooldownEnds, self._state.itemCooldownEnds)
		or not deepEqual(nextLaunchers, self._state.ownedLaunchers)
		or not deepEqual(nextPet, self._state.ownedPets)
		or not deepEqual(nextEquippedPets, self._state.equippedPets)
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
	self._state.itemCooldownEnds = nextItemCooldownEnds
	self._state.ownedLaunchers = nextLaunchers
	self._state.ownedPets = nextPet
	self._state.equippedPets = nextEquippedPets
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

function InventoryDataProvider:SelectPet(petId: string?)
	self._state.selectedPetId = petId
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
	local itemDef = itemId and ItemConfig.GetById(itemId)
	if not itemId or not itemDef then
		self._state.lastUseResult = "Select an item first"
		self:_emitChanged()
		return false
	end
	if itemDef.consumeOnUse ~= true then
		self._state.lastUseResult = "ItemCannotBeUsed"
		self:_emitChanged()
		return false
	end
	if math.max(0, math.floor(self._state.ownedItems[itemId] or 0)) <= 0 then
		self._state.lastUseResult = "NotOwned"
		self:_emitChanged()
		return false
	end
	if consumeItemRemote then
		-- Do not mutate local quantities: StateUpdate is the acknowledgement of use.
		consumeItemRemote:FireServer({ itemId = itemId })
		self._state.lastUseResult = "Requested"
		self:_emitChanged()
		return true
	end
	self._state.lastUseResult = "ConsumeItemRemoteMissing"
	self:_emitChanged()
	return false
end

function InventoryDataProvider:EquipSelectedLauncher(): boolean
	local launcherId = self._state.selectedLauncherId
	local index = launcherId and self:_findLauncherIndex(launcherId)
	if not index or not equipLauncherRemote then self._state.lastUseResult = "LauncherEquipRemoteMissing"; self:_emitChanged(); return false end
	local selected = self._state.ownedLaunchers[index]
	self._state.pendingLauncherInstanceId = selected.instanceId
	self._state.lastUseResult = "LauncherEquipRequested"
	self:_emitChanged()
	equipLauncherRemote:FireServer(selected.instanceId)
	return true
end

function InventoryDataProvider:UnequipSelectedLauncher(): boolean
	if not self._state.selectedLauncherId or not unequipLauncherRemote then return false end
	unequipLauncherRemote:FireServer()
	return true
end

local defaultProvider: any = nil

function InventoryDataProvider.GetDefault()
	if not defaultProvider then
		defaultProvider = InventoryDataProvider.new()
	end
	return defaultProvider
end

function InventoryDataProvider:_findPetIndex(petId: string): number?
	for index, entry in ipairs(self._state.ownedPets) do
		if entry.instanceId == petId or entry.id == petId then return index end
	end
	return nil
end

function InventoryDataProvider:EquipSelectedPet(): boolean
	print("[UI] Action called: Equip Item")
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryData] EquipSelectedPet selected=%s t=%.3f", tostring(self._state.selectedPetId), os.clock())) end
	local petId = self._state.selectedPetId
	local index = petId and self:_findPetIndex(petId)
	if not index then self:_emitChanged(); return false end
	local selected = self._state.ownedPets[index]
	if selected.equipped and unequipPetRemote then
		unequipPetRemote:FireServer(selected.equippedSlot)
		print("[UI] Action Success: Equip Item")
		return true
	end
	if equipPetRemote then
		equipPetRemote:FireServer(selected.instanceId)
		print("[UI] Action Success: Equip Item")
		print(string.format("[System]: Successfully equipped %s", selected.name or selected.id or selected.instanceId))
		return true
	end
	return false
end

function InventoryDataProvider:UnequipSelectedPet(): boolean
	local petId = self._state.selectedPetId
	local index = petId and self:_findPetIndex(petId)
	if not index then self:_emitChanged(); return false end
	local selected = self._state.ownedPets[index]
	if selected.equippedSlot and unequipPetRemote then unequipPetRemote:FireServer(selected.equippedSlot); return true end
	return false
end

return InventoryDataProvider
