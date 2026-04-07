--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryDataProvider = require(ReplicatedStorage.Client.Services.InventoryDataProvider)
local InventoryUIController = require(ReplicatedStorage.Client.Controllers.InventoryUIController)

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

	local itemTemplate = ui:FindFirstChild("ItemSlotTemplate")
	if not itemTemplate then
		itemTemplate = Instance.new("Frame")
		itemTemplate.Name = "ItemSlotTemplate"
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

	local slingTemplate = ui:FindFirstChild("SlingsSlotTemplate")
	if not slingTemplate then
		slingTemplate = Instance.new("Frame")
		slingTemplate.Name = "SlingsSlotTemplate"
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
	local mainHub = Instance.new("Frame")
	mainHub.Name = "MainHub"
	mainHub.Parent = screen

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Parent = mainHub
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Parent = header

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Parent = mainHub
	local itemsTab = Instance.new("TextButton")
	itemsTab.Name = "ItemsTab"
	itemsTab.Parent = tabs
	local slingTab = Instance.new("TextButton")
	slingTab.Name = "SlingTab"
	slingTab.Parent = tabs

	local bodyItems = Instance.new("Frame")
	bodyItems.Name = "BodyItems"
	bodyItems.Parent = mainHub
	local itemsGrid = Instance.new("Frame")
	itemsGrid.Name = "GridContainer"
	itemsGrid.Parent = bodyItems

	local bodySling = Instance.new("Frame")
	bodySling.Name = "BodySling"
	bodySling.Parent = mainHub
	local slingGrid = Instance.new("Frame")
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

runTest("GiveSling button behavior adds slings and renders slots", testGiveSlingAddsAndRenders)
