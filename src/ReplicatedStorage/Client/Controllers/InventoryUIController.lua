--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local EquipmentUpgradeConfig = require(ReplicatedStorage.Shared.Config.EquipmentUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

local NORMAL_COLOR = Color3.fromRGB(41, 43, 53)
local HOVER_COLOR = Color3.fromRGB(62, 66, 82)
local SELECTED_COLOR = Color3.fromRGB(88, 102, 132)
local ITEM_SLOT_TEMPLATE_NAME = "ItemSlotTemplate_InventoryUI"
local EQUIPMENT_SLOT_TEMPLATE_NAME = "EquipmentSlotTemplate_InventoryUI"

local function resolveGui(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("GuiObject") then
		return value
	end
	return nil
end

local function resolveTextLabel(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextLabel") then
		return value
	end
	return nil
end

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextButton") then
		return value
	end
	return nil
end

local function getTemplateRoot(slot: Instance, templateName: string): GuiObject?
	local root = slot:FindFirstChild("Root")
	if root and root:IsA("GuiObject") then
		return root
	end
	warn(string.format("[INVENTORY_UI] %s clone is missing required Root GuiObject", templateName))
	return nil
end

local function findDirectTemplateText(root: Instance, childName: string): TextLabel?
	local child = root:FindFirstChild(childName)
	if child and child:IsA("TextLabel") then
		return child
	end
	return nil
end

local function findDirectTemplateImage(root: Instance, childName: string): ImageLabel?
	local child = root:FindFirstChild(childName)
	if child and child:IsA("ImageLabel") then
		return child
	end
	return nil
end

local function findUiTemplate(uiFolder: Instance, templateName: string, legacyTemplateName: string?): GuiObject?
	local template = uiFolder:FindFirstChild(templateName)
	if template and template:IsA("GuiObject") then
		return template
	end

	if legacyTemplateName then
		local legacyTemplate = uiFolder:FindFirstChild(legacyTemplateName)
		if legacyTemplate and legacyTemplate:IsA("GuiObject") then
			return legacyTemplate
		end
	end

	return nil
end

function InventoryUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, InventoryUIController)
	self._playerGui = playerGui
	self._spawnedItemSlots = {}
	self._spawnedEquipmentSlots = {}
	self._connections = {}
	self._activeTab = "Items"
	self._slotConnections = {}
	self._slotConnectionMap = {}
	self._itemSlotMap = {}
	self._equipmentSlotMap = {}
	self._selectedItemId = nil
	self._selectedEquipmentId = nil
	self._cachedSnapshot = nil
	return self
end

function InventoryUIController:SetDataProvider(provider)
	self._dataProvider = provider
end

function InventoryUIController:Start(uiReadySignal: BindableEvent?)
	-- The UI builder owns the readiness boundary. Resolving paths before it fires
	-- creates false missing-path diagnostics while StarterGui is still cloning.
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then
		uiReadySignal.Event:Wait()
	end
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] Start existingConnections=%d t=%.3f", #self._connections, os.clock())) end
	self._inventoryGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Inventory.ScreenGui)
	self._itemsGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsGridContainer)
	self._itemsBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyItems)
	self._equipmentBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyEquipment)
	self._equipmentGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentGridContainer)
	self._itemsTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsTab)
	self._equipmentTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentTab)
	self._closeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.CloseButton)
	self._equipmentCapacityLabel = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentCapacityLabel)

	self._itemSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsSelectedName)
	self._itemStat1 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat1)
	self._itemStat2 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat2)
	self._itemStat3 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat3)
	self._itemUseButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsUseButton)

	self._equipmentSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentSelectedName)
	self._equipmentStatDamage = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatDamage)
	self._equipmentStatHP = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatHP)
	self._equipmentStatRange = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatRange)
	self._equipmentStatRegen = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentStatRegen)
	self._equipmentEquipButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentEquipButton)
	self._equipmentDeleteButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentDeleteButton)
	self._equipmentUpgradeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentUpgradeButton)
	self._upgradeEquipmentRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.UpgradeEquipment) :: RemoteEvent?

	local assets = ReplicatedStorage:WaitForChild("Assets")
	if not assets then
		warn("[INVENTORY_UI] ReplicatedStorage.Assets missing")
	else
		self._equipmentAssets = assets:FindFirstChild("Equipment")
		local uiFolder = assets:FindFirstChild("UI")
		if not uiFolder then
			warn("[INVENTORY_UI] ReplicatedStorage.Assets.UI missing")
		else
			self._itemTemplate = findUiTemplate(uiFolder, ITEM_SLOT_TEMPLATE_NAME, nil)
			self._equipmentTemplate = findUiTemplate(uiFolder, EQUIPMENT_SLOT_TEMPLATE_NAME, nil)
			if not self._itemTemplate then
				warn("[INVENTORY_UI] " .. ITEM_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
			if not self._equipmentTemplate then
				warn("[INVENTORY_UI] " .. EQUIPMENT_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
		end
	end
	if not self._equipmentAssets then warn("[INVENTORY_UI] ReplicatedStorage.Assets.Equipment missing") end

	if not self._inventoryGui then warn("[INVENTORY_UI] InventoryUI ScreenGui missing") end
	if not self._itemsGrid then warn("[INVENTORY_UI] Items grid container missing") end
	if not self._itemsBody then warn("[INVENTORY_UI] Items body frame missing") end
	if not self._equipmentBody then warn("[INVENTORY_UI] BodyEquipment missing at StarterGui/InventoryUI/Root/BodyEquipment") end
	if not self._equipmentGrid then warn("[INVENTORY_UI] GridContainer missing at StarterGui/InventoryUI/Root/BodyEquipment/GridContainer") end
	if not self._itemsTab then warn("[INVENTORY_UI] ItemsTab button missing") end
	if not self._closeButton then warn("[INVENTORY_UI] CloseButton missing") end

	if self._itemsTab then
		table.insert(self._connections, self._itemsTab.MouseButton1Click:Connect(function()
			self:SetActiveTab("Items")
		end))
	end
	if self._equipmentTab then
		table.insert(self._connections, self._equipmentTab.MouseButton1Click:Connect(function() self:SetActiveTab("Equipment") end))
	end
	if self._closeButton then
		table.insert(self._connections, self._closeButton.MouseButton1Click:Connect(function()
			self:SetVisible(false)
		end))
	end
	if self._itemUseButton then
		table.insert(self._connections, self._itemUseButton.MouseButton1Click:Connect(function()
			if self._dataProvider then
				self._dataProvider:UseSelectedItem()
			end
		end))
	else
		warn("[INVENTORY_UI] " .. ProjectTreeSpec.UI.Inventory.ItemsUseButton .. " missing")
	end
	if self._equipmentEquipButton then table.insert(self._connections, self._equipmentEquipButton.MouseButton1Click:Connect(function() if self._dataProvider then self._dataProvider:EquipSelectedEquipment() end end)) end
	if self._equipmentDeleteButton then table.insert(self._connections, self._equipmentDeleteButton.MouseButton1Click:Connect(function() if self._dataProvider then self._dataProvider:UnequipSelectedEquipment() end end)) end
	if self._equipmentUpgradeButton then table.insert(self._connections, self._equipmentUpgradeButton.MouseButton1Click:Connect(function() if self._selectedEquipmentId and self._upgradeEquipmentRemote then self._upgradeEquipmentRemote:FireServer(self._selectedEquipmentId) end end)) end

	self:SetActiveTab(self._activeTab)
end

function InventoryUIController:SetVisible(isVisible: boolean)
	if self._inventoryGui and self._inventoryGui:IsA("ScreenGui") then
		self._inventoryGui.Enabled = isVisible
	end
	if isVisible and self._cachedSnapshot then
		self:RefreshWithData(self._cachedSnapshot)
	end
end

function InventoryUIController:SetActiveTab(tabName: string)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] SetActiveTab requested=%s previous=%s t=%.3f", tostring(tabName), tostring(self._activeTab), os.clock())) end
	self._activeTab = if tabName == "Equipment" then "Equipment" else "Items"
	if self._itemsBody then
		self._itemsBody.Visible = self._activeTab == "Items"
	end
	if self._equipmentBody then self._equipmentBody.Visible = self._activeTab == "Equipment" end
end

function InventoryUIController:_disconnectSlotConnections()
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
	if self._slotConnectionMap then table.clear(self._slotConnectionMap) end
end

function InventoryUIController:_disconnectSlot(slot: Instance)
	local slotConnections = self._slotConnectionMap and self._slotConnectionMap[slot]
	if not slotConnections then return end
	for _, connection in ipairs(slotConnections) do
		connection:Disconnect()
		local index = table.find(self._slotConnections, connection)
		if index then table.remove(self._slotConnections, index) end
	end
	self._slotConnectionMap[slot] = nil
end

function InventoryUIController:_clearGeneratedSlots()
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] clearGeneratedSlots items=%d equipment=%d slotConnections=%d t=%.3f", #self._spawnedItemSlots, #self._spawnedEquipmentSlots, #self._slotConnections, os.clock())) end
	if self._itemsGrid then
		for _, child in ipairs(self._itemsGrid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	if self._equipmentGrid then
		for _, child in ipairs(self._equipmentGrid:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	end
	for _, slot in ipairs(self._spawnedItemSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self._spawnedItemSlots)
	table.clear(self._spawnedEquipmentSlots)
	table.clear(self._itemSlotMap)
	table.clear(self._equipmentSlotMap)
	self:_disconnectSlotConnections()
end

function InventoryUIController:_bindCommonSlot(slot: Instance, name: string, icon: string?)
	local nameLabel = findDirectTemplateText(slot, "Name")
	if nameLabel then
		nameLabel.Text = name
	end

	local iconLabel = findDirectTemplateImage(slot, "Icon")
	if iconLabel and icon then
		iconLabel.Image = icon
	end
end

function InventoryUIController:_populateEquipmentPreview(slotRoot: Instance, definitionId: string)
	local preview = slotRoot:FindFirstChild("EquipmentPreview", true)
	if preview and preview:IsA("ViewportFrame") then
		PreviewRenderer.Populate(preview, self._equipmentAssets, definitionId)
	else
		warn("[INVENTORY_UI] Equipment slot is missing EquipmentPreview ViewportFrame")
	end
end

function InventoryUIController:_bindEquipmentSlot(slotRoot: Instance, name: string, definitionId: string)
	local nameLabel = findDirectTemplateText(slotRoot, "Name")
	if nameLabel then
		nameLabel.Text = name
	end
	self:_populateEquipmentPreview(slotRoot, definitionId)
end

function InventoryUIController:_applySlotVisual(slot: GuiObject, isHovered: boolean, isSelected: boolean)
	slot.BackgroundColor3 = isSelected and SELECTED_COLOR or (isHovered and HOVER_COLOR or NORMAL_COLOR)
	local stroke = slot:FindFirstChildWhichIsA("UIStroke", true)
	if stroke then
		stroke.Thickness = isSelected and 2 or 1
		stroke.Color = isSelected and Color3.fromRGB(255, 230, 130) or Color3.fromRGB(120, 120, 120)
	end
end

function InventoryUIController:_bindSlotState(slot: GuiObject, listType: string, id: string)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] bindSlotState type=%s id=%s existingSlotConnections=%d t=%.3f", tostring(listType), tostring(id), #self._slotConnections, os.clock())) end
	slot.BackgroundTransparency = 0
	slot.Active = true
	slot.Selectable = true
	local hoverState = false

	local clickTarget: GuiObject = slot
	local button = slot:FindFirstChildWhichIsA("TextButton", true)
	if button then
		clickTarget = button
	end

	self:_applySlotVisual(slot, false, false)

	local slotConnections = {}
	local function track(connection)
		table.insert(slotConnections, connection)
		table.insert(self._slotConnections, connection)
	end

	track(clickTarget.MouseEnter:Connect(function()
		hoverState = true
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Equipment" and self._selectedEquipmentId == id)
		self:_applySlotVisual(slot, hoverState, selected)
	end))
	track(clickTarget.MouseLeave:Connect(function()
		hoverState = false
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Equipment" and self._selectedEquipmentId == id)
		self:_applySlotVisual(slot, hoverState, selected)
	end))
	track(clickTarget.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if listType == "Item" then
			self._selectedItemId = id
			if self._dataProvider then
				self._dataProvider:SelectItem(id)
			end
		elseif listType == "Equipment" then
			self._selectedEquipmentId = id
			if self._dataProvider then self._dataProvider:SelectEquipment(id) end
		end
		if self._cachedSnapshot then
			self:RefreshWithData(self._cachedSnapshot)
		end
	end))
	self._slotConnectionMap[slot] = slotConnections
