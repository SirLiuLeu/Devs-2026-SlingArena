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
		local itemRoot = Instance.new("Frame")
		itemRoot.Name = "Root"
		itemRoot.Parent = itemTemplate
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Parent = itemRoot
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Parent = itemRoot
		local quantity = Instance.new("TextLabel")
		quantity.Name = "Quantity"
		quantity.Parent = itemRoot
		itemTemplate.Parent = ui
	end

	local launcherTemplate = ui:FindFirstChild("LauncherSlotTemplate_InventoryUI")
	if not launcherTemplate then
		launcherTemplate = Instance.new("Frame")
		launcherTemplate.Name = "LauncherSlotTemplate_InventoryUI"
		local launcherRoot = Instance.new("Frame")
		launcherRoot.Name = "Root"
		launcherRoot.Parent = launcherTemplate
		local stars = Instance.new("Frame")
		stars.Name = "Stars"
		stars.Parent = launcherRoot
		for starIndex = 1, 5 do
			local star = Instance.new("ImageLabel")
			star.Name = "Star" .. starIndex
			star.Parent = stars
		end
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Parent = launcherRoot
		local equippedTag = Instance.new("TextLabel")
		equippedTag.Name = "EquippedTag"
		equippedTag.Parent = launcherRoot
		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.Parent = launcherRoot
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Parent = launcherRoot
		launcherTemplate.Parent = ui
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
	local launcherTab = Instance.new("TextButton")
	launcherTab.Name = "LauncherTab"
	launcherTab.Parent = tabs

	local bodyItems = Instance.new("Frame")
	bodyItems.Name = "BodyItems"
	bodyItems.Parent = root
	local itemsGrid = Instance.new("ScrollingFrame")
	itemsGrid.Name = "GridContainer"
	itemsGrid.Parent = bodyItems

	local bodyLauncher = Instance.new("Frame")
	bodyLauncher.Name = "BodyLauncher"
	bodyLauncher.Parent = root
	local launcherGrid = Instance.new("ScrollingFrame")
	launcherGrid.Name = "GridContainer"
	launcherGrid.Parent = bodyLauncher
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Parent = bodyLauncher
	local cap = Instance.new("TextLabel")
	cap.Name = "CapacityLabel"
	cap.Parent = footer

	return screen
end

local function testGiveLauncherAddsAndRenders()
	ensureAssetTemplates()
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local inventoryGui = buildInventoryGui()
	inventoryGui.Parent = playerGui

	local provider = InventoryDataProvider.new()
	local controller = InventoryUIController.new(playerGui :: any)
	controller:SetDataProvider(provider)
	controller:Start()

	provider:GiveTestLauncher()
	provider:GiveTestLauncher()
	local snapshot = provider:GetSnapshot()
	controller:RefreshWithData(snapshot)

	if #snapshot.ownedLaunchers < 2 then
		error("GiveLauncher must add at least 2 launchers after 2 clicks")
	end
	local spawnedLauncherSlots = (controller :: any)._spawnedLauncherSlots
	if #spawnedLauncherSlots < 2 then
		error("Launcher slots must render at least 2 entries")
	end
	local firstSlot = spawnedLauncherSlots[1]
	if firstSlot.Name:sub(1, 15) ~= "GeneratedLauncher_" then
		error("Launcher slot must be a cloned generated LauncherSlotTemplate_InventoryUI entry")
	end
	local root = firstSlot:FindFirstChild("Root")
	if not root or not root:FindFirstChild("Stars") or not root:FindFirstChild("Icon") or not root:FindFirstChild("EquippedTag") or not root:FindFirstChild("Level") or not root:FindFirstChild("Name") then
		error("Generated launcher slot must preserve LauncherSlotTemplate_InventoryUI/Root hierarchy")
	end

	print(string.format("[InventorySystemTests] Rendered launcher slots=%d", #spawnedLauncherSlots))
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
	local launchersGrid = inventoryGui.Root.BodyLauncher.GridContainer
	local staticLauncherSlot = Instance.new("Frame")
	staticLauncherSlot.Name = "Slot1"
	staticLauncherSlot.Parent = launchersGrid

	local provider = InventoryDataProvider.new()
	provider:LoadMockInventory()
	local snapshot = provider:GetSnapshot()
	local mockSnapshot = MockData.GetInventoryState()

	local mockLauncherCount = 0
	for _ in pairs(mockSnapshot.OwnedLaunchers) do
		mockLauncherCount += 1
	end
	if #snapshot.ownedLaunchers ~= mockLauncherCount then
		error("Provider mock launcher count must match mock data source")
	end
	if (snapshot.ownedItems.gacha_ticket or 0) ~= 100 then
		error("Mock data must include 100 gacha tickets")
	end

	local controller = InventoryUIController.new(playerGui :: any)
	controller:SetDataProvider(provider)
	controller:Start()
	controller:RefreshWithData(snapshot)

	if itemsGrid:FindFirstChild("Slot1") or launchersGrid:FindFirstChild("Slot1") then
		error("Inventory grids should clear pre-existing slots and use cloned templates only")
	end

	controller:Destroy()
	provider:Destroy()
	playerGui:Destroy()
end

runTest("GiveLauncher button behavior adds launchers and renders slots", testGiveLauncherAddsAndRenders)
runTest("Mock inventory loads and replaces static slots", testMockInventoryLoadsAndUsesTemplates)
