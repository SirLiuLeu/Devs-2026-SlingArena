--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

local NORMAL_COLOR = Color3.fromRGB(41, 43, 53)
local HOVER_COLOR = Color3.fromRGB(62, 66, 82)
local SELECTED_COLOR = Color3.fromRGB(88, 102, 132)
local ITEM_SLOT_TEMPLATE_NAME = "ItemSlotTemplate_InventoryUI"

local function resolveGui(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return if value and value:IsA("GuiObject") then value else nil
end

local function resolveTextLabel(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return if value and value:IsA("TextLabel") then value else nil
end

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return if value and value:IsA("TextButton") then value else nil
end

local function findDirectText(root: Instance, name: string): TextLabel?
	local child = root:FindFirstChild(name)
	return if child and child:IsA("TextLabel") then child else nil
end

local function findDirectImage(root: Instance, name: string): ImageLabel?
	local child = root:FindFirstChild(name)
	return if child and child:IsA("ImageLabel") then child else nil
end

local function getTemplateRoot(slot: Instance): GuiObject?
	local root = slot:FindFirstChild("Root")
	if root and root:IsA("GuiObject") then
		return root
	end
	warn(string.format("[INVENTORY_UI] %s clone is missing its Root GuiObject.", ITEM_SLOT_TEMPLATE_NAME))
	return nil
end

function InventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({
		_playerGui = playerGui,
		_connections = {},
		_slotConnections = {},
		_itemSlotMap = {},
		_selectedItemId = nil,
		_cachedSnapshot = nil,
	}, InventoryUIController)
end

function InventoryUIController:SetDataProvider(provider)
	self._dataProvider = provider
end

function InventoryUIController:Start(uiReadySignal: BindableEvent?)
	if self._started then
		return
	end
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then
		uiReadySignal.Event:Wait()
	end
	self._started = true

	local ui = ProjectTreeSpec.UI.Inventory
	self._inventoryGui = PathResolver.resolvePath(self._playerGui, ui.ScreenGui) :: ScreenGui?
	self._grid = resolveGui(self._playerGui, ui.ItemsGridContainer)
	self._selectedName = resolveTextLabel(self._playerGui, ui.ItemsSelectedName)
	self._stat1 = resolveTextLabel(self._playerGui, ui.ItemsStat1)
	self._stat2 = resolveTextLabel(self._playerGui, ui.ItemsStat2)
	self._stat3 = resolveTextLabel(self._playerGui, ui.ItemsStat3)
	self._description = resolveTextLabel(self._playerGui, ui.ItemsDescription)
	self._useButton = resolveTextButton(self._playerGui, ui.ItemsUseButton)
	self._closeButton = resolveTextButton(self._playerGui, ui.CloseButton)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._itemTemplate = uiFolder and uiFolder:FindFirstChild(ITEM_SLOT_TEMPLATE_NAME)

	if not self._inventoryGui then warn("[INVENTORY_UI] PlayerGui.InventoryUI ScreenGui is missing.") end
	if not self._grid then warn("[INVENTORY_UI] InventoryUI.Root.BodyItems.GridContainer is missing.") end
	if not (self._itemTemplate and self._itemTemplate:IsA("GuiObject")) then
		warn("[INVENTORY_UI] ReplicatedStorage.Assets.UI.ItemSlotTemplate_InventoryUI is missing.")
		self._itemTemplate = nil
	end
	if not self._closeButton then warn("[INVENTORY_UI] InventoryUI.Root.Header.CloseButton is missing.") end
	if not self._useButton then warn("[INVENTORY_UI] InventoryUI.Root.BodyItems.RightPanel.ActionButtons.UseButton is missing.") end

	-- Slot1..Slot4 in Studio are layout placeholders. Runtime inventory slots are
	-- generated from the shared template and reconciled against the server snapshot.
	if self._grid then
		for _, child in ipairs(self._grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	if self._closeButton then
		table.insert(self._connections, self._closeButton.Activated:Connect(function()
			self:SetVisible(false)
		end))
	end
	if self._useButton then
		table.insert(self._connections, self._useButton.Activated:Connect(function()
			if self._dataProvider then
				self._dataProvider:UseSelectedItem()
			end
		end))
	end

	if DebugConfig.VerboseTrace then
		print("[INVENTORY_UI] Items-only controller started.")
	end
end

function InventoryUIController:SetVisible(isVisible: boolean)
	if self._inventoryGui and self._inventoryGui.Parent then
		self._inventoryGui.Enabled = isVisible
	end
	if isVisible and self._cachedSnapshot then
		self:RefreshWithData(self._cachedSnapshot)
	end
end

function InventoryUIController:_disconnectSlot(slot: Instance)
	local connections = self._slotConnections[slot]
	if not connections then
		return
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	self._slotConnections[slot] = nil
end

function InventoryUIController:_applySlotVisual(slot: GuiObject, hovered: boolean, selected: boolean)
	slot.BackgroundColor3 = if selected then SELECTED_COLOR elseif hovered then HOVER_COLOR else NORMAL_COLOR
	local stroke = slot:FindFirstChildWhichIsA("UIStroke", true)
	if stroke then
		stroke.Thickness = if selected then 2 else 1
		stroke.Color = if selected then Color3.fromRGB(255, 230, 130) else Color3.fromRGB(120, 120, 120)
	end
end

function InventoryUIController:_bindSlot(slot: GuiObject, itemId: string)
	slot.Active = true
	slot.Selectable = true
	self:_applySlotVisual(slot, false, self._selectedItemId == itemId)

	local clickTarget: GuiObject = slot
	local childButton = slot:FindFirstChildWhichIsA("GuiButton", true)
	if childButton then
		clickTarget = childButton
	end

	local connections = {}
	table.insert(connections, clickTarget.MouseEnter:Connect(function()
		self:_applySlotVisual(slot, true, self._selectedItemId == itemId)
	end))
	table.insert(connections, clickTarget.MouseLeave:Connect(function()
		self:_applySlotVisual(slot, false, self._selectedItemId == itemId)
	end))
	table.insert(connections, clickTarget.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		self._selectedItemId = itemId
		if self._dataProvider then
			self._dataProvider:SelectItem(itemId)
		end
		if self._cachedSnapshot then
			self:RefreshWithData(self._cachedSnapshot)
		end
	end))
	self._slotConnections[slot] = connections
end

function InventoryUIController:_bindSlotContent(slot: GuiObject, itemId: string, quantity: number)
	local itemDef = ItemConfig.GetById(itemId)
	if not itemDef then
		warn(string.format("[INVENTORY_UI] Unknown item id in owned data: %s", itemId))
		return
	end

	local root = getTemplateRoot(slot)
	if not root then
		return
	end
	local nameLabel = findDirectText(root, "Name")
	local iconLabel = findDirectImage(root, "Icon")
	local quantityLabel = findDirectText(root, "Quantity")

	if nameLabel then nameLabel.Text = itemDef.name end
	if iconLabel and type(itemDef.icon) == "string" then iconLabel.Image = itemDef.icon end
	if quantityLabel then quantityLabel.Text = string.format("x%d", math.max(0, math.floor(tonumber(quantity) or 0))) end
end

function InventoryUIController:_spawnItemSlot(itemId: string, quantity: number)
	if not (self._grid and self._itemTemplate and self._itemTemplate:IsA("GuiObject")) then
		return
	end
	local itemDef = ItemConfig.GetById(itemId)
	if not itemDef then
		warn(string.format("[INVENTORY_UI] Cannot render unknown item id %q.", itemId))
		return
	end

	local slot = self._itemTemplate:Clone()
	if not getTemplateRoot(slot) then
		slot:Destroy()
		return
	end
	slot.Name = "GeneratedItem_" .. itemId
	slot.Visible = true
	slot.Parent = self._grid
	self:_bindSlotContent(slot, itemId, quantity)
	self._itemSlotMap[itemId] = slot
	self:_bindSlot(slot, itemId)
end

function InventoryUIController:_destroySlot(slot: GuiObject)
	self:_disconnectSlot(slot)
	if slot.Parent then
		slot:Destroy()
	end
end

function InventoryUIController:_reconcileSlots(data)
	local seen = {}
	for itemId, quantity in pairs(data.ownedItems or {}) do
		local normalizedId = tostring(itemId)
		seen[normalizedId] = true
		local slot = self._itemSlotMap[normalizedId]
		if slot and slot.Parent then
			self:_bindSlotContent(slot, normalizedId, quantity)
		else
			self:_spawnItemSlot(normalizedId, quantity)
		end
	end

	for itemId, slot in pairs(self._itemSlotMap) do
		if not seen[itemId] then
			self._itemSlotMap[itemId] = nil
			self:_destroySlot(slot)
		end
	end
end

function InventoryUIController:_refreshPanel(data)
	self._selectedItemId = data.selectedItemId or self._selectedItemId
	local itemId = self._selectedItemId
	local itemDef = itemId and ItemConfig.GetById(itemId) or nil
	local quantity = itemId and math.max(0, math.floor(tonumber(data.ownedItems and data.ownedItems[itemId]) or 0)) or 0

	if self._selectedName then
		self._selectedName.Text = itemDef and itemDef.name or "No item selected"
	end
	if self._stat1 then self._stat1.Text = string.format("Quantity: %d", quantity) end
	if self._stat2 then self._stat2.Text = itemDef and ("Type: " .. tostring(itemDef.type or "-")) or "Type: -" end
	if self._stat3 then self._stat3.Text = data.lastUseResult or "Use: ready" end
	if self._description then
		self._description.Text = if itemDef then tostring(itemDef.description or itemDef.effect or "") else ""
	end
	if self._useButton then
		self._useButton.Active = itemDef ~= nil and quantity > 0 and itemDef.consumeOnUse == true
		self._useButton.AutoButtonColor = self._useButton.Active
	end
end

function InventoryUIController:_refreshSlotVisuals()
	for itemId, slot in pairs(self._itemSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedItemId == itemId)
		end
	end
end

function InventoryUIController:RefreshWithData(data)
	self._cachedSnapshot = data
	if not (self._inventoryGui and self._inventoryGui.Enabled) then
		return
	end
	self:_reconcileSlots(data)
	self:_refreshPanel(data)
	self:_refreshSlotVisuals()
end

function InventoryUIController:Destroy()
	for slot in pairs(self._slotConnections) do
		self:_disconnectSlot(slot)
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._itemSlotMap)
end

return InventoryUIController
