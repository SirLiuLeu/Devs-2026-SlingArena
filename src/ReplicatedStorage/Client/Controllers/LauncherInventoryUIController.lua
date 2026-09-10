--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)

local LauncherInventoryUIController = {}
LauncherInventoryUIController.__index = LauncherInventoryUIController

local LAUNCHER_SLOT_TEMPLATE_NAME = "LauncherSlotTemplate_LauncherInventoryUI"

local function resolveGui(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path)
	return if value and value:IsA("GuiObject") then value else nil
end

local function resolveText(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path)
	return if value and value:IsA("TextLabel") then value else nil
end

local function resolveButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	return if value and value:IsA("TextButton") then value else nil
end

local function getSlotRoot(slot: Instance): GuiObject?
	local root = slot:FindFirstChild("Root")
	return if root and root:IsA("GuiObject") then root else nil
end

local function findText(root: Instance, name: string): TextLabel?
	local value = root:FindFirstChild(name, true)
	return if value and value:IsA("TextLabel") then value else nil
end

function LauncherInventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {}, _slotConnections = {}, _slotMap = {}, _selected = nil }, LauncherInventoryUIController)
end

function LauncherInventoryUIController:SetDataProvider(provider)
	self._provider = provider
end

function LauncherInventoryUIController:SetConfirmationController(controller)
	self._confirmation = controller
end

function LauncherInventoryUIController:Start(uiReadySignal: BindableEvent?)
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then
		uiReadySignal.Event:Wait()
	end

	self._gui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ScreenGui) :: ScreenGui?
	self._grid = resolveGui(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.GridContainer)
	self._capacity = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CapacityLabel)
	self._name = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.SelectedName)
	self._damage = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.Damage)
	self._hp = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.HP)
	self._range = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.Range)
	self._regen = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.Regen)
	self._equip = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.EquipButton)
	self._delete = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.DeleteButton)

	local assets = ReplicatedStorage:WaitForChild("Assets")
	self._launcherAssets = assets:FindFirstChild("Launchers")
	local uiFolder = assets:FindFirstChild("UI")
	local template = uiFolder and uiFolder:FindFirstChild(LAUNCHER_SLOT_TEMPLATE_NAME)
	self._template = if template and template:IsA("GuiObject") then template else nil
	if not self._template then
		warn("[LAUNCHER_INVENTORY_UI] " .. LAUNCHER_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
		self._template = nil
	end
	if not self._launcherAssets then
		warn("[LAUNCHER_INVENTORY_UI] ReplicatedStorage.Assets.Launchers missing")
	end

	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._equipRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
	self._unequipRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipLauncher) :: RemoteEvent?
	if self._equip then
		table.insert(self._connections, self._equip.MouseButton1Click:Connect(function()
			if self:_inLobby() and self._selected and self._equipRemote then
				self._equipRemote:FireServer(self._selected.instanceId)
			end
		end))
	end
	if self._delete then
		table.insert(self._connections, self._delete.MouseButton1Click:Connect(function()
			if self._selected and self._confirmation then
				self._confirmation:RequestConfirm("Unequip this launcher?", function()
					if self._unequipRemote then self._unequipRemote:FireServer() end
				end)
			end
		end))
	end
	if self._provider then
		self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end)
		self._latestSnapshot = self._provider:GetSnapshot()
	end
	self:SetVisible(false)
end

function LauncherInventoryUIController:_inLobby(): boolean
	return Players.LocalPlayer:GetAttribute("LocationState") == nil or Players.LocalPlayer:GetAttribute("LocationState") == "Lobby"
end

function LauncherInventoryUIController:SetVisible(value: boolean)
	if self._gui then
		self._gui.Enabled = value
		if value and self._latestSnapshot then
			self:Render(self._latestSnapshot)
		end
	end
end

function LauncherInventoryUIController:_entryKey(entry): string
	return tostring(entry.instanceId or entry.id or "")
end

function LauncherInventoryUIController:_bindSlot(slot: GuiObject, entry)
	local connection = slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._selected = entry
			if self._provider then self._provider:SelectLauncher(self:_entryKey(entry)) end
			self:_refreshRightPanel()
			self:_refreshSlotVisuals()
		end
	end)
	self._slotConnections[slot] = connection
end

