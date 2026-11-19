--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)
local LauncherPreviewConfig = require(ReplicatedStorage.Shared.Config.LauncherPreviewConfig)
local PetPreviewConfig = require(ReplicatedStorage.Shared.Config.PetPreviewConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetDisplayFormatter = require(ReplicatedStorage.Shared.Utils.PetDisplayFormatter)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local ShopUIController = {}
ShopUIController.__index = ShopUIController

local GENERATED_PREFIX = "GeneratedShopSlot_"
local DEFAULT_LANGUAGE = "vi"

local function resolveGuiObject(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	if value and value:IsA("GuiObject") then
		return value
	end
	return nil
end

local function resolveButton(root: Instance, path: string): GuiButton?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	if value and value:IsA("GuiButton") then
		return value
	end
	return nil
end

local function formatDiamonds(amount: number): string
	return string.format("%d Diamonds", math.max(0, math.floor(tonumber(amount) or 0)))
end

local function findFirstChildOfClass(root: Instance, name: string, className: string): Instance?
	local child = root:FindFirstChild(name, true)
	if child and child:IsA(className) then
		return child
	end
	return nil
end

local function setTextLabel(root: Instance, name: string, value: string, richText: boolean?)
	local label = findFirstChildOfClass(root, name, "TextLabel")
	if label then
		(label :: TextLabel).Text = value
		if richText ~= nil then
			(label :: TextLabel).RichText = richText
		end
	end
end

local function buildCatalogSignature(snapshot): string
	local parts = {}
	for _, key in ipairs({ "itemEntries", "launcherEntries", "petEntries", "dinamondEntries" }) do
		for _, entry in ipairs(snapshot[key] or {}) do
			table.insert(parts, table.concat({
				key,
				tostring(entry.id),
				tostring(entry.name),
				tostring(entry.modelName),
				tostring(entry.price),
				tostring(entry.priceX1),
				tostring(entry.priceX10),
				tostring(entry.script),
				tostring(entry.description),
				tostring(entry.icon),
				tostring(entry.rarity),
				tostring(entry.usd),
				tostring(entry.dinamondAmount),
				tostring(entry.note),
			}, ":"))
		end
	end
	return table.concat(parts, "|")
end

local function resolveTemplate(uiFolder: Instance?, preferredName: string, legacyNames: { string }?): GuiObject?
	if not uiFolder then return nil end
	local candidates = { preferredName }
	for _, legacyName in ipairs(legacyNames or {}) do
		table.insert(candidates, legacyName)
	end
	for _, candidate in ipairs(candidates) do
		local template = uiFolder:FindFirstChild(candidate)
		if template and template:IsA("GuiObject") then
			return template
		end
	end
	return nil
end

function ShopUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, ShopUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._uiConnections = {}
	self._slotConnections = {}
	self._snapshot = nil
	self._activeTab = "Items"
	return self
end

function ShopUIController:SetLogicService(logicService)
	self._logicService = logicService
end

function ShopUIController:SetToastController(toastController)
	self._toastController = toastController
end

function ShopUIController:_bindPurchaseFeedback()
	if self._feedbackConnection then return end
	local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	local feedbackRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if not (feedbackRemote and feedbackRemote:IsA("RemoteEvent")) then
		warn("[SHOP_UI] GameplayFeedback RemoteEvent is missing; purchase Toast messages are unavailable.")
		return
	end
	self._feedbackConnection = feedbackRemote.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" or message.EventType ~= "ShopPurchaseResult" then return end
		local payload = if type(message.Payload) == "table" then message.Payload else {}
		local productId = tostring(payload.ItemId or "")
		local productName = productId
		local productType = tostring(payload.PurchaseType or "")
		local entries = if productType == "Item" then (self._snapshot and self._snapshot.itemEntries)
			elseif productType == "Launcher" then (self._snapshot and self._snapshot.launcherEntries)
			elseif productType == "Pet" then (self._snapshot and self._snapshot.petEntries)
			else {}
		for _, entry in ipairs(entries or {}) do
			if tostring(entry.id) == productId then
				productName = tostring(entry.name or productId)
				break
			end
		end
		if self._toastController then
			if payload.Success == true then
				self._toastController:Enqueue("Mua thành công: " .. productName)
			elseif payload.Reason == "InsufficientDiamonds" then
				self._toastController:Enqueue("Không đủ Diamonds để mua " .. productName)
			else
				self._toastController:Enqueue("Không thể mua " .. productName .. " (" .. tostring(payload.Reason or "PurchaseRejected") .. ")")
			end
		end
	end)
end

function ShopUIController:Start()
	self:_bindCharacterLifecycle()
	self:_resolveGuiAndBind()
	self:_bindPurchaseFeedback()

	if self._logicService and not self._logicConnection then
		self._logicConnection = self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end)
	end

	if self._logicService then
		self:RenderSnapshot(self._logicService:GetSnapshot())
	end
	self:ShowTab("Items")
