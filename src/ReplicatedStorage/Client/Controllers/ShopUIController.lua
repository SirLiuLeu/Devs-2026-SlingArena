--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local ShopUIController = {}
ShopUIController.__index = ShopUIController

local GENERATED_PREFIX = "GeneratedShopSlot_"

local function resolveGuiObject(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("GuiObject") then
		return value
	end
	return nil
end

local function resolveButton(root: Instance, path: string): GuiButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("GuiButton") then
		return value
	end
	return nil
end

local function formatDinamond(amount: number): string
	return string.format("%d Dinamond", math.max(0, math.floor(amount)))
end

function ShopUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, ShopUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._slotConnections = {}
	self._snapshot = nil
	return self
end

function ShopUIController:SetLogicService(logicService)
	self._logicService = logicService
end

function ShopUIController:Start()
	self._screenGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Shop.ScreenGui)
	if not self._screenGui then
		self._screenGui = PathResolver.resolvePath(self._playerGui, "ShopUI")
	end

	self._main = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.Shop.Main)
	self._closeButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.CloseButton)
	self._itemsTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.ItemsTabButton)
	self._launchersTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.LaunchersTabButton)
	self._dinamondsTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.DinamondsTabButton)

	self._itemsScroll = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.Shop.ItemsScroll)
	self._launchersScroll = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.Shop.LaunchersScroll)
	self._dinamondsScroll = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.Shop.DinamondsScroll)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._itemTemplate = uiFolder and uiFolder:FindFirstChild("SlotItemsOfStoreTemplate")
	self._launcherTemplate = uiFolder and uiFolder:FindFirstChild("SlotLaunchersOfStoreTemplate")
	self._dinamondTemplate = uiFolder and uiFolder:FindFirstChild("SlotDinamondsOfStoreTemplate")

	if not self._screenGui then warn("[SHOP_UI] ShopGui/ShopUI missing.") end
	if not self._itemTemplate then warn("[SHOP_UI] ReplicatedStorage.Assets.UI.SlotItemsOfStoreTemplate missing") end
	if not self._launcherTemplate then warn("[SHOP_UI] ReplicatedStorage.Assets.UI.SlotLaunchersOfStoreTemplate missing") end
	if not self._dinamondTemplate then warn("[SHOP_UI] ReplicatedStorage.Assets.UI.SlotDinamondsOfStoreTemplate missing") end

	if self._closeButton then
		table.insert(self._connections, self._closeButton.MouseButton1Click:Connect(function()
			self:SetVisible(false)
		end))
	end
	if self._itemsTabButton then
		table.insert(self._connections, self._itemsTabButton.MouseButton1Click:Connect(function()
			self:ShowTab("Items")
		end))
	end
	if self._launchersTabButton then
		table.insert(self._connections, self._launchersTabButton.MouseButton1Click:Connect(function()
			self:ShowTab("Launchers")
		end))
	end
	if self._dinamondsTabButton then
		table.insert(self._connections, self._dinamondsTabButton.MouseButton1Click:Connect(function()
			self:ShowTab("Dinamonds")
		end))
	end

	if self._logicService then
		table.insert(self._connections, self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end))
		self:RenderSnapshot(self._logicService:GetSnapshot())
	end

	self:ShowTab("Items")
end

function ShopUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		self._screenGui.Enabled = isVisible
	end
end

function ShopUIController:IsVisible(): boolean
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		return self._screenGui.Enabled
	end
	return false
end

function ShopUIController:ShowTab(tabName: string)
	if not self._main then
		return
	end
	local itemsFrame = self._main:FindFirstChild("Items")
	local launcherFrame = self._main:FindFirstChild("Launcher")
	local dinamondsFrame = self._main:FindFirstChild("Dinamonds")

	if itemsFrame and itemsFrame:IsA("GuiObject") then
		itemsFrame.Visible = tabName == "Items"
	end
	if launcherFrame and launcherFrame:IsA("GuiObject") then
		launcherFrame.Visible = tabName == "Launchers"
	end
	if dinamondsFrame and dinamondsFrame:IsA("GuiObject") then
		dinamondsFrame.Visible = tabName == "Dinamonds"
	end
end