function LauncherInventoryUIController:_updateSlot(slot: GuiObject, entry)
	local root = getSlotRoot(slot)
	local definition = LauncherConfig.GetById(entry.id)
	slot.Name = "GeneratedLauncher_" .. self:_entryKey(entry)
	if not root then
		warn("[LAUNCHER_INVENTORY_UI] Launcher slot is missing Root GuiObject")
	else
		if not definition then
			warn(string.format("[LAUNCHER_INVENTORY_UI] Launcher definition missing for %q", tostring(entry.id)))
		end

		local name = findText(root, "Name")
		if name then name.Text = entry.name or (definition and definition.name) or "Unknown launcher" end
		local level = math.max(1, math.floor(tonumber(entry.level) or 1))
		local levelText = findText(root, "Level")
		if levelText then levelText.Text = string.format("Lv.%d", level) end
		local equipped = findText(root, "EquippedTag")
		if equipped then equipped.Visible = entry.equipped == true end
		local stars = root:FindFirstChild("Stars")
		if stars then
			for index = 1, 5 do
				local star = stars:FindFirstChild("Star" .. index)
				if star and star:IsA("GuiObject") then star.Visible = index <= math.clamp(level, 1, 5) end
			end
		end

		local equipmentPreviewViewport = root:FindFirstChild("EquipmentPreview")
		if equipmentPreviewViewport and equipmentPreviewViewport:IsA("ViewportFrame") then
			if slot:GetAttribute("CurrentRenderedId") ~= entry.id then
				PreviewRenderer.Populate(equipmentPreviewViewport, self._launcherAssets, entry.id)
				slot:SetAttribute("CurrentRenderedId", entry.id)
			end
		else
			warn("[LAUNCHER_INVENTORY_UI] LauncherSlotTemplate_LauncherInventoryUI.Root.EquipmentPreview ViewportFrame missing; create it in Studio")
		end
	end
end

function LauncherInventoryUIController:_spawnSlot(entry)
	if not self._grid or not self._template then return end
	local slot = self._template:Clone()
	slot.Visible = true
	slot.Parent = self._grid
	self:_updateSlot(slot, entry)
	self:_bindSlot(slot, entry)
	self._slotMap[self:_entryKey(entry)] = slot
end

function LauncherInventoryUIController:_refreshSlotVisuals()
	for key, slot in pairs(self._slotMap) do
		if slot.Parent then
			slot.BackgroundTransparency = if self._selected and key == self:_entryKey(self._selected) then 0 else 0.2
		end
	end
end

function LauncherInventoryUIController:_refreshRightPanel()
	local entry = self._selected
	local definition = entry and LauncherConfig.GetById(entry.id) or nil
	local stats = entry and entry.stats or nil
	if self._name then self._name.Text = (entry and (entry.name or (definition and definition.name))) or "No launcher selected" end
	if self._damage then self._damage.Text = string.format("Damage: %.2f", (stats and stats.damage) or (definition and definition.stats.launchPower) or 0) end
	if self._hp then self._hp.Text = string.format("HP: %.0f", (stats and stats.hp) or 0) end
	if self._range then self._range.Text = string.format("Range: %.2f", (stats and stats.range) or (definition and definition.stats.control) or 0) end
	if self._regen then self._regen.Text = string.format("Regen: %.2f", (stats and stats.regen) or 0) end
	local enabled = self:_inLobby() and entry ~= nil
	if self._equip then
		self._equip.Active = enabled
		self._equip.AutoButtonColor = enabled
		self._equip.TextTransparency = if enabled then 0 else 0.5
	end
end

function LauncherInventoryUIController:Render(snapshot)
	self._latestSnapshot = snapshot
	if self._gui and self._gui.Enabled == false then return end
	if not self._grid then return end
	local seen = {}
	for _, entry in ipairs(snapshot.ownedLaunchers or {}) do
		local key = self:_entryKey(entry)
		if key ~= "" then
			seen[key] = true
			local slot = self._slotMap[key]
			if slot and slot.Parent then self:_updateSlot(slot, entry) else self:_spawnSlot(entry) end
			if self._selected and self:_entryKey(self._selected) == key then self._selected = entry end
		end
	end
	for key, slot in pairs(self._slotMap) do
		if not seen[key] then
			local connection = self._slotConnections[slot]
			if connection then connection:Disconnect(); self._slotConnections[slot] = nil end
			if slot.Parent then slot:Destroy() end
			self._slotMap[key] = nil
			if self._selected and self:_entryKey(self._selected) == key then self._selected = nil end
		end
	end
	if self._capacity then self._capacity.Text = string.format("Capacity: %d/%d", #(snapshot.ownedLaunchers or {}), snapshot.launcherCapacity or 0) end
	self:_refreshRightPanel()
	self:_refreshSlotVisuals()
end

function LauncherInventoryUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for _, connection in pairs(self._slotConnections) do connection:Disconnect() end
	if self._providerConnection then self._providerConnection:Disconnect() end
	for key, slot in pairs(self._slotMap) do
		if slot then slot:Destroy() end
		self._slotMap[key] = nil
	end
	table.clear(self._slotConnections)
end

return LauncherInventoryUIController
