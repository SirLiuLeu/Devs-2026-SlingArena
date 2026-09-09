--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local EquipmentUpgradeConfig = require(ReplicatedStorage.Shared.Config.EquipmentUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)

local InventoryUIController = {}; InventoryUIController.__index = InventoryUIController

local function get(root: Instance, path: string, className: string): Instance?
	local result = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return result and result:IsA(className) and result or nil
end
local function statBase(def, name: string): number
	local add = def and def.statModifiers and def.statModifiers.Add or {}
	local passive = def and def.passiveAbility or {}
	if name == "Damage" then return tonumber(add.baseDamage) or 0 end
	if name == "HP" then return tonumber(add.maxHP) or 0 end
	if name == "Range" then return tonumber(add.range) or tonumber(add.launchRange) or 0 end
	return tonumber(add.regen) or (passive.type == "Regeneration" and tonumber(passive.value) or 0) or 0
end
local function numberText(value: number): string return value % 1 == 0 and tostring(math.floor(value)) or string.format("%.1f", value) end

function InventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {}, _selectedEquipmentId = nil, _activeTab = "Items" }, InventoryUIController)
end
function InventoryUIController:SetDataProvider(provider) self._provider = provider end
function InventoryUIController:SetConfirmationController(controller) self._confirmation = controller end

function InventoryUIController:Start(uiReadySignal: BindableEvent?)
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then uiReadySignal.Event:Wait() end
	self._gui = get(self._playerGui, ProjectTreeSpec.UI.Inventory.ScreenGui, "ScreenGui") :: ScreenGui?
	self._itemsBody = get(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyItems, "GuiObject") :: GuiObject?
	self._equipmentBody = get(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyEquipment, "GuiObject") :: GuiObject?
	self._itemsGrid = get(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsGridContainer, "GuiObject") :: GuiObject?
	self._equipmentGrid = get(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentGridContainer, "GuiObject") :: GuiObject?
	self._itemsTab = get(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsTab, "TextButton") :: TextButton?
	self._equipmentTab = get(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentTab, "TextButton") :: TextButton?
	self._close = get(self._playerGui, ProjectTreeSpec.UI.Inventory.CloseButton, "TextButton") :: TextButton?
	self._selectedName = get(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentSelectedName, "TextLabel") :: TextLabel?
	self._toggleEquip = get(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentToggleEquipButton, "TextButton") :: TextButton?
	self._upgrade = get(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentUpgradeButton, "TextButton") :: TextButton?
	self._capacity = get(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentCapacityLabel, "TextLabel") :: TextLabel?
	self._stats = {}
	for _, name in ipairs({ "Damage", "HP", "Range", "Regen" }) do self._stats[name] = get(self._playerGui, ProjectTreeSpec.UI.Inventory["EquipmentStat" .. name], "TextLabel") end
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._equipRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipEquipment) :: RemoteEvent?
	self._unequipRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipEquipment) :: RemoteEvent?
	self._upgradeRemote = remotes:FindFirstChild(RemoteContracts.Names.UpgradeEquipment) :: RemoteEvent?
	if self._itemsTab then table.insert(self._connections, self._itemsTab.MouseButton1Click:Connect(function() self:SetActiveTab("Items") end)) end
	if self._equipmentTab then table.insert(self._connections, self._equipmentTab.MouseButton1Click:Connect(function() self:SetActiveTab("Equipment") end)) end
	if self._close then table.insert(self._connections, self._close.MouseButton1Click:Connect(function() self:SetVisible(false) end)) end
	if self._toggleEquip then table.insert(self._connections, self._toggleEquip.MouseButton1Click:Connect(function() self:_toggleSelectedEquipment() end)) end
	if self._upgrade then table.insert(self._connections, self._upgrade.MouseButton1Click:Connect(function() self:_requestUpgrade() end)) end
	if self._provider then self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end); self:Render(self._provider:GetSnapshot()) end
	self:SetActiveTab("Items")
end

function InventoryUIController:SetVisible(value: boolean) if self._gui then self._gui.Enabled = value end end
function InventoryUIController:SetActiveTab(tab: string)
	self._activeTab = tab
	if self._itemsBody then self._itemsBody.Visible = tab == "Items" end
	if self._equipmentBody then self._equipmentBody.Visible = tab == "Equipment" end
