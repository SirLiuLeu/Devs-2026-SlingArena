--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

local NORMAL_COLOR = Color3.fromRGB(41, 43, 53)
local HOVER_COLOR = Color3.fromRGB(62, 66, 82)
local SELECTED_COLOR = Color3.fromRGB(88, 102, 132)
local EQUIPPED_LAUNCHER_MODEL_NAME = "EquippedLauncherModel"
local TYPO_EQUIPPED_LAUNCHER_MODEL_NAME = "EquipedLauncherModel"
local LAUNCHER_ROOT_PART_NAME = "RootPart"
local HITBOX_ROOT_WELD_NAME = "WeldConstraint_HitboxRootPart"
local LEGACY_HITBOX_MESH_WELD_NAME = "WeldConstraint_HitboxMesh"
local ITEM_SLOT_TEMPLATE_NAME = "ItemSlotTemplate_InventoryUI"
local LAUNCHER_SLOT_TEMPLATE_NAME = "LauncherSlotTemplate_InventoryUI"
local LEGACY_LAUNCHER_SLOT_TEMPLATE_NAME = "LaunchersSlotTemplate_InventoryUI"
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
	self._spawnedLauncherSlots = {}
	self._spawnedEquipmentSlots = {}
	self._connections = {}
	self._activeTab = "Items"
	self._slotConnections = {}
	self._slotConnectionMap = {}
	self._itemSlotMap = {}
	self._launcherSlotMap = {}
	self._equipmentSlotMap = {}
	self._selectedItemId = nil
	self._selectedLauncherId = nil
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
	self._launchersGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.LaunchersGridContainer)
	self._itemsBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyItems)
	self._launcherBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyLauncher)
	self._equipmentBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyEquipment)
	self._equipmentGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentGridContainer)
	self._itemsTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsTab)
	self._launcherTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherTab)
	self._equipmentTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.EquipmentTab)
	self._closeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.CloseButton)
	self._launcherCapacityLabel = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherCapacityLabel)
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
	self._launcherSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherSelectedName)
	self._launcherStatDamage = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherStatDamage)
	self._launcherStatHP = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherStatHP)
	self._launcherStatRange = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherStatRange)
	self._launcherStatRegen = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherStatRegen)
	self._launcherEquipButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherEquipButton)
	self._launcherDeleteButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.LauncherDeleteButton)

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
			self._launcherTemplate = findUiTemplate(uiFolder, LAUNCHER_SLOT_TEMPLATE_NAME, LEGACY_LAUNCHER_SLOT_TEMPLATE_NAME)
			self._equipmentTemplate = findUiTemplate(uiFolder, EQUIPMENT_SLOT_TEMPLATE_NAME, nil)
			if not self._itemTemplate then
				warn("[INVENTORY_UI] " .. ITEM_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
			if not self._launcherTemplate then
				warn("[INVENTORY_UI] " .. LAUNCHER_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
			if not self._equipmentTemplate then
				warn("[INVENTORY_UI] " .. EQUIPMENT_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
		end
	end
	if not self._equipmentAssets then warn("[INVENTORY_UI] ReplicatedStorage.Assets.Equipment missing") end

	if not self._inventoryGui then warn("[INVENTORY_UI] InventoryUI ScreenGui missing") end
	if not self._itemsGrid then warn("[INVENTORY_UI] Items grid container missing") end
	if not self._launchersGrid then warn("[INVENTORY_UI] Launchers grid container missing") end
	if not self._itemsBody then warn("[INVENTORY_UI] Items body frame missing") end
	if not self._launcherBody then warn("[INVENTORY_UI] Launcher body frame missing") end
	if not self._equipmentBody then warn("[INVENTORY_UI] BodyEquipment missing at StarterGui/InventoryUI/Root/BodyEquipment") end
	if not self._equipmentGrid then warn("[INVENTORY_UI] GridContainer missing at StarterGui/InventoryUI/Root/BodyEquipment/GridContainer") end
	if not self._itemsTab then warn("[INVENTORY_UI] ItemsTab button missing") end
	if not self._launcherTab then warn("[INVENTORY_UI] LauncherTab button missing") end
	if not self._closeButton then warn("[INVENTORY_UI] CloseButton missing") end

	if self._itemsTab then
		table.insert(self._connections, self._itemsTab.MouseButton1Click:Connect(function()
			self:SetActiveTab("Items")
		end))
	end
	if self._launcherTab then
		table.insert(self._connections, self._launcherTab.MouseButton1Click:Connect(function() self:SetActiveTab("Launcher") end))
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
	if self._launcherEquipButton then
		table.insert(self._connections, self._launcherEquipButton.MouseButton1Click:Connect(function()
			if self._dataProvider then
				self._dataProvider:EquipSelectedLauncher()
			end
		end))
	else
		warn("[INVENTORY_UI] " .. ProjectTreeSpec.UI.Inventory.LauncherEquipButton .. " missing")
	end
	if self._equipmentEquipButton then table.insert(self._connections, self._equipmentEquipButton.MouseButton1Click:Connect(function() if self._dataProvider then self._dataProvider:EquipSelectedEquipment() end end)) end
	if self._equipmentDeleteButton then table.insert(self._connections, self._equipmentDeleteButton.MouseButton1Click:Connect(function() if self._dataProvider then self._dataProvider:UnequipSelectedEquipment() end end)) end
	if self._launcherDeleteButton then
		table.insert(self._connections, self._launcherDeleteButton.MouseButton1Click:Connect(function()
			if self._dataProvider then
				self._dataProvider:UnequipSelectedLauncher()
			end
		end))
	else
		warn("[INVENTORY_UI] " .. ProjectTreeSpec.UI.Inventory.LauncherDeleteButton .. " missing")
	end

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
	self._activeTab = if tabName == "Launcher" then "Launcher" elseif tabName == "Equipment" then "Equipment" else "Items"
	if self._itemsBody then
		self._itemsBody.Visible = self._activeTab == "Items"
	end
	if self._launcherBody then
		self._launcherBody.Visible = self._activeTab == "Launcher"
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
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] clearGeneratedSlots items=%d launchers=%d equipment=%d slotConnections=%d t=%.3f", #self._spawnedItemSlots, #self._spawnedLauncherSlots, #self._spawnedEquipmentSlots, #self._slotConnections, os.clock())) end
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
	if self._launchersGrid then
		for _, child in ipairs(self._launchersGrid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	for _, slot in ipairs(self._spawnedItemSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	for _, slot in ipairs(self._spawnedLauncherSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self._spawnedItemSlots)
	table.clear(self._spawnedLauncherSlots)
	table.clear(self._spawnedEquipmentSlots)
	table.clear(self._itemSlotMap)
	table.clear(self._launcherSlotMap)
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
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Launcher" and self._selectedLauncherId == id) or (listType == "Equipment" and self._selectedEquipmentId == id)
		self:_applySlotVisual(slot, hoverState, selected)
	end))
	track(clickTarget.MouseLeave:Connect(function()
		hoverState = false
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Launcher" and self._selectedLauncherId == id) or (listType == "Equipment" and self._selectedEquipmentId == id)
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
		elseif listType == "Launcher" then
			self._selectedLauncherId = id
			if self._dataProvider then self._dataProvider:SelectLauncher(id) end
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

function InventoryUIController:_spawnLauncherSlot(launcherEntry)
	if not self._launchersGrid or not self._launcherTemplate or not self._launcherTemplate:IsA("GuiObject") then
		return
	end
	local launcherId = launcherEntry.id
	local level = launcherEntry.level or 1
	local isEquipped = launcherEntry.equipped == true
	local launcherDef = LauncherConfig.GetById(launcherId)
	if not launcherDef then
		warn(string.format("[INVENTORY_UI] Unknown launcher id in owned data: %s", launcherId))
		return
	end

	local slot = self._launcherTemplate:Clone()
	local slotRoot = getTemplateRoot(slot, LAUNCHER_SLOT_TEMPLATE_NAME)
	if not slotRoot then
		slot:Destroy()
		return
	end
	slot.Name = string.format("GeneratedLauncher_%s", launcherId)
	slot.Visible = true
	slot.Parent = self._launchersGrid
	self:_bindCommonSlot(slotRoot, launcherEntry.name or launcherDef.name, launcherEntry.icon or launcherDef.icon)

	local levelLabel = findDirectTemplateText(slotRoot, "Level")
	if levelLabel then
		local stats = launcherEntry.stats
		if type(stats) == "table" then
			levelLabel.Text = string.format("Lv.%d | Dmg %.1f | HP %.0f", math.max(1, level), stats.damage or 0, stats.hp or 0)
		else
			levelLabel.Text = string.format("Lv.%d", math.max(1, level))
		end
	end

	local equippedTag = findDirectTemplateText(slotRoot, "EquippedTag")
	if equippedTag then
		equippedTag.Visible = isEquipped
	end

	local stars = slotRoot:FindFirstChild("Stars")
	if stars and stars:IsA("GuiObject") then
		local filledStars = math.clamp(math.floor(level), 1, 5)
		for starIndex = 1, 5 do
			local star = stars:FindFirstChild("Star" .. starIndex)
			if star and star:IsA("ImageLabel") then
				star.Visible = starIndex <= filledStars
			end
		end
	end

	self._launcherSlotMap[launcherId] = slot
	self:_bindSlotState(slot, "Launcher", launcherId)
	table.insert(self._spawnedLauncherSlots, slot)
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

function InventoryUIController:_updateLauncherSlot(slot: GuiObject, launcherEntry)
	local slotRoot = getTemplateRoot(slot, LAUNCHER_SLOT_TEMPLATE_NAME)
	local launcherDef = LauncherConfig.GetById(launcherEntry.id)
	if not slotRoot or not launcherDef then return end
	self:_bindCommonSlot(slotRoot, launcherEntry.name or launcherDef.name, launcherEntry.icon or launcherDef.icon)
	local levelLabel = findDirectTemplateText(slotRoot, "Level")
	if levelLabel then
		local stats = launcherEntry.stats
		if type(stats) == "table" then
			levelLabel.Text = string.format("Lv.%d | Dmg %.1f | HP %.0f", math.max(1, launcherEntry.level or 1), stats.damage or 0, stats.hp or 0)
		else
			levelLabel.Text = string.format("Lv.%d", math.max(1, launcherEntry.level or 1))
		end
	end
	local equippedTag = findDirectTemplateText(slotRoot, "EquippedTag")
	if equippedTag then equippedTag.Visible = launcherEntry.equipped == true end
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

	local seenLaunchers = {}
	for _, launcherEntry in ipairs(data.ownedLaunchers or {}) do
		local launcherId = launcherEntry.id
		seenLaunchers[launcherId] = true
		local slot = self._launcherSlotMap[launcherId]
		if slot and slot.Parent then self:_updateLauncherSlot(slot, launcherEntry) else self:_spawnLauncherSlot(launcherEntry) end
	end
	for launcherId, slot in pairs(self._launcherSlotMap) do if not seenLaunchers[launcherId] then self._launcherSlotMap[launcherId] = nil; self:_destroyMappedSlot(slot) end end

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
	if self._equipmentStatDamage then self._equipmentStatDamage.Text = "Ability: " .. tostring(def and def.effectId or "-") end
	if self._equipmentStatHP then self._equipmentStatHP.Text = "Level: " .. tostring(entry and entry.level or "-") end
	if self._equipmentStatRange then self._equipmentStatRange.Text = "Rarity: " .. tostring(def and def.rarity or "-") end
	if self._equipmentStatRegen then self._equipmentStatRegen.Text = entry and (entry.equipped and "Equipped" or "Unequipped") or "-" end
end

function InventoryUIController:_findLauncherEntry(ownedLaunchers, launcherId)
	for _, launcherEntry in ipairs(ownedLaunchers) do
		if launcherEntry.id == launcherId then
			return launcherEntry
		end
	end
	return nil
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

function InventoryUIController:_refreshLauncherPanel(data)
	local launcherId = data.selectedLauncherId or self._selectedLauncherId
	self._selectedLauncherId = launcherId
	local launcherDef = launcherId and LauncherConfig.GetById(launcherId) or nil
	local launcherEntry = launcherId and self:_findLauncherEntry(data.ownedLaunchers, launcherId) or nil

	if self._launcherSelectedName then
		self._launcherSelectedName.Text = (launcherEntry and launcherEntry.name) or (launcherDef and launcherDef.name) or "No launcher selected"
	end
	if self._launcherStatDamage then
		local value = launcherEntry and launcherEntry.stats and launcherEntry.stats.damage
		self._launcherStatDamage.Text = string.format("Power: %.2f", value or (launcherDef and launcherDef.stats.launchPower or 0))
	end
	if self._launcherStatHP then
		local hpValue = launcherEntry and launcherEntry.stats and launcherEntry.stats.hp
		self._launcherStatHP.Text = hpValue and string.format("HP: %.0f", hpValue) or (launcherEntry and string.format("Level: %d", launcherEntry.level or 1) or "Level: -")
	end
	if self._launcherStatRange then
		local rangeValue = launcherEntry and launcherEntry.stats and launcherEntry.stats.range
		self._launcherStatRange.Text = string.format("Range: %.2f", rangeValue or (launcherDef and launcherDef.stats.control or 0))
	end
	if self._launcherStatRegen then
		local regenValue = launcherEntry and launcherEntry.stats and launcherEntry.stats.regen
		local isEquipped = launcherEntry and launcherEntry.equipped == true
		self._launcherStatRegen.Text = string.format("Regen: %.2f | %s", regenValue or 0, isEquipped and "Equipped" or "Unequipped")
	end
end

function InventoryUIController:_refreshAllSlotVisuals()
	for itemId, slot in pairs(self._itemSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedItemId == itemId)
		end
	end
	for launcherId, slot in pairs(self._launcherSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedLauncherId == launcherId)
		end
	end
	for equipmentId, slot in pairs(self._equipmentSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedEquipmentId == equipmentId)
		end
	end
end

function InventoryUIController:_resolveLauncherModelSource(launcherId: string): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder then
		local assetsLauncher = assetsFolder:FindFirstChild("Launcher")
		if assetsLauncher then
			local model = assetsLauncher:FindFirstChild(launcherId)
			if model and model:IsA("Model") then
				return model
			end
		end
		local assetsLaunchers = assetsFolder:FindFirstChild("Launchers")
		if assetsLaunchers then
			local model = assetsLaunchers:FindFirstChild(launcherId)
			if model and model:IsA("Model") then
				return model
			end
		end
	end

	local launchersFolder = ReplicatedStorage:FindFirstChild("Launchers")
	if launchersFolder then
		local model = launchersFolder:FindFirstChild(launcherId)
		if model and model:IsA("Model") then
			return model
		end
	end

	warn(string.format("[INVENTORY_UI] Launcher model missing for %s in ReplicatedStorage/Assets/Launchers", launcherId))
	return nil
end

function InventoryUIController:_findEquippedLauncherModel(pawn: Model): Model?
	local direct = pawn:FindFirstChild(EQUIPPED_LAUNCHER_MODEL_NAME)
	if direct and direct:IsA("Model") then
		return direct
	end

	local legacy = pawn:FindFirstChild(TYPO_EQUIPPED_LAUNCHER_MODEL_NAME)
	if legacy and legacy:IsA("Model") then
		legacy.Name = EQUIPPED_LAUNCHER_MODEL_NAME
		return legacy
	end

	return nil
end

function InventoryUIController:_cloneEquippedLauncherModel(pawn: Model, modelTemplate: Model): Model
	local existingModel = self:_findEquippedLauncherModel(pawn)
	if existingModel then
		existingModel:Destroy()
	end

	local equippedModel = modelTemplate:Clone()
	equippedModel.Name = EQUIPPED_LAUNCHER_MODEL_NAME
	equippedModel.Parent = pawn
	return equippedModel
end

function InventoryUIController:_resolveLauncherVisualRoot(model: Model): BasePart?
	local rootPart = model:FindFirstChild(LAUNCHER_ROOT_PART_NAME)
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return nil
end

function InventoryUIController:_configureVisualRig(rig: Model)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

function InventoryUIController:_validateLauncherMotor6Ds(rig: Model, launcherId: string): boolean
	local isValid = true
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if not (part0 and part0:IsDescendantOf(rig)) then
				isValid = false
				warn(string.format("[INVENTORY_UI] Launcher %s Motor6D %s has invalid Part0 after cloning", launcherId, descendant:GetFullName()))
			end
			if not (part1 and part1:IsDescendantOf(rig)) then
				isValid = false
				warn(string.format("[INVENTORY_UI] Launcher %s Motor6D %s has invalid Part1 after cloning", launcherId, descendant:GetFullName()))
			end
		end
	end
	return isValid
end

function InventoryUIController:_updateHitboxRootPartWeld(pawn: Model, hitbox: BasePart, visualRoot: BasePart)
	local legacyWeld = pawn:FindFirstChild(LEGACY_HITBOX_MESH_WELD_NAME)
	if legacyWeld then
		legacyWeld:Destroy()
	end

	local weld = pawn:FindFirstChild(HITBOX_ROOT_WELD_NAME)
	if not (weld and weld:IsA("WeldConstraint")) then
		if weld then
			weld:Destroy()
		end
		weld = Instance.new("WeldConstraint")
		weld.Name = HITBOX_ROOT_WELD_NAME
		weld.Parent = pawn
	end
	weld.Part0 = hitbox
	weld.Part1 = visualRoot
end

function InventoryUIController:_applyEquippedLauncherModel(launcherId: string)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] applyEquippedLauncherModel launcherId=%s t=%.3f", tostring(launcherId), os.clock())) end
	local modelTemplate = self:_resolveLauncherModelSource(launcherId)
	if not modelTemplate then
		return
	end
	local pawn = PawnLocator.GetLocalPawn()
	if not pawn then
		warn("[INVENTORY_UI] Launcher pawn missing while equipping launcher")
		return
	end
	local root = PawnLocator.GetRootPart(pawn)
	if not root or not root:IsA("BasePart") then
		warn("[INVENTORY_UI] Launcher pawn root (Hitbox/PrimaryPart) missing while equipping launcher")
		return
	end

	local sourceRoot = self:_resolveLauncherVisualRoot(modelTemplate)
	if not sourceRoot then
		warn(string.format("[INVENTORY_UI] Launcher model %s has no RootPart/PrimaryPart", launcherId))
		return
	end

	local existingModel = self:_findEquippedLauncherModel(pawn)
	local oldRoot = existingModel and (existingModel.PrimaryPart or existingModel:FindFirstChild(LAUNCHER_ROOT_PART_NAME))
	local targetCFrame = if oldRoot and oldRoot:IsA("BasePart") then oldRoot.CFrame else root.CFrame
	local equippedModel = self:_cloneEquippedLauncherModel(pawn, modelTemplate)
	local visualRoot = self:_resolveLauncherVisualRoot(equippedModel)
	if not visualRoot then
		warn(string.format("[INVENTORY_UI] Cloned launcher model %s has no RootPart/PrimaryPart", launcherId))
		return
	end
	visualRoot.Name = LAUNCHER_ROOT_PART_NAME
	equippedModel.PrimaryPart = visualRoot
	equippedModel:PivotTo(targetCFrame)
	self:_configureVisualRig(equippedModel)
	self:_validateLauncherMotor6Ds(equippedModel, launcherId)
	equippedModel:SetAttribute("LauncherId", launcherId)
	pawn:SetAttribute("LauncherId", launcherId)
	self:_updateHitboxRootPartWeld(pawn, root, visualRoot)
end

function InventoryUIController:RefreshWithData(data)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] RefreshWithData items=%s launchers=%s equipment=%s equippedEquipment=%s selectedEquipment=%s t=%.3f", tostring(type(data.ownedItems) == "table" and (function() local count = 0; for _ in pairs(data.ownedItems) do count += 1 end; return count end)() or "n/a"), tostring(type(data.ownedLaunchers) == "table" and #data.ownedLaunchers or "n/a"), tostring(type(data.ownedEquipment) == "table" and #data.ownedEquipment or "n/a"), tostring(type(data.equippedEquipment) == "table" and (function() local count = 0; for _ in pairs(data.equippedEquipment) do count += 1 end; return count end)() or "n/a"), tostring(data.selectedEquipmentId), os.clock())) end
	self._cachedSnapshot = data
	if self._inventoryGui and self._inventoryGui:IsA("ScreenGui") and not self._inventoryGui.Enabled then
		return
	end

	self:_reconcileSlots(data)

	local ownedLaunchers = data.ownedLaunchers or {}
	if self._equipmentCapacityLabel then self._equipmentCapacityLabel.Text = string.format("Capacity: %d/%d | Equipped: %d/3", #(data.ownedEquipment or {}), data.equipmentCapacity or 0, (function() local count = 0; for _ in pairs(data.equippedEquipment or {}) do count += 1 end; return count end)()) end
	if self._launcherCapacityLabel then
		self._launcherCapacityLabel.Text = string.format("Capacity: %d/%d", #ownedLaunchers, data.launcherCapacity or 0)
	end

	self:_refreshItemPanel(data)
	self:_refreshLauncherPanel(data)
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