end

function InventoryUIController:_spawnItemSlot(itemId: string, quantity: number)
	if not self._itemsGrid or not self._itemTemplate or not self._itemTemplate:IsA("GuiObject") then
		return
	end
	local itemDef = ItemConfig.GetById(itemId)
	if not itemDef then
		warn(string.format("[INVENTORY_UI] Unknown item id in owned data: %s", itemId))
		return
	end

	local slot = self._itemTemplate:Clone()
	local slotRoot = getTemplateRoot(slot, ITEM_SLOT_TEMPLATE_NAME)
	if not slotRoot then
		slot:Destroy()
		return
	end
	slot.Name = string.format("GeneratedItem_%s", itemId)
	slot.Visible = true
	slot.Parent = self._itemsGrid
	self:_bindCommonSlot(slotRoot, itemDef.name, itemDef.icon)

	local quantityLabel = findDirectTemplateText(slotRoot, "Quantity")
	if quantityLabel then
		quantityLabel.Text = string.format("x%d", math.max(0, quantity))
	end

	self._itemSlotMap[itemId] = slot
	self:_bindSlotState(slot, "Item", itemId)
	table.insert(self._spawnedItemSlots, slot)
end



local function formatRemainingLifetime(entry): string
	local expiresAt = tonumber(entry.expiresAt or entry.ExpiresAt or entry.remainingLifetimeEndsAt or entry.RemainingLifetimeEndsAt)
	if expiresAt then
		local remaining = math.max(0, math.ceil(expiresAt - os.time()))
		if remaining > 0 then return string.format("%ds", remaining) end
	end
	local remainingSeconds = tonumber(entry.remainingLifetimeSeconds or entry.RemainingLifetimeSeconds or entry.remainingTime or entry.RemainingTime)
	if remainingSeconds and remainingSeconds > 0 then return string.format("%ds", math.ceil(remainingSeconds)) end
	return "Permanent"
