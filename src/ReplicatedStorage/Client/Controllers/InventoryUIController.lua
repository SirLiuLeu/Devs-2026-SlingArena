--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

local NORMAL_COLOR = Color3.fromRGB(41, 43, 53)
local HOVER_COLOR = Color3.fromRGB(62, 66, 82)
local SELECTED_COLOR = Color3.fromRGB(88, 102, 132)

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

local function resolveImageLabel(root: Instance, path: string): ImageLabel?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("ImageLabel") then
		return value
	end
	return nil
end

function InventoryUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, InventoryUIController)
	self._playerGui = playerGui
	self._spawnedItemSlots = {}
	self._spawnedSlingSlots = {}
	self._connections = {}
	self._activeTab = "Items"
	self._slotConnections = {}
	self._itemSlotMap = {}
	self._slingSlotMap = {}
	self._selectedItemId = nil
	self._selectedSlingId = nil
	self._cachedSnapshot = nil
	return self
end

function InventoryUIController:SetDataProvider(provider)
	self._dataProvider = provider
end

function InventoryUIController:Start()
	self._inventoryGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Inventory.ScreenGui)
	self._itemsGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsGridContainer)
	self._slingsGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingsGridContainer)
	self._itemsBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodyItems)
	self._slingBody = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.BodySling)
	self._itemsTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsTab)
	self._slingTab = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingTab)
	self._closeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.CloseButton)
	self._slingCapacityLabel = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingCapacityLabel)

	self._itemSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsSelectedName)
	self._itemDescription = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsDescription)
	self._itemPanelIcon = resolveImageLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsPanelIcon)
	self._itemStat1 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat1)
	self._itemStat2 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat2)
	self._itemStat3 = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsStat3)
	self._itemUseButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsUseButton)

	self._slingSelectedName = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingSelectedName)
	self._slingPanelIcon = resolveImageLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingPanelIcon)
	self._slingStatDamage = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingStatDamage)
	self._slingStatHP = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingStatHP)
	self._slingStatRange = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingStatRange)
	self._slingStatRegen = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingStatRegen)
	self._slingEquipButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingEquipButton)
	self._slingDeleteButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingDeleteButton)

	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	if not assets then
		warn("[INVENTORY_UI] ReplicatedStorage.Assets missing")
	else
		local uiFolder = assets:FindFirstChild("UI")
		if not uiFolder then
			warn("[INVENTORY_UI] ReplicatedStorage.Assets.UI missing")
		else
			self._itemTemplate = uiFolder:FindFirstChild("ItemSlotTemplate")
			self._slingTemplate = uiFolder:FindFirstChild("SlingsSlotTemplate")
			if not self._itemTemplate then
				warn("[INVENTORY_UI] ItemSlotTemplate missing in ReplicatedStorage.Assets.UI")
			end
			if not self._slingTemplate then
				warn("[INVENTORY_UI] SlingsSlotTemplate missing in ReplicatedStorage.Assets.UI")
			end
		end
	end

	if not self._inventoryGui then warn("[INVENTORY_UI] InventoryUI ScreenGui missing") end
	if not self._itemsGrid then warn("[INVENTORY_UI] Items grid container missing") end
	if not self._slingsGrid then warn("[INVENTORY_UI] Slings grid container missing") end
	if not self._itemsBody then warn("[INVENTORY_UI] Items body frame missing") end
	if not self._slingBody then warn("[INVENTORY_UI] Sling body frame missing") end
	if not self._itemsTab then warn("[INVENTORY_UI] ItemsTab button missing") end
	if not self._slingTab then warn("[INVENTORY_UI] SlingTab button missing") end
	if not self._closeButton then warn("[INVENTORY_UI] CloseButton missing") end

	if self._itemsTab then
		table.insert(self._connections, self._itemsTab.MouseButton1Click:Connect(function()
			self:SetActiveTab("Items")
		end))
	end
	if self._slingTab then
		table.insert(self._connections, self._slingTab.MouseButton1Click:Connect(function()
			self:SetActiveTab("Sling")
		end))
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
	if self._slingEquipButton then
		table.insert(self._connections, self._slingEquipButton.MouseButton1Click:Connect(function()
			if self._dataProvider and self._dataProvider:EquipSelectedSling() and self._selectedSlingId then
				self:_applyEquippedSlingModel(self._selectedSlingId)
			end
		end))
	else
		warn("[INVENTORY_UI] " .. ProjectTreeSpec.UI.Inventory.SlingEquipButton .. " missing")
	end
	if self._slingDeleteButton then
		table.insert(self._connections, self._slingDeleteButton.MouseButton1Click:Connect(function()
			if self._dataProvider then
				self._dataProvider:UnequipSelectedSling()
			end
			self:_removeEquippedSlingModel()
		end))
	else
		warn("[INVENTORY_UI] " .. ProjectTreeSpec.UI.Inventory.SlingDeleteButton .. " missing")
	end

	self:SetActiveTab(self._activeTab)
	self:_clearStaticGridSlots()
end

