--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamConfig = require(ReplicatedStorage.Shared.Config.TeamConfig)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local TeamSelectionUIController = {}
TeamSelectionUIController.__index = TeamSelectionUIController

local function warnMissing(path: string)
	warn(string.format("[TEAM_SELECTION_UI] Missing %s. Create the UI in Studio using ProjectTreeSpec.lua.", path))
end

local function getTeamId(item: Instance, button: TextButton): string?
	if TeamConfig.TeamIdSet[button.Name] then return button.Name end
	local label = item:FindFirstChild("TeamName", true)
	local candidate = if label and label:IsA("TextLabel") then label.Text else button.Text
	return if TeamConfig.TeamIdSet[candidate] then candidate else nil
end

function TeamSelectionUIController.new(playerGui: PlayerGui)
	return setmetatable({
		_playerGui = playerGui,
		_connections = {},
		_teamConnections = {},
		_teamButtons = {},
	}, TeamSelectionUIController)
end

function TeamSelectionUIController:Start()
	local ui = ProjectTreeSpec.UI.TeamSelection
	self._gui = PathResolver.resolvePath(self._playerGui, ui.ScreenGui) :: ScreenGui?
	self._toggle = PathResolver.resolvePath(self._playerGui, ui.ToggleButton)
	self._popup = PathResolver.resolvePath(self._playerGui, ui.PopupFrame)
	if not self._gui then warnMissing("StarterGui.TeamSelectionGui (ScreenGui)") end
	if not (self._toggle and self._toggle:IsA("GuiButton")) then warnMissing("TeamSelectionGui.ToggleBtn (GuiButton)") end
	if not (self._popup and self._popup:IsA("GuiObject")) then warnMissing("TeamSelectionGui.TeamPopupFrame (Frame)") end
	if self._popup and self._popup:IsA("GuiObject") then self._popup.Visible = false end
	if self._toggle and self._toggle:IsA("GuiButton") and self._popup and self._popup:IsA("GuiObject") then
		table.insert(self._connections, self._toggle.Activated:Connect(function()
			self._popup.Visible = not self._popup.Visible
		end))
	end

	local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	self._changeTeamRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.ChangeTeam) :: RemoteEvent?
	self._feedbackRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if not self._changeTeamRemote then warnMissing("ReplicatedStorage.LauncherArenaRemotes.ChangeTeam (RemoteEvent)") end
	if self._popup then
		for _, item in ipairs(self._popup:GetChildren()) do
			if not item:IsA("GuiObject") or item.Name == "UIListLayout" or item.Name == "UIGridLayout" or item.Name == "UIPadding" then continue end
			local button = item:FindFirstChildWhichIsA("TextButton", true)
			if not button then continue end
			local teamId = getTeamId(item, button)
			if not teamId then
				warn(string.format("[TEAM_SELECTION_UI] Could not resolve team ID for %s; button ignored.", item:GetFullName()))
				continue
			end
			self._teamButtons[teamId] = { item = item, button = button }
			table.insert(self._connections, button.Activated:Connect(function()
				if self._changeTeamRemote then self._changeTeamRemote:FireServer(teamId) end
			end))
		end
	end
	if self._feedbackRemote then
		table.insert(self._connections, self._feedbackRemote.OnClientEvent:Connect(function(message)
			if type(message) == "table" and message.EventType == "TeamChangeResult"
				and type(message.Payload) == "table" and message.Payload.Success == true
				and self._popup and self._popup:IsA("GuiObject") then
				self._popup.Visible = false
			end
		end))
	end
	for _, team in ipairs(Teams:GetTeams()) do self:_watchTeam(team) end
	table.insert(self._connections, Teams.ChildAdded:Connect(function(child)
		if child:IsA("Team") then self:_watchTeam(child); self:_refreshCounts() end
	end))
	table.insert(self._connections, Teams.ChildRemoved:Connect(function() self:_refreshCounts() end))
	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		table.insert(self._connections, player:GetPropertyChangedSignal("Team"):Connect(function() self:_refreshCounts() end))
		self:_refreshCounts()
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(self._connections, player:GetPropertyChangedSignal("Team"):Connect(function() self:_refreshCounts() end))
	end
	self:_refreshCounts()
end

function TeamSelectionUIController:_watchTeam(team: Team)
	if self._teamConnections[team] then return end
	self._teamConnections[team] = {
		team.PlayerAdded:Connect(function() self:_refreshCounts() end),
		team.PlayerRemoved:Connect(function() self:_refreshCounts() end),
	}
end

function TeamSelectionUIController:_refreshCounts()
	for teamId, entry in pairs(self._teamButtons) do
		local countLabel = entry.item:FindFirstChild("PlayerCount", true)
		if countLabel and countLabel:IsA("TextLabel") then
			local team = Teams:FindFirstChild(teamId)
			local count = if team and team:IsA("Team") then #team:GetPlayers() else 0
			countLabel.Text = string.format("%d/%d", count, TeamConfig.MaxPlayersPerTeam)
		end
	end
end

function TeamSelectionUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for _, connections in pairs(self._teamConnections) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end
	table.clear(self._connections)
	table.clear(self._teamConnections)
end

return TeamSelectionUIController
