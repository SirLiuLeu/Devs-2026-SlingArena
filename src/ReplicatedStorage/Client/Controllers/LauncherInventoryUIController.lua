--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)

local LauncherInventoryUIController = {}
LauncherInventoryUIController.__index = LauncherInventoryUIController

local function resolve(root: Instance, path: string, className: string): Instance?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return value and value:IsA(className) and value or nil
end

function LauncherInventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {}, _selectedId = nil }, LauncherInventoryUIController)
end

function LauncherInventoryUIController:SetDataProvider(provider) self._provider = provider end
function LauncherInventoryUIController:SetConfirmationController(controller) self._confirmation = controller end
function LauncherInventoryUIController:_inLobby(): boolean
	local state = Players.LocalPlayer:GetAttribute("LocationState")
	return state == nil or state == "Lobby"
end

function LauncherInventoryUIController:Start()
	self._gui = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ScreenGui, "ScreenGui") :: ScreenGui?
	self._grid = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.GridContainer, "GuiObject") :: GuiObject?
	self._name = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.SelectedName, "TextLabel") :: TextLabel?
	self._capacity = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CapacityLabel, "TextLabel") :: TextLabel?
	self._toggleEquip = resolve(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ToggleEquipButton, "TextButton") :: TextButton?
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._equipRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
	self._unequipRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipLauncher) :: RemoteEvent?
	if self._toggleEquip then
		table.insert(self._connections, self._toggleEquip.MouseButton1Click:Connect(function()
			local entry = self:_selectedEntry()
			if not entry or not self:_inLobby() then return end
			if entry.equipped then
				MockPlayerData.UnequipLauncher("LauncherUnequipped")
				if self._unequipRemote then self._unequipRemote:FireServer() end
			else
				MockPlayerData.EquipLauncher(entry.instanceId, "LauncherEquipped")
				if self._equipRemote then self._equipRemote:FireServer(entry.instanceId) end
			end
		end))
	end
	if self._provider then
		self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end)
		self:Render(self._provider:GetSnapshot())
	end
	self:SetVisible(false)
end

function LauncherInventoryUIController:_selectedEntry()
	for _, entry in ipairs((self._snapshot and self._snapshot.ownedLaunchers) or {}) do
		if entry.instanceId == self._selectedId then return entry end
	end
	return nil
end

function LauncherInventoryUIController:SetVisible(value: boolean)
	if self._gui then self._gui.Enabled = value end
end

function LauncherInventoryUIController:_refreshToggle()
	local entry = self:_selectedEntry()
	if self._toggleEquip then
		local enabled = entry ~= nil and self:_inLobby()
		self._toggleEquip.Active = enabled
		self._toggleEquip.AutoButtonColor = enabled
		self._toggleEquip.TextTransparency = enabled and 0 or 0.5
		self._toggleEquip.Text = entry and entry.equipped and "Unequip" or "Equip"
	end
	if self._name then self._name.Text = entry and (entry.name or entry.id) or "No launcher selected" end
end

function LauncherInventoryUIController:Render(snapshot)
	self._snapshot = snapshot
	if not self._grid then return end
	for _, child in ipairs(self._grid:GetChildren()) do
		if child.Name:sub(1, 18) == "GeneratedLauncher_" then child:Destroy() end
	end
	local entries = snapshot.ownedLaunchers or {}
	if self._capacity then self._capacity.Text = string.format("Capacity: %d/%d", #entries, snapshot.launcherCapacity or 0) end
	for _, entry in ipairs(entries) do
		local button = Instance.new("TextButton")
		button.Name = "GeneratedLauncher_" .. tostring(entry.instanceId)
		button.Size = UDim2.fromOffset(160, 42)
		button.Text = string.format("%s  Lv.%d", entry.name or entry.id, entry.level or 1)
		button.Parent = self._grid
		table.insert(self._connections, button.MouseButton1Click:Connect(function()
			self._selectedId = entry.instanceId
			self:_refreshToggle()
		end))
	end
	if not self:_selectedEntry() then self._selectedId = entries[1] and entries[1].instanceId or nil end
	self:_refreshToggle()
end

function LauncherInventoryUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	if self._providerConnection then self._providerConnection:Disconnect() end
end
return LauncherInventoryUIController
