--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

local NORMAL_COLOR = Color3.fromRGB(41, 43, 53)
local HOVER_COLOR = Color3.fromRGB(62, 66, 82)
local SELECTED_COLOR = Color3.fromRGB(88, 102, 132)
local ITEM_SLOT_TEMPLATE_NAME = "ItemSlotTemplate_InventoryUI"
local PET_SLOT_TEMPLATE_NAME = "PetSlotTemplate_InventoryUI"

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
	self._spawnedPetSlots = {}
	self._connections = {}
	self._activeTab = "Items"
	self._slotConnections = {}
	self._slotConnectionMap = {}
	self._itemSlotMap = {}
	self._petSlotMap = {}
	self._selectedItemId = nil
	self._selectedPetId = nil
	self._cachedSnapshot = nil
	return self
end

function InventoryUIController:SetDataProvider(provider)
	self._dataProvider = provider
end

function InventoryUIController:SetConfirmationController(controller)
	self._confirmationController = controller
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
	self._petBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyPets)
	self._petGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsGridContainer)
	self._itemsTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsTab)
	self._petTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsTab)
	self._closeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.CloseButton)
	self._petCapacityLabel = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsCapacityLabel)

	self._itemSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsSelectedName)
	self._itemStat1 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat1)
	self._itemStat2 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat2)
	self._itemStat3 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat3)
	self._itemUseButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsUseButton)

	self._petSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsSelectedName)
	self._petStatDamage = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsStatDamage)
	self._petStatHP = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsStatHP)
	self._petStatRange = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsStatRange)
	self._petStatRegeneration = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsStatRegeneration)
	self._petEquipButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsEquipButton)
	self._petDeleteButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsDeleteButton)
	self._petUpgradeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.PetsUpgradeButton)
	self._upgradePetRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.UpgradePet) :: RemoteEvent?

	local assets = ReplicatedStorage:WaitForChild("Assets")
	if not assets then
		warn("[INVENTORY_UI] ReplicatedStorage.Assets missing")
	else
		self._petAssets = assets:FindFirstChild("Pets")
		local uiFolder = assets:FindFirstChild("UI")
		if not uiFolder then
			warn("[INVENTORY_UI] ReplicatedStorage.Assets.UI missing")
		else
			self._itemTemplate = findUiTemplate(uiFolder, ITEM_SLOT_TEMPLATE_NAME, nil)
			self._petTemplate = findUiTemplate(uiFolder, PET_SLOT_TEMPLATE_NAME, nil)
			if not self._itemTemplate then
				warn("[INVENTORY_UI] " .. ITEM_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
			if not self._petTemplate then
				warn("[INVENTORY_UI] " .. PET_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
			end
		end
	end
	if not self._petAssets then warn("[INVENTORY_UI] ReplicatedStorage.Assets.Pets missing") end

	if not self._inventoryGui then warn("[INVENTORY_UI] InventoryUI ScreenGui missing") end
	if not self._itemsGrid then warn("[INVENTORY_UI] Items grid container missing") end
	if not self._itemsBody then warn("[INVENTORY_UI] Items body frame missing") end
	if not self._petBody then warn("[INVENTORY_UI] BodyPets missing at StarterGui/InventoryUI/Root/BodyPets") end
	if not self._petGrid then warn("[INVENTORY_UI] GridContainer missing at StarterGui/InventoryUI/Root/BodyPets/GridContainer") end
	if not self._itemsTab then warn("[INVENTORY_UI] ItemsTab button missing") end
	if not self._closeButton then warn("[INVENTORY_UI] CloseButton missing") end

	if self._itemsTab then
		table.insert(self._connections, self._itemsTab.MouseButton1Click:Connect(function()
			self:SetActiveTab("Items")
		end))
	end
	if self._petTab then
		table.insert(self._connections, self._petTab.MouseButton1Click:Connect(function() self:SetActiveTab("Pet") end))
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
	if self._petEquipButton then table.insert(self._connections, self._petEquipButton.MouseButton1Click:Connect(function() if self._dataProvider then self._dataProvider:EquipSelectedPet() end end)) end
	if self._petDeleteButton then table.insert(self._connections, self._petDeleteButton.MouseButton1Click:Connect(function() if self._dataProvider then self._dataProvider:UnequipSelectedPet() end end)) end
	if self._petUpgradeButton then
		table.insert(self._connections, self._petUpgradeButton.MouseButton1Click:Connect(function()
			local petId = self._selectedPetId
			if not petId or not self._upgradePetRemote then
				return
			end
			if not self._confirmationController then
				warn("[INVENTORY_UI] ConfirmationUIController is required before upgrading pet")
				return
			end
			self._confirmationController:RequestConfirm("Upgrade this pet?", function()
				self._upgradePetRemote:FireServer(petId)
			end)
		end))
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
	self._activeTab = if tabName == "Pet" then "Pet" else "Items"
	if self._itemsBody then
		self._itemsBody.Visible = self._activeTab == "Items"
	end
	if self._petBody then self._petBody.Visible = self._activeTab == "Pet" end
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
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] clearGeneratedSlots items=%d pet=%d slotConnections=%d t=%.3f", #self._spawnedItemSlots, #self._spawnedPetSlots, #self._slotConnections, os.clock())) end
	if self._itemsGrid then
		for _, child in ipairs(self._itemsGrid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	if self._petGrid then
		for _, child in ipairs(self._petGrid:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	end
	for _, slot in ipairs(self._spawnedItemSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self._spawnedItemSlots)
	table.clear(self._spawnedPetSlots)
	table.clear(self._itemSlotMap)
	table.clear(self._petSlotMap)
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

function InventoryUIController:_populatePetPreview(slotRoot: Instance, definition: PetsConfig.PetDefinition)
	local preview = slotRoot:FindFirstChild("PetPreview", true)
	if preview and preview:IsA("ViewportFrame") then
		PreviewRenderer.Populate(preview, self._petAssets, definition.Name)
	else
		warn("[INVENTORY_UI] Pet slot is missing PetPreview ViewportFrame")
	end
end

function InventoryUIController:_bindPetSlot(slotRoot: Instance, displayName: string, definition: PetsConfig.PetDefinition)
	local nameLabel = findDirectTemplateText(slotRoot, "Name")
	if nameLabel then
		nameLabel.Text = displayName
	end
	self:_populatePetPreview(slotRoot, definition)
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
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Pet" and self._selectedPetId == id)
		self:_applySlotVisual(slot, hoverState, selected)
	end))
	track(clickTarget.MouseLeave:Connect(function()
		hoverState = false
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Pet" and self._selectedPetId == id)
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
		elseif listType == "Pet" then
			self._selectedPetId = id
			if self._dataProvider then self._dataProvider:SelectPet(id) end
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

function InventoryUIController:_spawnPetSlot(petEntry)
	if not self._petGrid then warn("[INVENTORY_UI] Cannot spawn pet: GridContainer missing at StarterGui/InventoryUI/Root/BodyPets/GridContainer"); return end
	if not self._petTemplate or not self._petTemplate:IsA("GuiObject") then warn("[INVENTORY_UI] Cannot spawn pet: template missing at ReplicatedStorage/Assets/UI/PetSlotTemplate_InventoryUI"); return end
	local instanceId = tostring(petEntry.instanceId or "")
	local definitionId = tostring(petEntry.definitionId or petEntry.id or "")
	if instanceId == "" or definitionId == "" then return end
	local def = PetsConfig.GetById(definitionId)
	if not def then warn(string.format("[INVENTORY_UI] Unknown pet definition id in owned data: %s", definitionId)); return end
	local slot = self._petTemplate:Clone()
	local slotRoot = getTemplateRoot(slot, PET_SLOT_TEMPLATE_NAME)
	if not slotRoot then slot:Destroy(); return end
	slot.Name = string.format("GeneratedPet_%s", instanceId)
	slot.Visible = true
	slot.Parent = self._petGrid
	self:_bindPetSlot(slotRoot, def.DisplayName, def)
	local remainingTimeText = findDirectTemplateText(slotRoot, "RemainingTimeText")
	if remainingTimeText then remainingTimeText.Text = formatRemainingLifetime(petEntry) end
	local levelLabel = findDirectTemplateText(slotRoot, "Level")
	if levelLabel then levelLabel.Text = string.format("Lv.%d", math.max(1, petEntry.level or 1)) end
	local equippedTag = findDirectTemplateText(slotRoot, "EquippedTag")
	if equippedTag then
		equippedTag.Visible = petEntry.equipped == true
		equippedTag.Text = petEntry.equippedSlot and ("Slot " .. tostring(petEntry.equippedSlot)) or "Equipped"
	end
	self._petSlotMap[instanceId] = slot
	self:_bindSlotState(slot, "Pet", instanceId)
	table.insert(self._spawnedPetSlots, slot)
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



function InventoryUIController:_updatePetSlot(slot: GuiObject, petEntry)
	local definitionId = tostring(petEntry.definitionId or petEntry.id or "")
	local def = PetsConfig.GetById(definitionId)
	local slotRoot = getTemplateRoot(slot, PET_SLOT_TEMPLATE_NAME)
	if not slotRoot or not def then return end
	self:_bindPetSlot(slotRoot, def.DisplayName, def)
	local remainingTimeText = findDirectTemplateText(slotRoot, "RemainingTimeText")
	if remainingTimeText then remainingTimeText.Text = formatRemainingLifetime(petEntry) end
	local levelLabel = findDirectTemplateText(slotRoot, "Level")
	if levelLabel then levelLabel.Text = string.format("Lv.%d", math.max(1, petEntry.level or 1)) end
	local equippedTag = findDirectTemplateText(slotRoot, "EquippedTag")
	if equippedTag then
		equippedTag.Visible = petEntry.equipped == true
		equippedTag.Text = petEntry.equippedSlot and ("Slot " .. tostring(petEntry.equippedSlot)) or "Equipped"
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

	local seenPet = {}
	for _, petEntry in ipairs(data.ownedPets or {}) do
		local instanceId = tostring(petEntry.instanceId or "")
		if instanceId ~= "" then
			seenPet[instanceId] = true
			local slot = self._petSlotMap[instanceId]
			if slot and slot.Parent then self:_updatePetSlot(slot, petEntry) else self:_spawnPetSlot(petEntry) end
		end
	end
	for petId, slot in pairs(self._petSlotMap) do if not seenPet[petId] then self._petSlotMap[petId] = nil; self:_destroyMappedSlot(slot) end end
end

function InventoryUIController:_findPetEntry(ownedPets, petId)
	for _, entry in ipairs(ownedPets or {}) do if entry.instanceId == petId or entry.id == petId then return entry end end
	return nil
end

function InventoryUIController:_refreshPetPanel(data)
	local petId = data.selectedPetId or self._selectedPetId
	self._selectedPetId = petId
	local entry = petId and self:_findPetEntry(data.ownedPets, petId) or nil
	local def = entry and PetsConfig.GetById(entry.definitionId or entry.id or "") or nil
	if self._petSelectedName then self._petSelectedName.Text = (def and def.DisplayName) or "No pet selected" end
	local level = math.max(1, math.floor(tonumber(entry and entry.level) or 1))
	local nextLevel = level + 1
	local modifiers = def and def.statModifiers or nil
	local additiveStats = modifiers and modifiers.Add or nil
	local multiplierStats = modifiers and modifiers.Multiply or nil

	local function formatStat(label: string, statName: string, fallbackMultiplierStatName: string?): string
		local baseValue = additiveStats and additiveStats[statName]
		local isMultiplier = false
		if type(baseValue) ~= "number" and fallbackMultiplierStatName then
			baseValue = multiplierStats and multiplierStats[fallbackMultiplierStatName]
			isMultiplier = true
		end
		if type(baseValue) ~= "number" then
			return label .. ": -"
		end
		local currentValue = PetsUpgradeConfig.GetStatAtLevel(baseValue, level)
		local nextValue = PetsUpgradeConfig.GetStatAtLevel(baseValue, nextLevel)
		local prefix = if isMultiplier then "x" else ""
		return string.format("%s: %s%.2f <font color=\"#00ff00\">➔ %s%.2f</font>", label, prefix, currentValue, prefix, nextValue)
	end

	if self._petStatDamage then self._petStatDamage.Text = formatStat("Damage", "baseDamage", "damageMultiplier") ; self._petStatDamage.RichText = true end
	if self._petStatHP then self._petStatHP.Text = formatStat("HP", "maxHP") ; self._petStatHP.RichText = true end
	if self._petStatRange then self._petStatRange.Text = formatStat("Range", "launchRange", "launchSpeed") ; self._petStatRange.RichText = true end
	if self._petStatRegeneration then self._petStatRegeneration.Text = formatStat("Regeneration", "regen") ; self._petStatRegeneration.RichText = true end
	if self._petEquipButton then
		self._petEquipButton.Text = if entry and entry.equipped then "Unequip" else "Equip"
		self._petEquipButton.Active = entry ~= nil
	end
	if self._petUpgradeButton then self._petUpgradeButton.Text = string.format("Upgrade %d Diamonds", PetsUpgradeConfig.GetUpgradeCost(level)); self._petUpgradeButton.Active = entry ~= nil end
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
	for petId, slot in pairs(self._petSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedPetId == petId)
		end
	end
end

function InventoryUIController:RefreshWithData(data)
	if DebugConfig.VerboseTrace then print(string.format("[DIAG][InventoryUI] RefreshWithData items=%s pet=%s equippedPets=%s selectedPet=%s t=%.3f", tostring(type(data.ownedItems) == "table" and (function() local count = 0; for _ in pairs(data.ownedItems) do count += 1 end; return count end)() or "n/a"), tostring(type(data.ownedPets) == "table" and #data.ownedPets or "n/a"), tostring(type(data.equippedPets) == "table" and (function() local count = 0; for _ in pairs(data.equippedPets) do count += 1 end; return count end)() or "n/a"), tostring(data.selectedPetId), os.clock())) end
	self._cachedSnapshot = data
	if self._inventoryGui and self._inventoryGui:IsA("ScreenGui") and not self._inventoryGui.Enabled then
		return
	end

	self:_reconcileSlots(data)

	if self._petCapacityLabel then self._petCapacityLabel.Text = string.format("Capacity: %d/%d | Equipped: %d/3", #(data.ownedPets or {}), data.petCapacity or 0, (function() local count = 0; for _ in pairs(data.equippedPets or {}) do count += 1 end; return count end)()) end

	self:_refreshItemPanel(data)
	self:_refreshPetPanel(data)
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
