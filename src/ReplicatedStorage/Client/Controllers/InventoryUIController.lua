--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local EquipmentUpgradeConfig = require(ReplicatedStorage.Shared.Config.EquipmentUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

local ITEM_TEMPLATE = "ItemSlotTemplate_InventoryUI"
local EQUIPMENT_TEMPLATE = "EquipmentSlotTemplate_InventoryUI"

local function resolve(root: Instance, path: string, className: string): Instance?
	local value = PathResolver.resolvePath(root, path)
	return value and value:IsA(className) and value or nil
end

local function templateRoot(slot: Instance): GuiObject?
	local root = slot:FindFirstChild("Root")
	return root and root:IsA("GuiObject") and root or nil
end

local function text(root: Instance, name: string): TextLabel?
	local value = root:FindFirstChild(name, true)
	return value and value:IsA("TextLabel") and value or nil
end

local function inputTarget(slot: GuiObject): GuiObject
	return (slot:FindFirstChildWhichIsA("TextButton", true) :: GuiObject?) or slot
end

local function formatNumber(value: number): string
	local formatted = string.format("%.2f", value)
	return (formatted:gsub("%.?0+$", ""))
end

function InventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({
		_playerGui = playerGui, _connections = {}, _slotConnections = {}, _itemSlots = {}, _equipmentSlots = {},
		_activeTab = "Items", _selectedItemId = nil, _selectedEquipmentId = nil,
	}, InventoryUIController)
end

function InventoryUIController:SetDataProvider(provider) self._dataProvider = provider end
function InventoryUIController:SetConfirmationController(controller) self._confirmation = controller end

function InventoryUIController:Start(uiReadySignal: BindableEvent?)
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then uiReadySignal.Event:Wait() end
	self._gui = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ScreenGui, "ScreenGui") :: ScreenGui?
	self._itemsBody = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyItems, "GuiObject") :: GuiObject?
	self._equipmentBody = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyEquipment, "GuiObject") :: GuiObject?
	self._itemsGrid = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsGridContainer, "GuiObject") :: GuiObject?
	self._equipmentGrid = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentGridContainer, "GuiObject") :: GuiObject?
	self._itemsTab = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsTab, "TextButton") :: TextButton?
	self._equipmentTab = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentTab, "TextButton") :: TextButton?
	self._close = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.CloseButton, "TextButton") :: TextButton?
	self._itemName = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsSelectedName, "TextLabel") :: TextLabel?
	self._itemStats = {
		resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat1, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat2, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat3, "TextLabel"),
	}
	self._itemUse = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsUseButton, "TextButton") :: TextButton?
	self._equipmentName = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentSelectedName, "TextLabel") :: TextLabel?
	self._equipmentStats = {
		resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatDamage, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatHP, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatRange, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatRegen, "TextLabel"),
	}
	self._equipmentToggle = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentToggleEquipButton, "TextButton") :: TextButton?
	self._equipmentDelete = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentDeleteButton, "TextButton") :: TextButton?
	self._equipmentUpgrade = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentUpgradeButton, "TextButton") :: TextButton?
	self._equipmentCapacity = resolve(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentCapacityLabel, "TextLabel") :: TextLabel?

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local ui = assets:FindFirstChild("UI")
	self._equipmentAssets = assets:FindFirstChild("Equipment")
	self._itemTemplate = ui and ui:FindFirstChild(ITEM_TEMPLATE) :: GuiObject?
	self._equipmentTemplate = ui and ui:FindFirstChild(EQUIPMENT_TEMPLATE) :: GuiObject?
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._upgradeRemote = remotes:FindFirstChild(RemoteContracts.Names.UpgradeEquipment) :: RemoteEvent?

	local function connect(button: TextButton?, callback: () -> ()) if button then table.insert(self._connections, button.MouseButton1Click:Connect(callback)) end end
	connect(self._itemsTab, function() self:SetActiveTab("Items") end)
	connect(self._equipmentTab, function() self:SetActiveTab("Equipment") end)
	connect(self._close, function() self:SetVisible(false) end)
	connect(self._itemUse, function() if self._dataProvider then self._dataProvider:UseSelectedItem() end end)
	connect(self._equipmentToggle, function() if self._dataProvider then self._dataProvider:EquipSelectedEquipment() end end)
	connect(self._equipmentDelete, function() if self._dataProvider then self._dataProvider:UnequipSelectedEquipment() end end)
	connect(self._equipmentUpgrade, function()
		if not (self._selectedEquipmentId and self._upgradeRemote) then return end
		local function upgrade() self._upgradeRemote:FireServer(self._selectedEquipmentId) end
		if self._confirmation then self._confirmation:RequestConfirm("Upgrade this equipment?", upgrade) else upgrade() end
	end)
	self:SetActiveTab(self._activeTab)