end

function InventoryUIController:_spawnEquipmentSlot(equipmentEntry)
	if not self._equipmentGrid then warn("[INVENTORY_UI] Cannot spawn equipment: GridContainer missing at StarterGui/InventoryUI/Root/BodyEquipment/GridContainer"); return end
	if not self._equipmentTemplate or not self._equipmentTemplate:IsA("GuiObject") then warn("[INVENTORY_UI] Cannot spawn equipment: template missing at ReplicatedStorage/Assets/UI/EquipmentSlotTemplate_InventoryUI"); return end
	local instanceId = tostring(equipmentEntry.instanceId or "")
	local definitionId = tostring(equipmentEntry.definitionId or equipmentEntry.id or "")
	if instanceId == "" or definitionId == "" then return end
	local def = EquipmentConfig.GetById(definitionId)
	if not def then warn(string.format("[INVENTORY_UI] Unknown equipment definition id in owned data: %s", definitionId)); return end
	local slot = self._equipmentTemplate:Clone()
	local slotRoot = getTemplateRoot(slot, EQUIPMENT_SLOT_TEMPLATE_NAME)
	if not slotRoot then slot:Destroy(); return end
	slot.Name = string.format("GeneratedEquipment_%s", instanceId)
	slot.Visible = true
	slot.Parent = self._equipmentGrid
	self:_bindEquipmentSlot(slotRoot, equipmentEntry.name or def.name, definitionId)
	local remainingTimeText = findDirectTemplateText(slotRoot, "RemainingTimeText")
	if remainingTimeText then remainingTimeText.Text = formatRemainingLifetime(equipmentEntry) end
	local levelLabel = findDirectTemplateText(slotRoot, "Level")
	if levelLabel then levelLabel.Text = string.format("Lv.%d", math.max(1, equipmentEntry.level or 1)) end
	local equippedTag = findDirectTemplateText(slotRoot, "EquippedTag")
	if equippedTag then
		equippedTag.Visible = equipmentEntry.equipped == true
		equippedTag.Text = equipmentEntry.equippedSlot and ("Slot " .. tostring(equipmentEntry.equippedSlot)) or "Equipped"
	end
	self._equipmentSlotMap[instanceId] = slot
	self:_bindSlotState(slot, "Equipment", instanceId)
	table.insert(self._spawnedEquipmentSlots, slot)