function ShopUIController:_clearGeneratedSlots(container: GuiObject?)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if string.sub(child.Name, 1, #GENERATED_PREFIX) == GENERATED_PREFIX then
			child:Destroy()
		end
	end
end

function ShopUIController:_disconnectSlotConnections()
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
end

function ShopUIController:_applyCommonText(slot: GuiObject, title: string, quantityText: string?)
	local titleLabel = slot:FindFirstChild("Title", true)
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = title
	end
	local quantityLabel = slot:FindFirstChild("Quantity", true)
	if quantityLabel and quantityLabel:IsA("TextLabel") and quantityText then
		quantityLabel.Text = quantityText
	end
end

function ShopUIController:_applyIcon(slot: GuiObject, icon: string?)
	local iconLabel = slot:FindFirstChild("Icon", true)
	if iconLabel and iconLabel:IsA("ImageLabel") and icon then
		iconLabel.Image = icon
	end
end

function ShopUIController:_hookBuyButton(slot: GuiObject, onClick)
	local buyButton = slot:FindFirstChild("BuyButton", true)
	if buyButton and buyButton:IsA("GuiButton") then
		table.insert(self._slotConnections, buyButton.MouseButton1Click:Connect(onClick))
	end
end

function ShopUIController:RenderSnapshot(snapshot)
	self._snapshot = snapshot
	self:_disconnectSlotConnections()
	self:_clearGeneratedSlots(self._itemsScroll)
	self:_clearGeneratedSlots(self._launchersScroll)
	self:_clearGeneratedSlots(self._dinamondsScroll)

	if self._itemTemplate and self._itemTemplate:IsA("GuiObject") and self._itemsScroll then
		local order = 1
		for _, item in ipairs(snapshot.itemEntries or {}) do
			for _, qty in ipairs({ 1, 10 }) do
				local slot = self._itemTemplate:Clone()
				slot.Name = string.format("%s%s_%d", GENERATED_PREFIX, tostring(item.id), qty)
				slot.Visible = true
				slot.LayoutOrder = order
				order += 1
				slot.Parent = self._itemsScroll

				local price = if qty == 1 then item.priceX1 else item.priceX10
				self:_applyCommonText(slot, string.format("%s x%d", item.name, qty), formatDinamond(price))
				self:_applyIcon(slot, item.icon)
				self:_hookBuyButton(slot, function()
					local _, message = self._logicService:PurchaseItem(item.id, qty)
					print("[SHOP_UI]", message)
				end)

				local infoButton = slot:FindFirstChild("InfoButton", true)
				if infoButton and infoButton:IsA("GuiButton") then
					table.insert(self._slotConnections, infoButton.MouseButton1Click:Connect(function()
						print(string.format("[SHOP_UI] %s => %s", item.name, item.description or "No description"))
					end))
				end
			end
		end
	end

	if self._launcherTemplate and self._launcherTemplate:IsA("GuiObject") and self._launchersScroll then
		for index, launcher in ipairs(snapshot.launcherEntries or {}) do
			local slot = self._launcherTemplate:Clone()
			slot.Name = string.format("%s%s", GENERATED_PREFIX, tostring(launcher.id))
			slot.Visible = true
			slot.LayoutOrder = index
			slot.Parent = self._launchersScroll

			self:_applyCommonText(slot, launcher.name, formatDinamond(launcher.price))
			self:_applyIcon(slot, launcher.icon)
			self:_hookBuyButton(slot, function()
				local _, message = self._logicService:PurchaseLauncher(launcher.id)
				print("[SHOP_UI]", message)
			end)
		end
	end

	if self._dinamondTemplate and self._dinamondTemplate:IsA("GuiObject") and self._dinamondsScroll then
		for index, pack in ipairs(snapshot.dinamondEntries or {}) do
			local slot = self._dinamondTemplate:Clone()
			slot.Name = string.format("%s%s", GENERATED_PREFIX, tostring(pack.id))
			slot.Visible = true
			slot.LayoutOrder = index
			slot.Parent = self._dinamondsScroll

			self:_applyCommonText(slot, string.format("%s USD", tostring(pack.usd)), nil)
			local description = slot:FindFirstChild("Description", true)
			if description and description:IsA("TextLabel") then
				description.Text = string.format("%s (%s)", formatDinamond(pack.dinamondAmount), tostring(pack.note or ""))
			end
			self:_applyIcon(slot, pack.icon)
			self:_hookBuyButton(slot, function()
				local _, message = self._logicService:PurchaseDinamondPack(pack.id)
				print("[SHOP_UI]", message)
			end)
		end
	end

	if self._main then
		for _, descendant in ipairs(self._main:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				descendant.Text = string.gsub(descendant.Text, "Diamond", "Dinamond")
				descendant.Text = string.gsub(descendant.Text, "Diamonds", "Dinamond")
			end
		end
	end
end

function ShopUIController:Destroy()
	self:_disconnectSlotConnections()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return ShopUIController
