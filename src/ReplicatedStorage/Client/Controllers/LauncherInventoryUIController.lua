--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local LauncherInventoryUIController = {}
LauncherInventoryUIController.__index = LauncherInventoryUIController

local TEMPLATE_NAME = "LauncherSlotTemplate_InventoryUI"

local function resolve(root: Instance, path: string, className: string): Instance?
	local value = PathResolver.resolvePath(root, path)
	return value and value:IsA(className) and value or nil
end

local function label(root: Instance, name: string): TextLabel?
	local value = root:FindFirstChild(name, true)
	return value and value:IsA("TextLabel") and value or nil
end

local function slotRoot(slot: Instance): GuiObject?
	local root = slot:FindFirstChild("Root")
	return root and root:IsA("GuiObject") and root or nil
end

function LauncherInventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {}, _slotConnections = {}, _slots = {}, _selected = nil }, LauncherInventoryUIController)
end
function LauncherInventoryUIController:SetDataProvider(provider) self._provider = provider end
function LauncherInventoryUIController:SetConfirmationController(controller) self._confirmation = controller end

function LauncherInventoryUIController:Start(uiReadySignal: BindableEvent?)
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then uiReadySignal.Event:Wait() end
	self._gui = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ScreenGui, "ScreenGui") :: ScreenGui?
	self._grid = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.GridContainer, "GuiObject") :: GuiObject?
	self._capacity = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CapacityLabel, "TextLabel") :: TextLabel?
	self._name = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.SelectedName, "TextLabel") :: TextLabel?
	self._level = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Level, "TextLabel") :: TextLabel?
	self._stats = {
		resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.StatDamage, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.StatHP, "TextLabel"),
		resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.StatRange, "TextLabel"), resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.StatRegen, "TextLabel"),
	}
	self._equip = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.EquipButton, "TextButton") :: TextButton?
	self._delete = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.DeleteButton, "TextButton") :: TextButton?
	local assets = ReplicatedStorage:WaitForChild("Assets"); local ui = assets:FindFirstChild("UI")
	self._template = ui and ui:FindFirstChild(TEMPLATE_NAME) :: GuiObject?
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._equipRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
	self._unequipRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipLauncher) :: RemoteEvent?
	if self._equip then table.insert(self._connections, self._equip.MouseButton1Click:Connect(function()
		if not (self._selected and self:_inLobby()) then return end
		if self._selected.equipped then if self._unequipRemote then self._unequipRemote:FireServer() end elseif self._equipRemote then self._equipRemote:FireServer(self._selected.instanceId) end
	end)) end
	if self._delete then table.insert(self._connections, self._delete.MouseButton1Click:Connect(function()
		if not self._selected or not self._unequipRemote then return end
		local function unequip() self._unequipRemote:FireServer() end
		if self._confirmation then self._confirmation:RequestConfirm("Unequip this launcher?", unequip) else unequip() end
	end)) end
	if self._provider then
		self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end)
		self:Render(self._provider:GetSnapshot())
	end
	self:SetVisible(false)
end

function LauncherInventoryUIController:_inLobby(): boolean
	local state = Players.LocalPlayer:GetAttribute("LocationState")
	return state == nil or state == "Lobby"
end
function LauncherInventoryUIController:SetVisible(value: boolean) if self._gui then self._gui.Enabled = value end end

function LauncherInventoryUIController:_bindSlot(slot: GuiObject, entry: any)
	local old = self._slotConnections[slot]; if old then old:Disconnect() end
	local target = (slot:FindFirstChildWhichIsA("TextButton", true) :: GuiObject?) or slot
	self._slotConnections[slot] = target.MouseButton1Click:Connect(function() self._selected = entry; self:_refreshPanel() end)
end

function LauncherInventoryUIController:_updateSlot(slot: GuiObject, entry: any)
	local root = slotRoot(slot); local definition = LauncherConfig.GetById(entry.id or entry.definitionId or "")
	if not root or not definition then return end
	local name, level, equipped = label(root, "Name"), label(root, "Level"), label(root, "EquippedTag")
	if name then name.Text = entry.name or definition.name end
	if level then level.Text = "Lv." .. tostring(math.max(1, math.floor(entry.level or 1))) end
	if equipped then equipped.Visible = entry.equipped == true end
	local icon = root:FindFirstChild("Icon", true); if icon and icon:IsA("ImageLabel") then icon.Image = entry.icon or definition.iconId end
	local stars = root:FindFirstChild("Stars"); if stars then for index = 1, 5 do local star = stars:FindFirstChild("Star" .. index); if star and star:IsA("GuiObject") then star.Visible = index <= math.clamp(math.floor(entry.star or 1), 1, 5) end end end
	self:_bindSlot(slot, entry)
end

function LauncherInventoryUIController:_refreshPanel()
	local entry = self._selected; local definition = entry and LauncherConfig.GetById(entry.id or entry.definitionId or "") or nil
	if self._name then self._name.Text = entry and (entry.name or (definition and definition.name)) or "No launcher selected" end
	if self._level then self._level.Text = entry and ("Lv." .. tostring(entry.level or 1)) or "Lv.-" end
	local stats = entry and entry.stats or (definition and definition.stats) or {}
	local names = { "Damage", "HP", "Range", "Regen" }; local values = { stats.damage or stats.launchPower or 0, stats.hp or 0, stats.range or stats.control or 0, stats.regen or 0 }
	for index, stat in ipairs(self._stats) do if stat and stat:IsA("TextLabel") then stat.Text = string.format("%s: %s", names[index], tostring(values[index])) end end
	if self._equip then local enabled = entry ~= nil and self:_inLobby(); self._equip.Text = entry and entry.equipped and "Unequip" or "Equip"; self._equip.Active = enabled; self._equip.AutoButtonColor = enabled end
end

function LauncherInventoryUIController:Render(snapshot)
	if not self._grid or not (self._template and self._template:IsA("GuiObject")) then return end
	local seen = {}
	for _, entry in ipairs(snapshot.ownedLaunchers or {}) do
		local id = tostring(entry.instanceId or entry.id or "")
		if id ~= "" then
			seen[id] = true; local slot = self._slots[id]
			if not (slot and slot.Parent) then slot = self._template:Clone(); slot.Name = "GeneratedLauncher_" .. id; slot.Parent = self._grid; self._slots[id] = slot end
			slot.Visible = true; self:_updateSlot(slot, entry)
		end
	end
	for id, slot in pairs(self._slots) do if not seen[id] then local connection = self._slotConnections[slot]; if connection then connection:Disconnect() end; self._slotConnections[slot] = nil; if slot.Parent then slot:Destroy() end; self._slots[id] = nil end end
	if self._capacity then self._capacity.Text = string.format("%d/%d", #(snapshot.ownedLaunchers or {}), snapshot.launcherCapacity or 40) end
	if self._selected then
		local selectedId = self._selected.instanceId or self._selected.id
		for _, entry in ipairs(snapshot.ownedLaunchers or {}) do if entry.instanceId == selectedId or entry.id == selectedId then self._selected = entry; break end end
	end
	self:_refreshPanel()
end

function LauncherInventoryUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for _, connection in pairs(self._slotConnections) do connection:Disconnect() end
	if self._providerConnection then self._providerConnection:Disconnect() end
end
return LauncherInventoryUIController