end
function InventoryUIController:_entry()
	for _, entry in ipairs((self._snapshot and self._snapshot.ownedEquipment) or {}) do if entry.instanceId == self._selectedEquipmentId then return entry end end
	return nil
end
function InventoryUIController:_toggleSelectedEquipment()
	local entry = self:_entry(); if not entry then return end
	if entry.equipped then
		MockPlayerData.UnequipEquipment(entry.instanceId, "EquipmentUnequipped")
		if self._unequipRemote then self._unequipRemote:FireServer(entry.equippedSlot) end
	else
		MockPlayerData.EquipEquipment(entry.instanceId, "EquipmentEquipped")
		if self._equipRemote then self._equipRemote:FireServer(entry.instanceId) end
	end
end
function InventoryUIController:_requestUpgrade()
	local entry = self:_entry(); if not entry then return end
	local def = EquipmentConfig.GetById(entry.definitionId or entry.id or ""); local level = math.max(1, tonumber(entry.level) or 1)
	local maxLevel = def and EquipmentConfig.GetMaxLevelForRarity(def.rarity) or EquipmentUpgradeConfig.MaxLevel
	if level >= maxLevel then return end
	local cost = EquipmentUpgradeConfig.GetUpgradeCost(level)
	local function upgrade()
		if MockPlayerData.UpgradeEquipment(entry.instanceId, cost, maxLevel, "EquipmentUpgrade") and self._upgradeRemote then self._upgradeRemote:FireServer(entry.instanceId) end
	end
	if self._confirmation then self._confirmation:RequestConfirm(string.format("Upgrade %s for %d Diamonds?", entry.name or entry.id, cost), upgrade) else upgrade() end
end
function InventoryUIController:_renderEquipmentPanel()
	local entry = self:_entry(); local def = entry and EquipmentConfig.GetById(entry.definitionId or entry.id or "") or nil
	if self._selectedName then self._selectedName.Text = entry and (entry.name or (def and def.name) or entry.id) or "No equipment selected" end
	local level = math.max(1, tonumber(entry and entry.level) or 1)
	for name, label in pairs(self._stats) do
		if label then
			local current = EquipmentUpgradeConfig.GetScaledStat(statBase(def, name), level)
			local nextValue = EquipmentUpgradeConfig.GetScaledStat(statBase(def, name), level + 1)
			label.RichText = true; label.Text = string.format("%s: %s <font color=\"#00ff00\">➔ %s</font>", name, numberText(current), numberText(nextValue))
		end
	end
	if self._toggleEquip then self._toggleEquip.Text = entry and entry.equipped and "Unequip" or "Equip"; self._toggleEquip.Active = entry ~= nil end
	if self._upgrade then self._upgrade.Text = string.format("Upgrade %d Diamonds", EquipmentUpgradeConfig.GetUpgradeCost(level)); self._upgrade.Active = entry ~= nil end
end
function InventoryUIController:RefreshWithData(snapshot)
	self:Render(snapshot)
end

function InventoryUIController:Render(snapshot)
	self._snapshot = snapshot
	if self._equipmentGrid then
		for _, child in ipairs(self._equipmentGrid:GetChildren()) do if child.Name:sub(1, 19) == "GeneratedEquipment_" then child:Destroy() end end
		for _, entry in ipairs(snapshot.ownedEquipment or {}) do
			local button = Instance.new("TextButton"); button.Name = "GeneratedEquipment_" .. entry.instanceId; button.Size = UDim2.fromOffset(160, 42); button.Text = string.format("%s Lv.%d", entry.name or entry.id, entry.level or 1); button.Parent = self._equipmentGrid
			table.insert(self._connections, button.MouseButton1Click:Connect(function() self._selectedEquipmentId = entry.instanceId; self:_renderEquipmentPanel() end))
		end
	end
	if not self:_entry() then local first = snapshot.ownedEquipment and snapshot.ownedEquipment[1]; self._selectedEquipmentId = first and first.instanceId or nil end
	if self._capacity then self._capacity.Text = string.format("Capacity: %d/%d", #(snapshot.ownedEquipment or {}), snapshot.equipmentCapacity or 0) end
	self:_renderEquipmentPanel()
end
function InventoryUIController:Destroy() for _, c in ipairs(self._connections) do c:Disconnect() end; if self._providerConnection then self._providerConnection:Disconnect() end end
return InventoryUIController