end

function InventoryUIController:SetVisible(visible: boolean)
	if self._gui then self._gui.Enabled = visible end
	if visible and self._snapshot then self:RefreshWithData(self._snapshot) end
end

function InventoryUIController:SetActiveTab(tab: string)
	self._activeTab = tab == "Equipment" and "Equipment" or "Items"
	if self._itemsBody then self._itemsBody.Visible = self._activeTab == "Items" end
	if self._equipmentBody then self._equipmentBody.Visible = self._activeTab == "Equipment" end
end

function InventoryUIController:_disconnectSlot(slot: GuiObject)
	local connections = self._slotConnections[slot]
	if connections then for _, connection in ipairs(connections) do connection:Disconnect() end end
	self._slotConnections[slot] = nil
end

function InventoryUIController:_bindSlot(slot: GuiObject, kind: string, id: string)
	self:_disconnectSlot(slot)
	local target = inputTarget(slot)
	self._slotConnections[slot] = { target.MouseButton1Click:Connect(function()
		if kind == "Item" then self._selectedItemId = id; if self._dataProvider then self._dataProvider:SelectItem(id) end
		else self._selectedEquipmentId = id; if self._dataProvider then self._dataProvider:SelectEquipment(id) end end
		if self._snapshot then self:RefreshWithData(self._snapshot) end
	end) }
end

function InventoryUIController:_upsertItem(itemId: string, quantity: number)
	if not (self._itemsGrid and self._itemTemplate and self._itemTemplate:IsA("GuiObject")) then return end
	local def = ItemConfig.GetById(itemId); if not def then return end
	local slot = self._itemSlots[itemId]
	if not (slot and slot.Parent) then slot = self._itemTemplate:Clone(); slot.Name = "GeneratedItem_" .. itemId; slot.Parent = self._itemsGrid; self._itemSlots[itemId] = slot; self:_bindSlot(slot, "Item", itemId) end
	slot.Visible = true
	local root = templateRoot(slot); if not root then return end
	local name, icon, amount = text(root, "Name"), root:FindFirstChild("Icon", true), text(root, "Quantity")
	if name then name.Text = def.name end
	if icon and icon:IsA("ImageLabel") then icon.Image = def.icon end
	if amount then amount.Text = "x" .. tostring(math.max(0, quantity)) end
end

function InventoryUIController:_upsertEquipment(entry: any)
	if not (self._equipmentGrid and self._equipmentTemplate and self._equipmentTemplate:IsA("GuiObject")) then return end
	local id = tostring(entry.instanceId or ""); local definitionId = tostring(entry.definitionId or entry.id or "")
	local def = EquipmentConfig.GetById(definitionId); if id == "" or not def then return end
	local slot = self._equipmentSlots[id]
	if not (slot and slot.Parent) then slot = self._equipmentTemplate:Clone(); slot.Name = "GeneratedEquipment_" .. id; slot.Parent = self._equipmentGrid; self._equipmentSlots[id] = slot; self:_bindSlot(slot, "Equipment", id) end
	slot.Visible = true
	local root = templateRoot(slot); if not root then return end
	local name, level, equipped = text(root, "Name"), text(root, "Level"), text(root, "EquippedTag")
	if name then name.Text = entry.name or def.name end
	if level then level.Text = "Lv." .. tostring(math.max(1, math.floor(entry.level or 1))) end
	if equipped then equipped.Visible = entry.equipped == true; equipped.Text = entry.equippedSlot and "Slot " .. tostring(entry.equippedSlot) or "Equipped" end
	local preview = root:FindFirstChild("EquipmentPreview", true)
	if preview and preview:IsA("ViewportFrame") then PreviewRenderer.Populate(preview, self._equipmentAssets, definitionId) end