end

function InventoryUIController:_updateItemSlot(slot: GuiObject, itemId: string, quantity: number)
	local itemDef = ItemConfig.GetById(itemId)
	if not itemDef then return end
	local slotRoot = getTemplateRoot(slot, ITEM_SLOT_TEMPLATE_NAME)
	if not slotRoot then return end
	self:_bindCommonSlot(slotRoot, itemDef.name, itemDef.icon)
	local quantityLabel = findDirectTemplateText(slotRoot, "Quantity")
	if quantityLabel then quantityLabel.Text = string.format("x%d", math.max(0, quantity)) end
end



function InventoryUIController:_updateEquipmentSlot(slot: GuiObject, equipmentEntry)
	local definitionId = tostring(equipmentEntry.definitionId or equipmentEntry.id or "")
	local def = EquipmentConfig.GetById(definitionId)
	local slotRoot = getTemplateRoot(slot, EQUIPMENT_SLOT_TEMPLATE_NAME)
	if not slotRoot or not def then return end
	self:_bindEquipmentSlot(slotRoot, equipmentEntry.name or def.name, definitionId)
	local remainingTimeText = findDirectTemplateText(slotRoot, "RemainingTimeText")
	if remainingTimeText then remainingTimeText.Text = formatRemainingLifetime(equipmentEntry) end
	local levelLabel = findDirectTemplateText(slotRoot, "Level")
	if levelLabel then levelLabel.Text = string.format("Lv.%d", math.max(1, equipmentEntry.level or 1)) end
	local equippedTag = findDirectTemplateText(slotRoot, "EquippedTag")
	if equippedTag then
		equippedTag.Visible = equipmentEntry.equipped == true
		equippedTag.Text = equipmentEntry.equippedSlot and ("Slot " .. tostring(equipmentEntry.equippedSlot)) or "Equipped"
	end
