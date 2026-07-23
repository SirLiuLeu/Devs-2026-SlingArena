--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local MockData = require(ReplicatedStorage.Client.Services.MockData)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local consumeHpPotionRemote = remotes:FindFirstChild(RemoteContracts.Names.ConsumeHpPotion) :: RemoteEvent?

local InventoryDataProvider = {}
InventoryDataProvider.__index = InventoryDataProvider

export type InventorySnapshot = {
	ownedItems: { [string]: number },
	ownedLaunchers: { { instanceId: string, definitionId: string, id: string, star: number, level: number, equipped: boolean, name: string?, icon: string?, stats: any? } },
	launcherCapacity: number,
	selectedItemId: string?,
	selectedLauncherId: string?,
	lastUseResult: string?,
}

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
		launcherCapacity = 40,
		selectedItemId = nil,
		selectedLauncherId = nil,
		lastUseResult = nil,
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

	local incomingLaunchers = state.OwnedLaunchers
	if type(incomingLaunchers) == "table" then
		self._state.ownedLaunchers = cloneLaunchers(incomingLaunchers)
	end

	if type(state.EquippedLauncherInstanceId) == "string" then
		for _, launcherEntry in ipairs(self._state.ownedLaunchers) do
			launcherEntry.equipped = launcherEntry.instanceId == state.EquippedLauncherInstanceId
		end
	end

	if type(state.LauncherCapacity) == "number" then
		self._state.launcherCapacity = math.max(0, math.floor(state.LauncherCapacity))
	end

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
		self._state.lastUseResult = "Requested"
		self:_emitChanged()
		return true
	end

	local success, message = MockPlayerData.UseItem(itemId, "InventoryUseItem")
	self._state.lastUseResult = message
	if not success then
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
	local equipped = MockPlayerData.EquipLauncher(selected.instanceId, "InventoryEquipLauncher")
	if equipped then
		local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
		local abilityTrigger = remotes and remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger)
		if abilityTrigger and abilityTrigger:IsA("RemoteEvent") then
			abilityTrigger:FireServer({
				action = "EquipLauncher",
				launcherId = selected.id,
				instanceId = selected.instanceId,
			})
		end
	else
		self:_emitChanged()
	end
	return equipped
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

return InventoryDataProvider