end

function InventoryUIController:_removeUnseen(map, seen)
	for id, slot in pairs(map) do if not seen[id] then self:_disconnectSlot(slot); if slot.Parent then slot:Destroy() end; map[id] = nil end end
end

function InventoryUIController:_refreshEquipmentPanel(data)
	local selectedId = data.selectedEquipmentId or self._selectedEquipmentId
	self._selectedEquipmentId = selectedId
	local entry
	for _, candidate in ipairs(data.ownedEquipment or {}) do if candidate.instanceId == selectedId or candidate.id == selectedId then entry = candidate; break end end
	local def = entry and EquipmentConfig.GetById(tostring(entry.definitionId or entry.id or "")) or nil
	if self._equipmentName then self._equipmentName.Text = entry and (entry.name or def.name) or "No equipment selected" end
	local level = math.max(1, math.floor(tonumber(entry and entry.level) or 1))
	local modifiers = def and def.statModifiers or {}; local add = modifiers.Add or {}; local multiply = modifiers.Multiply or {}
	local values = { add.baseDamage or 0, add.maxHP or 0, multiply.launchRange or multiply.launchSpeed or 0, add.regen or 0 }
	local labels = { "Damage", "HP", "Range", "Regen" }
	for index, statLabel in ipairs(self._equipmentStats) do
		if statLabel and statLabel:IsA("TextLabel") then
			local current, nextValue = EquipmentUpgradeConfig.GetStatAtLevel(values[index], level), EquipmentUpgradeConfig.GetStatAtLevel(values[index], level + 1)
			statLabel.RichText = true; statLabel.Text = string.format("%s: %s <font color=\"#00ff00\">➔ %s</font>", labels[index], formatNumber(current), formatNumber(nextValue))
		end
	end
	if self._equipmentToggle then self._equipmentToggle.Text = entry and (entry.equipped and "Unequip" or "Equip") or "Equip"; self._equipmentToggle.Active = entry ~= nil end
	if self._equipmentUpgrade then self._equipmentUpgrade.Text = entry and string.format("Upgrade %d Diamonds", EquipmentUpgradeConfig.GetUpgradeCost(level)) or "Upgrade"; self._equipmentUpgrade.Active = entry ~= nil end
end

function InventoryUIController:RefreshWithData(data)
	self._snapshot = data
	local seenItems, seenEquipment = {}, {}
	for itemId, quantity in pairs(data.ownedItems or {}) do seenItems[itemId] = true; self:_upsertItem(itemId, quantity) end
	for _, entry in ipairs(data.ownedEquipment or {}) do local id = tostring(entry.instanceId or ""); if id ~= "" then seenEquipment[id] = true; self:_upsertEquipment(entry) end end
	self:_removeUnseen(self._itemSlots, seenItems); self:_removeUnseen(self._equipmentSlots, seenEquipment)
	if self._equipmentCapacity then self._equipmentCapacity.Text = string.format("%d/%d", #(data.ownedEquipment or {}), data.equipmentCapacity or 40) end
	self:_refreshEquipmentPanel(data)
	local itemId = data.selectedItemId or self._selectedItemId; self._selectedItemId = itemId
	local item = itemId and ItemConfig.GetById(itemId) or nil
	if self._itemName then self._itemName.Text = item and item.name or "No item selected" end
	if self._itemStats[1] and self._itemStats[1]:IsA("TextLabel") then self._itemStats[1].Text = "Quantity: " .. tostring(itemId and (data.ownedItems[itemId] or 0) or 0) end
	if self._itemStats[2] and self._itemStats[2]:IsA("TextLabel") then self._itemStats[2].Text = item and "Type: " .. tostring(item.type) or "Type: -" end
	if self._itemStats[3] and self._itemStats[3]:IsA("TextLabel") then self._itemStats[3].Text = data.lastUseResult or "Use: ready" end
end

function InventoryUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for slot in pairs(self._slotConnections) do self:_disconnectSlot(slot) end
end

return InventoryUIController