end

function InventoryUIController:_destroyMappedSlot(slot: GuiObject?)
	if not slot then return end
	self:_disconnectSlot(slot)
	if slot.Parent then slot:Destroy() end
end

function InventoryUIController:_reconcileSlots(data)
	local seenItems = {}
	for itemId, quantity in pairs(data.ownedItems or {}) do
		seenItems[itemId] = true
		local slot = self._itemSlotMap[itemId]
		if slot and slot.Parent then self:_updateItemSlot(slot, itemId, quantity) else self:_spawnItemSlot(itemId, quantity) end
	end
	for itemId, slot in pairs(self._itemSlotMap) do if not seenItems[itemId] then self._itemSlotMap[itemId] = nil; self:_destroyMappedSlot(slot) end end

	local seenEquipment = {}
	for _, equipmentEntry in ipairs(data.ownedEquipment or {}) do
		local instanceId = tostring(equipmentEntry.instanceId or "")
		if instanceId ~= "" then
			seenEquipment[instanceId] = true
			local slot = self._equipmentSlotMap[instanceId]
			if slot and slot.Parent then self:_updateEquipmentSlot(slot, equipmentEntry) else self:_spawnEquipmentSlot(equipmentEntry) end
		end
	end
	for equipmentId, slot in pairs(self._equipmentSlotMap) do if not seenEquipment[equipmentId] then self._equipmentSlotMap[equipmentId] = nil; self:_destroyMappedSlot(slot) end end
end

function InventoryUIController:_findEquipmentEntry(ownedEquipment, equipmentId)
	for _, entry in ipairs(ownedEquipment or {}) do if entry.instanceId == equipmentId or entry.id == equipmentId then return entry end end
	return nil
end