end

function ShopUIController:_disconnectSlotConnections()
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
end

function ShopUIController:_disconnectUiConnections()
	for _, connection in ipairs(self._uiConnections) do
		connection:Disconnect()
	end
	table.clear(self._uiConnections)
	self:_disconnectSlotConnections()
end

function ShopUIController:_bindCharacterLifecycle()
	if self._characterConnection then return end
	local player = Players.LocalPlayer
	self._characterConnection = player.CharacterAdded:Connect(function()
		-- ScreenGuis with ResetOnSpawn enabled may be recreated with the character.
		task.defer(function()
			self:_resolveGuiAndBind()
			if self._snapshot then
				self:RenderSnapshot(self._snapshot)
			end
			self:ShowTab(self._activeTab or "Items")
		end)
	end)
end

function ShopUIController:_resolveGuiAndBind()
	local wasVisible = self:IsVisible()
	self:_disconnectUiConnections()

	self._screenGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Shop.ScreenGui, { shouldWarn = false })
	if not self._screenGui then
		self._screenGui = self._playerGui:FindFirstChild("ShopUI")
	end

	self._main = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.Shop.Main)
	if not self._main then
		self._main = self._screenGui and self._screenGui:FindFirstChild("Main")
	end

	self._closeButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.CloseButton)
	self._itemsTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.ItemsTabButton)
	self._launchersTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.LaunchersTabButton)
	self._dinamondsTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.DinamondsTabButton)
	self._petsTabButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.Shop.PetsTabButton)

	local main = self._main
	local itemsFrame = main and main:FindFirstChild("Items")
	local launcherFrame = main and main:FindFirstChild("Launcher")
	local petFrame = main and main:FindFirstChild("Pet")
	local diamondsFrame = main and main:FindFirstChild("Dinamonds")

	-- The updated Studio tree places Items and Dinamonds grids directly under
	-- their Frames, while Launcher and Pet use a nested ScrollingFrame.
	self._itemsContainer = if itemsFrame and itemsFrame:IsA("GuiObject") then itemsFrame else nil
	self._launchersContainer = if launcherFrame then launcherFrame:FindFirstChild("ScrollingFrame") else nil
	self._petsContainer = if petFrame then petFrame:FindFirstChild("ScrollingFrame") else nil
	self._dinamondsContainer = if diamondsFrame and diamondsFrame:IsA("GuiObject") then diamondsFrame else nil

	-- Backward-compatible fallback for the previous Content.ScrollingFrame tree.
	if itemsFrame and not (self._itemsContainer and self._itemsContainer:FindFirstChildOfClass("UIGridLayout")) then
		local content = itemsFrame:FindFirstChild("Content")
		self._itemsContainer = content and content:FindFirstChild("ScrollingFrame") or self._itemsContainer
	end
	if diamondsFrame and not (self._dinamondsContainer and self._dinamondsContainer:FindFirstChildOfClass("UIGridLayout")) then
		local content = diamondsFrame:FindFirstChild("Content")
		self._dinamondsContainer = content and content:FindFirstChild("ScrollingFrame") or self._dinamondsContainer
	end
	if launcherFrame and not (self._launchersContainer and self._launchersContainer:IsA("GuiObject")) then
		local content = launcherFrame:FindFirstChild("Content")
		self._launchersContainer = content and content:FindFirstChild("ScrollingFrame") or nil
	end
	if petFrame and not (self._petsContainer and self._petsContainer:IsA("GuiObject")) then
		local content = petFrame:FindFirstChild("Content")
		self._petsContainer = content and content:FindFirstChild("ScrollingFrame") or nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	self._launcherAssets = assets and assets:FindFirstChild("Launchers")
	self._petAssets = assets and assets:FindFirstChild("Pets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._itemTemplate = resolveTemplate(uiFolder, "SlotItemTemplate_shopUI", { "SlotItemsTemplate_ShopUI" })
	self._launcherTemplate = resolveTemplate(uiFolder, "SlotLauncherTemplate_shopUI", { "SlotLauncherTemplate_shopUI" })
	self._petTemplate = resolveTemplate(uiFolder, "SlotPetTemplate_shopUI")
	self._dinamondTemplate = resolveTemplate(uiFolder, "SlotDiamondPackTemplate_ShopUI")

	if not self._screenGui then warn("[SHOP_UI] ShopUI ScreenGui is missing.") end
	if not self._main then warn("[SHOP_UI] ShopUI.Main is missing.") end
	if not self._itemTemplate then warn("[SHOP_UI] Assets.UI.SlotItemTemplate_shopUI is missing.") end
	if not self._launcherTemplate then warn("[SHOP_UI] Assets.UI.SlotLauncherTemplate_shopUI is missing.") end
	if not self._petTemplate then warn("[SHOP_UI] Assets.UI.SlotPetTemplate_shopUI is missing.") end
	if not self._dinamondTemplate then warn("[SHOP_UI] Assets.UI.SlotDiamondPackTemplate_ShopUI is missing.") end
	if not self._launcherAssets then warn("[SHOP_UI] ReplicatedStorage.Assets.Launchers is missing.") end
	if not self._petAssets then warn("[SHOP_UI] ReplicatedStorage.Assets.Pets is missing.") end

	if self._closeButton then
		table.insert(self._uiConnections, self._closeButton.Activated:Connect(function()
			self:SetVisible(false)
		end))
	end
	if self._itemsTabButton then
		table.insert(self._uiConnections, self._itemsTabButton.Activated:Connect(function()
			self:ShowTab("Items")
		end))
	end
	if self._launchersTabButton then
		table.insert(self._uiConnections, self._launchersTabButton.Activated:Connect(function()
			self:ShowTab("Launchers")
		end))
	end
	if self._petsTabButton then
		table.insert(self._uiConnections, self._petsTabButton.Activated:Connect(function()
			self:ShowTab("Pets")
		end))
	end
	if self._dinamondsTabButton then
		table.insert(self._uiConnections, self._dinamondsTabButton.Activated:Connect(function()
			self:ShowTab("Dinamonds")
		end))
	end

	self:SetVisible(wasVisible)
end

function ShopUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		self._screenGui.Enabled = isVisible
	end
end

function ShopUIController:IsVisible(): boolean
	return self._screenGui ~= nil
		and self._screenGui:IsA("ScreenGui")
		and self._screenGui.Enabled
end

function ShopUIController:ShowTab(tabName: string)
	if not self._main then return end
	local normalizedTab = tabName
	if normalizedTab ~= "Items" and normalizedTab ~= "Launchers" and normalizedTab ~= "Pets" and normalizedTab ~= "Dinamonds" then
		normalizedTab = "Items"
	end
	self._activeTab = normalizedTab

	local visibility = {
		Items = normalizedTab == "Items",
		Launcher = normalizedTab == "Launchers",
		Pet = normalizedTab == "Pets",
		Dinamonds = normalizedTab == "Dinamonds",
	}
	for frameName, isVisible in pairs(visibility) do
		local frame = self._main:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") then
			frame.Visible = isVisible
		end
	end
end

function ShopUIController:_clearGeneratedSlots(container: Instance?)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if string.sub(child.Name, 1, #GENERATED_PREFIX) == GENERATED_PREFIX then
			child:Destroy()
		end
	end
end

function ShopUIController:_cloneSlot(template: GuiObject?, container: Instance?, productId: string, order: number): GuiObject?
	if not template or not container then return nil end
	local slot = template:Clone()
	slot.Name = GENERATED_PREFIX .. productId
	slot.Visible = true
	slot.LayoutOrder = order
	slot.Parent = container
	local info = slot:FindFirstChild("Info", true)
	if info and info:IsA("GuiObject") then
		info.Visible = false
	end
	return slot
end

function ShopUIController:_renderBalance(balance: number?)
	if not self._main or typeof(balance) ~= "number" then return end
	for _, labelName in ipairs({ "Balance", "DiamondBalance", "DiamondsBalance", "DinamondBalance" }) do
		local label = findFirstChildOfClass(self._main, labelName, "TextLabel")
		if label then
			(label :: TextLabel).Text = formatDiamonds(balance)
			return
		end
	end
end

function ShopUIController:_applyCommonText(slot: GuiObject, title: string, priceText: string?)
	setTextLabel(slot, "Title", title)
	if priceText then
		local priceLabel = findFirstChildOfClass(slot, "Price", "TextLabel")
			or findFirstChildOfClass(slot, "Quantity", "TextLabel")
		if priceLabel then
			(priceLabel :: TextLabel).Text = priceText
		else
			local buyButton = findFirstChildOfClass(slot, "BuyButton", "TextButton")
			if buyButton then (buyButton :: TextButton).Text = priceText end
		end
	end
end

function ShopUIController:_applyIcon(slot: GuiObject, icon: string?)
	local iconLabel = findFirstChildOfClass(slot, "Icon", "ImageLabel")
	if iconLabel and type(icon) == "string" and icon ~= "" then
		(iconLabel :: ImageLabel).Image = icon
	end
end

function ShopUIController:_populatePreview(slot: GuiObject, rootFolder: Instance?, modelName: string, previewConfig: any?)
	local preview = slot:FindFirstChild("Preview", true)
	if not (preview and preview:IsA("ViewportFrame")) then
		warn(string.format("[SHOP_UI] %s is missing Preview ViewportFrame.", slot.Name))
		return
	end
	PreviewRenderer.Populate(preview, rootFolder, modelName, previewConfig)
end

function ShopUIController:_hookBuyButton(slot: GuiObject, onClick: () -> ())
	local buyButton = findFirstChildOfClass(slot, "BuyButton", "GuiButton")
	if buyButton then
		table.insert(self._slotConnections, (buyButton :: GuiButton).Activated:Connect(onClick))
	else
		warn(string.format("[SHOP_UI] %s is missing BuyButton.", slot.Name))
	end
end

function ShopUIController:_hookInfoButton(slot: GuiObject, scriptText: string?)
	local info = slot:FindFirstChild("Info", true)
	local infoButton = findFirstChildOfClass(slot, "InfoButton", "GuiButton")
	if info and info:IsA("GuiObject") then
		info.Visible = false
		local scriptLabel = findFirstChildOfClass(info, "Script", "TextLabel")
		if scriptLabel then
			local label = scriptLabel :: TextLabel
			label.Text = scriptText or "Chưa có mô tả cho sản phẩm này."
			label.RichText = true
		end
	end
	if infoButton and info and info:IsA("GuiObject") then
		table.insert(self._slotConnections, (infoButton :: GuiButton).Activated:Connect(function()
			info.Visible = not info.Visible
		end))
	elseif infoButton then
		warn(string.format("[SHOP_UI] %s has InfoButton but no Info Frame.", slot.Name))
	end
end

function ShopUIController:_getPetScript(petEntry): string
	local definition = PetsConfig.GetById(tostring(petEntry.id or ""))
	if definition then
		local ok, formatted = pcall(function()
			return PetDisplayFormatter.Format(definition, 1, false, DEFAULT_LANGUAGE)
		end)
		if ok and type(formatted) == "table" and type(formatted.ScriptText) == "string" then
			return formatted.ScriptText
		end
		return definition.script or "Chưa có mô tả cho Pet này."
	end
	return petEntry.script or "Chưa có mô tả cho Pet này."
end

function ShopUIController:_renderItems(snapshot)
	if not (self._itemTemplate and self._itemsContainer) then return end
	local order = 0
	for _, item in ipairs(snapshot.itemEntries or {}) do
		for _, quantity in ipairs({ 1, 10 }) do
			order += 1
			local productKey = string.format("Item_%s_x%d_%d", tostring(item.id), quantity, order)
			local slot = self:_cloneSlot(self._itemTemplate, self._itemsContainer, productKey, order)
			if slot then
				local price = if quantity == 10 then item.priceX10 else item.priceX1
				self:_applyCommonText(slot, string.format("%s x%d", tostring(item.name), quantity), formatDiamonds(price))
				self:_applyIcon(slot, item.icon)
				self:_hookInfoButton(slot, item.script or item.description)
				self:_hookBuyButton(slot, function()
					if self._logicService then
						self._logicService:PurchaseItem(item.id, quantity)
					end
				end)
			end
		end
	end
end

function ShopUIController:_renderLaunchers(snapshot)
	if not (self._launcherTemplate and self._launchersContainer) then return end
	for index, launcher in ipairs(snapshot.launcherEntries or {}) do
		local slot = self:_cloneSlot(self._launcherTemplate, self._launchersContainer, "Launcher_" .. tostring(launcher.id), index)
		if slot then
			self:_applyCommonText(slot, tostring(launcher.name), formatDiamonds(launcher.price))
			self:_populatePreview(slot, self._launcherAssets, tostring(launcher.id), LauncherPreviewConfig.Get(tostring(launcher.id)))
			self:_hookInfoButton(slot, launcher.script or launcher.description)
			self:_hookBuyButton(slot, function()
				if self._logicService then
					self._logicService:PurchaseLauncher(launcher.id)
				end
			end)
		end
	end
end

function ShopUIController:_renderPets(snapshot)
	if not (self._petTemplate and self._petsContainer) then return end
	for index, pet in ipairs(snapshot.petEntries or {}) do
		local slot = self:_cloneSlot(self._petTemplate, self._petsContainer, "Pet_" .. tostring(pet.id), index)
		if slot then
			local title = tostring(pet.name)
			if type(pet.rarity) == "string" and pet.rarity ~= "" then
				title = string.format("%s (%s)", title, pet.rarity)
			end
			self:_applyCommonText(slot, title, formatDiamonds(pet.price))
			local modelName = tostring(pet.modelName or pet.id)
			self:_populatePreview(slot, self._petAssets, modelName, PetPreviewConfig.Get(tostring(pet.id)))
			self:_hookInfoButton(slot, self:_getPetScript(pet))
			self:_hookBuyButton(slot, function()
				if self._logicService then
					self._logicService:PurchasePet(pet.id)
				end
			end)
		end
	end
end

function ShopUIController:_renderDiamondPacks(snapshot)
	if not (self._dinamondTemplate and self._dinamondsContainer) then return end
	for index, pack in ipairs(snapshot.dinamondEntries or {}) do
		local slot = self:_cloneSlot(self._dinamondTemplate, self._dinamondsContainer, "DiamondPack_" .. tostring(pack.id), index)
		if slot then
			self:_applyCommonText(slot, string.format("%s USD", tostring(pack.usd)), nil)
			setTextLabel(slot, "Description", string.format("%s (%s)", formatDiamonds(pack.dinamondAmount), tostring(pack.note or "")))
			self:_applyIcon(slot, pack.icon)
			self:_hookBuyButton(slot, function()
				if self._logicService then
					self._logicService:PurchaseDinamondPack(pack.id)
				end
			end)
		end
	end
end

function ShopUIController:RenderSnapshot(snapshot)
	if type(snapshot) ~= "table" then return end
	self._snapshot = snapshot
	local signature = buildCatalogSignature(snapshot)
	if self._catalogSignature == signature then
		self:_renderBalance(snapshot.balance)
		return
	end
	self._catalogSignature = signature
	self:_renderBalance(snapshot.balance)
	self:_disconnectSlotConnections()
	self:_clearGeneratedSlots(self._itemsContainer)
	self:_clearGeneratedSlots(self._launchersContainer)
	self:_clearGeneratedSlots(self._petsContainer)
	self:_clearGeneratedSlots(self._dinamondsContainer)

	self:_renderItems(snapshot)
	self:_renderLaunchers(snapshot)
	self:_renderPets(snapshot)
	self:_renderDiamondPacks(snapshot)
end

function ShopUIController:Destroy()
	self:_disconnectUiConnections()
	if self._feedbackConnection then
		self._feedbackConnection:Disconnect()
		self._feedbackConnection = nil
	end
	if self._characterConnection then
		self._characterConnection:Disconnect()
		self._characterConnection = nil
	end
	if self._logicConnection then
		self._logicConnection:Disconnect()
		self._logicConnection = nil
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return ShopUIController
