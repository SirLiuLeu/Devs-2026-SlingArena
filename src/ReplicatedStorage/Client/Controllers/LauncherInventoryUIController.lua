--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local LauncherInventoryUIController = {}
LauncherInventoryUIController.__index = LauncherInventoryUIController

function LauncherInventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {}, _selected = nil }, LauncherInventoryUIController)
end
function LauncherInventoryUIController:SetDataProvider(provider) self._provider = provider end
function LauncherInventoryUIController:SetConfirmationController(controller) self._confirmation = controller end
function LauncherInventoryUIController:Start()
	self._gui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ScreenGui) :: ScreenGui?
	self._grid = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.GridContainer) :: GuiObject?
	self._name = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.SelectedName) :: TextLabel?
	self._equip = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.EquipButton) :: TextButton?
	self._delete = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.DeleteButton) :: TextButton?
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._equipRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
	self._unequipRemote = remotes:FindFirstChild(RemoteContracts.Names.UnequipLauncher) :: RemoteEvent?
	if self._equip then table.insert(self._connections, self._equip.MouseButton1Click:Connect(function()
		if self:_inLobby() and self._selected and self._equipRemote then self._equipRemote:FireServer(self._selected.instanceId) end
	end)) end
	if self._delete then table.insert(self._connections, self._delete.MouseButton1Click:Connect(function()
		if self._selected and self._confirmation then self._confirmation:RequestConfirm("Delete this launcher?", function() if self._unequipRemote then self._unequipRemote:FireServer() end end) end
	end)) end
	if self._provider then self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end); self:Render(self._provider:GetSnapshot()) end
	self:SetVisible(false)
end
function LauncherInventoryUIController:_inLobby(): boolean return Players.LocalPlayer:GetAttribute("LocationState") == nil or Players.LocalPlayer:GetAttribute("LocationState") == "Lobby" end
function LauncherInventoryUIController:SetVisible(value: boolean) if self._gui then self._gui.Enabled = value end end
function LauncherInventoryUIController:Render(snapshot)
	if not self._grid then return end
	for _, child in ipairs(self._grid:GetChildren()) do if child.Name:sub(1, 18) == "GeneratedLauncher_" then child:Destroy() end end
	for _, entry in ipairs(snapshot.ownedLaunchers or {}) do
		local button = Instance.new("TextButton"); button.Name = "GeneratedLauncher_" .. entry.instanceId; button.Size = UDim2.fromOffset(160, 42); button.Text = string.format("%s  Lv.%d", entry.name or entry.id, entry.level or 1); button.Parent = self._grid
		button.MouseButton1Click:Connect(function() self._selected = entry; if self._name then self._name.Text = entry.name or entry.id end; self:_updateEquipEnabled() end)
	end
	self:_updateEquipEnabled()
end
function LauncherInventoryUIController:_updateEquipEnabled()
	if self._equip then local enabled = self:_inLobby() and self._selected ~= nil; self._equip.Active = enabled; self._equip.AutoButtonColor = enabled; self._equip.TextTransparency = enabled and 0 or .5 end
end
function LauncherInventoryUIController:Destroy() for _, c in ipairs(self._connections) do c:Disconnect() end; if self._providerConnection then self._providerConnection:Disconnect() end end
return LauncherInventoryUIController