function InventoryUIController:_refreshEquipmentPanel(data)
	local equipmentId = data.selectedEquipmentId or self._selectedEquipmentId
	self._selectedEquipmentId = equipmentId
	local entry = equipmentId and self:_findEquipmentEntry(data.ownedEquipment, equipmentId) or nil
	local def = entry and EquipmentConfig.GetById(entry.definitionId or entry.id or "") or nil
	if self._equipmentSelectedName then self._equipmentSelectedName.Text = (entry and entry.name) or (def and def.name) or "No equipment selected" end
	local level = math.max(1, math.floor(tonumber(entry and entry.level) or 1))
	local nextLevel = level + 1
	if self._equipmentStatDamage then self._equipmentStatDamage.Text = "Ability: " .. tostring(def and def.effectId or "-") .. "  <font color='rgb(85,255,127)'>Next Lv." .. nextLevel .. "</font>"; self._equipmentStatDamage.RichText = true end
	if self._equipmentStatHP then self._equipmentStatHP.Text = "Level: " .. tostring(level) .. "  <font color='rgb(85,255,127)'>Lv." .. nextLevel .. "</font>"; self._equipmentStatHP.RichText = true end
	if self._equipmentStatRange then self._equipmentStatRange.Text = "Rarity: " .. tostring(def and def.rarity or "-") end
	if self._equipmentStatRegen then self._equipmentStatRegen.Text = entry and (entry.equipped and "Equipped" or "Unequipped") or "-" end
	if self._equipmentUpgradeButton then self._equipmentUpgradeButton.Text = string.format("Upgrade %d Diamonds", EquipmentUpgradeConfig.GetUpgradeCost(level)); self._equipmentUpgradeButton.Active = entry ~= nil end
end



function InventoryUIController:_refreshItemPanel(data)
	local itemId = data.selectedItemId or self._selectedItemId
	self._selectedItemId = itemId
	local itemDef = itemId and ItemConfig.GetById(itemId) or nil
	if self._itemSelectedName then
		self._itemSelectedName.Text = itemDef and itemDef.name or "No item selected"
	end
	if self._itemStat1 then
		local qty = itemId and (data.ownedItems[itemId] or 0) or 0
		self._itemStat1.Text = string.format("Quantity: %d", qty)
	end
	if self._itemStat2 then
		self._itemStat2.Text = itemDef and ("Type: " .. tostring(itemDef.type)) or "Type: -"
	end
	if self._itemStat3 then
		self._itemStat3.Text = data.lastUseResult or "Use: ready"
	end
end



function InventoryUIController:_refreshAllSlotVisuals()
	for itemId, slot in pairs(self._itemSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedItemId == itemId)
		end
	end
	for equipmentId, slot in pairs(self._equipmentSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedEquipmentId == equipmentId)
		end
	end
end

function InventoryUIController:RefreshWithData(data)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] RefreshWithData items=%s equipment=%s equippedEquipment=%s selectedEquipment=%s t=%.3f", tostring(type(data.ownedItems) == "table" and (function() local count = 0; for _ in pairs(data.ownedItems) do count += 1 end; return count end)() or "n/a"), tostring(type(data.ownedEquipment) == "table" and #data.ownedEquipment or "n/a"), tostring(type(data.equippedEquipment) == "table" and (function() local count = 0; for _ in pairs(data.equippedEquipment) do count += 1 end; return count end)() or "n/a"), tostring(data.selectedEquipmentId), os.clock())) end
	self._cachedSnapshot = data
	if self._inventoryGui and self._inventoryGui:IsA("ScreenGui") and not self._inventoryGui.Enabled then
		return
	end

	self:_reconcileSlots(data)

	if self._equipmentCapacityLabel then self._equipmentCapacityLabel.Text = string.format("Capacity: %d/%d | Equipped: %d/3", #(data.ownedEquipment or {}), data.equipmentCapacity or 0, (function() local count = 0; for _ in pairs(data.equippedEquipment or {}) do count += 1 end; return count end)()) end

	self:_refreshItemPanel(data)
	self:_refreshEquipmentPanel(data)
	self:_refreshAllSlotVisuals()
end

function InventoryUIController:Destroy()
	self:_clearGeneratedSlots()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return InventoryUIController
