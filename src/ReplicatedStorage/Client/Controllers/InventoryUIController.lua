--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)

local InventoryUIController = {}
InventoryUIController.__index = InventoryUIController

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

function InventoryUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, InventoryUIController)
	self._playerGui = playerGui
	self._spawnedSlots = {}
	return self
end

function InventoryUIController:Start()
	self._inventoryGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Inventory.ScreenGui)
	self._itemsGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.ItemsGridContainer)
	self._slingsGrid = resolveGui(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingsGridContainer)
	self._slingCapacityLabel = resolveTextLabel(self._playerGui, ProjectTreeSpec.UI.Inventory.SlingCapacityLabel)

	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	if not assets then
		warn("[INVENTORY_UI] ReplicatedStorage.Assets missing")
	else
		local uiFolder = assets:FindFirstChild("UI")
		if not uiFolder then
			warn("[INVENTORY_UI] ReplicatedStorage.Assets.UI missing")
		else
			self._itemTemplate = uiFolder:FindFirstChild("ItemSlotTemplate")
			self._slingTemplate = uiFolder:FindFirstChild("SlingsSlotTemplate") or uiFolder:FindFirstChild("SlingSlotTemplate")
			if not self._itemTemplate then
				warn("[INVENTORY_UI] ItemSlotTemplate missing in ReplicatedStorage.Assets.UI")
			end
			if not self._slingTemplate then
				warn("[INVENTORY_UI] SlingsSlotTemplate missing in ReplicatedStorage.Assets.UI")
			end
		end
	end

	if not self._inventoryGui then
		warn("[INVENTORY_UI] InventoryUI ScreenGui missing")
	end
	if not self._itemsGrid then
		warn("[INVENTORY_UI] Items grid container missing")
	end
	if not self._slingsGrid then
		warn("[INVENTORY_UI] Slings grid container missing")
	end
end

function InventoryUIController:_clearGeneratedSlots()
	for _, slot in ipairs(self._spawnedSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self._spawnedSlots)
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
	table.insert(self._spawnedSlots, slot)
end

function InventoryUIController:_spawnSlingSlot(slingId: string, level: number, isEquipped: boolean)
	if not self._slingsGrid or not self._slingTemplate or not self._slingTemplate:IsA("GuiObject") then
		return
	end
	local slingDef = SlingConfig.GetById(slingId)
	if not slingDef then
		warn(string.format("[INVENTORY_UI] Unknown sling id in owned data: %s", slingId))
		return
	end

	local slot = self._slingTemplate:Clone()
	slot.Name = string.format("GeneratedSling_%s", slingId)
	slot.Visible = true
	slot.Parent = self._slingsGrid
	self:_bindCommonSlot(slot, slingDef.name, nil)

	local levelLabel = slot:FindFirstChild("Level", true)
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = string.format("Lv.%d", math.max(1, level))
	end

	local equippedTag = slot:FindFirstChild("EquippedTag", true)
	if equippedTag and equippedTag:IsA("TextLabel") then
		equippedTag.Visible = isEquipped
	end
	table.insert(self._spawnedSlots, slot)
end

function InventoryUIController:RefreshWithData(data)
	self:_clearGeneratedSlots()

	local ownedItems = data.ownedItems or {}
	for itemId, quantity in pairs(ownedItems) do
		self:_spawnItemSlot(itemId, quantity)
	end

	local ownedSlings = data.ownedSlings or {}
	for _, slingEntry in ipairs(ownedSlings) do
		self:_spawnSlingSlot(slingEntry.id, slingEntry.level or 1, slingEntry.equipped == true)
	end

	if self._slingCapacityLabel then
		self._slingCapacityLabel.Text = string.format("Capacity: %d/%d", #ownedSlings, data.slingCapacity or 0)
	end
end

function InventoryUIController:Destroy()
	self:_clearGeneratedSlots()
end

return InventoryUIController
