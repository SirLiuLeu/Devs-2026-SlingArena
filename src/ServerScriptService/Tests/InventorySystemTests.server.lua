--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryDataProvider = require(ReplicatedStorage.Client.Services.InventoryDataProvider)
local InventoryUIController = require(ReplicatedStorage.Client.Controllers.InventoryUIController)
local MockData = require(ReplicatedStorage.Client.Services.MockData)

local function runTest(name: string, testFn)
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[InventorySystemTests] PASS %s", name))
	else
		warn(string.format("[InventorySystemTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function ensureAssetTemplates()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local ui = assets:FindFirstChild("UI")
	if not ui then
		ui = Instance.new("Folder")
		ui.Name = "UI"
		ui.Parent = assets
	end

	local itemTemplate = ui:FindFirstChild("ItemSlotTemplate_InventoryUI")
	if not itemTemplate then
		itemTemplate = Instance.new("Frame")
		itemTemplate.Name = "ItemSlotTemplate_InventoryUI"
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Parent = itemTemplate
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Parent = itemTemplate
		local quantity = Instance.new("TextLabel")
		quantity.Name = "Quantity"
		quantity.Parent = itemTemplate
		itemTemplate.Parent = ui
	end

	local slingTemplate = ui:FindFirstChild("SlingsSlotTemplate_InventoryUI")
	if not slingTemplate then
		slingTemplate = Instance.new("Frame")
		slingTemplate.Name = "SlingsSlotTemplate_InventoryUI"
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Parent = slingTemplate
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Parent = slingTemplate
		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.Parent = slingTemplate
		local equippedTag = Instance.new("TextLabel")
		equippedTag.Name = "EquippedTag"
		equippedTag.Parent = slingTemplate
		slingTemplate.Parent = ui
	end
end

local function buildInventoryGui(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "InventoryUI"
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Parent = screen

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Parent = root
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Parent = header

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Parent = root
	local itemsTab = Instance.new("TextButton")
	itemsTab.Name = "ItemsTab"
	itemsTab.Parent = tabs
	local slingTab = Instance.new("TextButton")
	slingTab.Name = "SlingTab"
	slingTab.Parent = tabs

	local bodyItems = Instance.new("Frame")
	bodyItems.Name = "BodyItems"
	bodyItems.Parent = root
	local itemsGrid = Instance.new("ScrollingFrame")
	itemsGrid.Name = "GridContainer"
	itemsGrid.Parent = bodyItems

	local bodySling = Instance.new("Frame")
	bodySling.Name = "BodySling"
	bodySling.Parent = root
	local slingGrid = Instance.new("ScrollingFrame")
	slingGrid.Name = "GridContainer"
	slingGrid.Parent = bodySling
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Parent = bodySling
	local cap = Instance.new("TextLabel")
	cap.Name = "CapacityLabel"
	cap.Parent = footer

	return screen
end

local function testGiveSlingAddsAndRenders()
	ensureAssetTemplates()
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local inventoryGui = buildInventoryGui()
	inventoryGui.Parent = playerGui

	local provider = InventoryDataProvider.new()
	local controller = InventoryUIController.new(playerGui :: any)
	controller:SetDataProvider(provider)
	controller:Start()

	provider:GiveTestSling()
	provider:GiveTestSling()
	local snapshot = provider:GetSnapshot()
	controller:RefreshWithData(snapshot)

	if #snapshot.ownedSlings < 2 then
		error("GiveSling must add at least 2 slings after 2 clicks")
	end
	local spawnedSlingSlots = (controller :: any)._spawnedSlingSlots
	if #spawnedSlingSlots < 2 then
		error("Sling slots must render at least 2 entries")
	end

	print(string.format("[InventorySystemTests] Rendered sling slots=%d", #spawnedSlingSlots))
	controller:Destroy()
	provider:Destroy()
	playerGui:Destroy()
end

local function testMockInventoryLoadsAndUsesTemplates()
	ensureAssetTemplates()
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local inventoryGui = buildInventoryGui()
	inventoryGui.Parent = playerGui

	local itemsGrid = inventoryGui.Root.BodyItems.GridContainer
	local staticItemSlot = Instance.new("Frame")
	staticItemSlot.Name = "Slot1"
	staticItemSlot.Parent = itemsGrid
	local slingsGrid = inventoryGui.Root.BodySling.GridContainer
	local staticSlingSlot = Instance.new("Frame")
	staticSlingSlot.Name = "Slot1"
	staticSlingSlot.Parent = slingsGrid

	local provider = InventoryDataProvider.new()
	provider:LoadMockInventory()
	local snapshot = provider:GetSnapshot()
	local mockSnapshot = MockData.GetInventoryState()

	if #snapshot.ownedSlings ~= #mockSnapshot.OwnedSlings then
		error("Provider mock sling count must match mock data source")
	end
	if (snapshot.ownedItems.gacha_ticket or 0) ~= 100 then
		error("Mock data must include 100 gacha tickets")
	end

	local controller = InventoryUIController.new(playerGui :: any)
	controller:SetDataProvider(provider)
	controller:Start()
	controller:RefreshWithData(snapshot)

	if itemsGrid:FindFirstChild("Slot1") or slingsGrid:FindFirstChild("Slot1") then
		error("Inventory grids should clear pre-existing slots and use cloned templates only")
	end

	controller:Destroy()
	provider:Destroy()
	playerGui:Destroy()
end

runTest("GiveSling button behavior adds slings and renders slots", testGiveSlingAddsAndRenders)
runTest("Mock inventory loads and replaces static slots", testMockInventoryLoadsAndUsesTemplates)