function InventoryUIController:SetVisible(isVisible: boolean)
	if self._inventoryGui and self._inventoryGui:IsA("ScreenGui") then
		self._inventoryGui.Enabled = isVisible
	end
end

function InventoryUIController:SetActiveTab(tabName: string)
	self._activeTab = tabName == "Sling" and "Sling" or "Items"
	if self._itemsBody then
		self._itemsBody.Visible = self._activeTab == "Items"
	end
	if self._slingBody then
		self._slingBody.Visible = self._activeTab == "Sling"
	end
end

function InventoryUIController:_disconnectSlotConnections()
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
end

function InventoryUIController:_clearGeneratedSlots()
	for _, slot in ipairs(self._spawnedItemSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	for _, slot in ipairs(self._spawnedSlingSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self._spawnedItemSlots)
	table.clear(self._spawnedSlingSlots)
	table.clear(self._itemSlotMap)
	table.clear(self._slingSlotMap)
	self:_disconnectSlotConnections()
end

function InventoryUIController:_clearStaticGridSlots()
	local function clearGrid(grid: GuiObject?)
		if not grid then
			return
		end
		for _, child in ipairs(grid:GetChildren()) do
			if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	clearGrid(self._itemsGrid)
	clearGrid(self._slingsGrid)
end

function InventoryUIController:_bindCommonSlot(slot: Instance, name: string, icon: string?)
	local nameLabel = slot:FindFirstChild("Name", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = name
	end

	local iconLabel = slot:FindFirstChild("Icon", true)
	if iconLabel and iconLabel:IsA("ImageLabel") and icon then
		iconLabel.Image = icon
	end
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

	table.insert(self._slotConnections, clickTarget.MouseEnter:Connect(function()
		hoverState = true
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Sling" and self._selectedSlingId == id)
		self:_applySlotVisual(slot, hoverState, selected)
	end))
	table.insert(self._slotConnections, clickTarget.MouseLeave:Connect(function()
		hoverState = false
		local selected = (listType == "Item" and self._selectedItemId == id) or (listType == "Sling" and self._selectedSlingId == id)
		self:_applySlotVisual(slot, hoverState, selected)
	end))
	table.insert(self._slotConnections, clickTarget.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if listType == "Item" then
			self._selectedItemId = id
			if self._dataProvider then
				self._dataProvider:SelectItem(id)
			end
		elseif listType == "Sling" then
			self._selectedSlingId = id
			if self._dataProvider then
				self._dataProvider:SelectSling(id)
			end
		end
		if self._cachedSnapshot then
			self:RefreshWithData(self._cachedSnapshot)
		end
	end))
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
	slot.Name = string.format("GeneratedItem_%s", itemId)
	slot.Visible = true
	slot.Parent = self._itemsGrid
	self:_bindCommonSlot(slot, itemDef.name, itemDef.icon)

	local quantityLabel = slot:FindFirstChild("Quantity", true)
	if quantityLabel and quantityLabel:IsA("TextLabel") then
		quantityLabel.Text = string.format("x%d", math.max(0, quantity))
	end

	self._itemSlotMap[itemId] = slot
	self:_bindSlotState(slot, "Item", itemId)
	table.insert(self._spawnedItemSlots, slot)
end

function InventoryUIController:_spawnSlingSlot(slingEntry)
	if not self._slingsGrid or not self._slingTemplate or not self._slingTemplate:IsA("GuiObject") then
		return
	end
	local slingId = slingEntry.id
	local level = slingEntry.level or 1
	local isEquipped = slingEntry.equipped == true
	local slingDef = SlingConfig.GetById(slingId)
	if not slingDef then
		warn(string.format("[INVENTORY_UI] Unknown sling id in owned data: %s", slingId))
		return
	end

	local slot = self._slingTemplate:Clone()
	slot.Name = string.format("GeneratedSling_%s", slingId)
	slot.Visible = true
	slot.Parent = self._slingsGrid
	self:_bindCommonSlot(slot, slingEntry.name or slingDef.name, slingEntry.icon or slingDef.icon)

	local levelLabel = slot:FindFirstChild("Level", true)
	if levelLabel and levelLabel:IsA("TextLabel") then
		local stats = slingEntry.stats
		if type(stats) == "table" then
			levelLabel.Text = string.format("Lv.%d | Dmg %.1f | HP %.0f", math.max(1, level), stats.damage or 0, stats.hp or 0)
		else
			levelLabel.Text = string.format("Lv.%d", math.max(1, level))
		end
	end

	local equippedTag = slot:FindFirstChild("EquippedTag", true)
	if equippedTag and equippedTag:IsA("TextLabel") then
		equippedTag.Visible = isEquipped
	end

	self._slingSlotMap[slingId] = slot
	self:_bindSlotState(slot, "Sling", slingId)
	table.insert(self._spawnedSlingSlots, slot)
end

function InventoryUIController:_findSlingEntry(ownedSlings, slingId)
	for _, slingEntry in ipairs(ownedSlings) do
		if slingEntry.id == slingId then
			return slingEntry
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
	if self._itemDescription then
		self._itemDescription.Text = itemDef and (itemDef.effect or "No description") or "Select an item to view details"
	end
	if self._itemPanelIcon and itemDef then
		self._itemPanelIcon.Image = itemDef.icon or ""
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

function InventoryUIController:_refreshSlingPanel(data)
	local slingId = data.selectedSlingId or self._selectedSlingId
	self._selectedSlingId = slingId
	local slingDef = slingId and SlingConfig.GetById(slingId) or nil
	local slingEntry = slingId and self:_findSlingEntry(data.ownedSlings, slingId) or nil

	if self._slingSelectedName then
		self._slingSelectedName.Text = (slingEntry and slingEntry.name) or (slingDef and slingDef.name) or "No sling selected"
	end
	if self._slingPanelIcon and slingDef then
		self._slingPanelIcon.Image = (slingEntry and slingEntry.icon) or slingDef.icon or ""
	end
	if self._slingStatDamage then
		local value = slingEntry and slingEntry.stats and slingEntry.stats.damage
		self._slingStatDamage.Text = string.format("Power: %.2f", value or (slingDef and slingDef.stats.launchPower or 0))
	end
	if self._slingStatHP then
		local hpValue = slingEntry and slingEntry.stats and slingEntry.stats.hp
		self._slingStatHP.Text = hpValue and string.format("HP: %.0f", hpValue) or (slingEntry and string.format("Level: %d", slingEntry.level or 1) or "Level: -")
	end
	if self._slingStatRange then
		local rangeValue = slingEntry and slingEntry.stats and slingEntry.stats.range
		self._slingStatRange.Text = string.format("Range: %.2f", rangeValue or (slingDef and slingDef.stats.control or 0))
	end
	if self._slingStatRegen then
		local regenValue = slingEntry and slingEntry.stats and slingEntry.stats.regen
		local isEquipped = slingEntry and slingEntry.equipped == true
		self._slingStatRegen.Text = string.format("Regen: %.2f | %s", regenValue or 0, isEquipped and "Equipped" or "Unequipped")
	end
end

function InventoryUIController:_refreshAllSlotVisuals()
	for itemId, slot in pairs(self._itemSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedItemId == itemId)
		end
	end
	for slingId, slot in pairs(self._slingSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedSlingId == slingId)
		end
	end
end

function InventoryUIController:_resolveSlingModelSource(slingId: string): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder then
		local assetsSlings = assetsFolder:FindFirstChild("Slings")
		if assetsSlings then
			local model = assetsSlings:FindFirstChild(slingId)
			if model and model:IsA("Model") then
				return model
			end
		end
	end

	local slingsFolder = ReplicatedStorage:FindFirstChild("Slings")
	if slingsFolder then
		local model = slingsFolder:FindFirstChild(slingId)
		if model and model:IsA("Model") then
			return model
		end
	end

	warn(string.format("[INVENTORY_UI] Sling model missing for %s in ReplicatedStorage/Assets/Slings", slingId))
	return nil
end

function InventoryUIController:_removeEquippedSlingModel()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child.Name == "EquippedSlingModel" then
			child:Destroy()
		end
	end
end

function InventoryUIController:_applyEquippedSlingModel(slingId: string)
	local modelTemplate = self:_resolveSlingModelSource(slingId)
	if not modelTemplate then
		return
	end
	if modelTemplate:FindFirstChildOfClass("Humanoid") then
		warn(string.format("[INVENTORY_UI] Sling model %s contains Humanoid; skipping equip", slingId))
		return
	end

	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		warn("[INVENTORY_UI] Character missing while equipping sling")
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		warn("[INVENTORY_UI] HumanoidRootPart missing while equipping sling")
		return
	end

	self:_removeEquippedSlingModel()

	local newModel = modelTemplate:Clone()
	newModel.Name = "EquippedSlingModel"
	newModel.Parent = character
	if not newModel.PrimaryPart then
		local firstPart = newModel:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			newModel.PrimaryPart = firstPart
		end
	end
	if not newModel.PrimaryPart then
		warn(string.format("[INVENTORY_UI] Sling model %s has no BasePart", slingId))
		newModel:Destroy()
		return
	end

	newModel:PivotTo(root.CFrame * CFrame.new(0, 0, -1.4))
	for _, descendant in ipairs(newModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = newModel.PrimaryPart
	weld.Parent = newModel.PrimaryPart
end

function InventoryUIController:RefreshWithData(data)
	self._cachedSnapshot = data
	self:_clearGeneratedSlots()
	self:_clearStaticGridSlots()

	local ownedItems = data.ownedItems or {}
	for itemId, quantity in pairs(ownedItems) do
		self:_spawnItemSlot(itemId, quantity)
	end

	local ownedSlings = data.ownedSlings or {}
	for _, slingEntry in ipairs(ownedSlings) do
		self:_spawnSlingSlot(slingEntry)
	end

	if self._slingCapacityLabel then
		self._slingCapacityLabel.Text = string.format("Capacity: %d/%d", #ownedSlings, data.slingCapacity or 0)
	end

	self:_refreshItemPanel(data)
	self:_refreshSlingPanel(data)
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
