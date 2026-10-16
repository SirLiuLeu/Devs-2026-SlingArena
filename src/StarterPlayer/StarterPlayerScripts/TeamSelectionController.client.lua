--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TeamConfig = require(ReplicatedStorage.Shared.Config.TeamConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
local changeTeamRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.ChangeTeam)
local feedbackRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
if not (changeTeamRemote and changeTeamRemote:IsA("RemoteEvent")) then
	warn("[TeamSelectionController] Missing ReplicatedStorage.LauncherArenaRemotes.ChangeTeam (RemoteEvent). Create it manually.")
	changeTeamRemote = nil
end
if not (feedbackRemote and feedbackRemote:IsA("RemoteEvent")) then
	warn("[TeamSelectionController] Missing ReplicatedStorage.LauncherArenaRemotes.GameplayFeedback (RemoteEvent).")
	feedbackRemote = nil
end

local guiConnections: { RBXScriptConnection } = {}
local globalConnections: { RBXScriptConnection } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local toggleButton: GuiButton? = nil
local popup: Frame? = nil
local teamButtons: { [string]: GuiButton } = {}
local playerCountLabels: { [string]: TextLabel } = {}
local isRage = Workspace:GetAttribute("RageActive") == true

local function disconnectGuiConnections()
	for _, connection in ipairs(guiConnections) do connection:Disconnect() end
	table.clear(guiConnections)
	table.clear(teamButtons)
	table.clear(playerCountLabels)
end

local function findTeamId(instance: Instance, popupFrame: Frame): string?
	local current: Instance? = instance
	while current and current ~= popupFrame do
		if TeamConfig.IsTeamId(current.Name) then return current.Name end
		local nameLabel = current:FindFirstChild("TeamName", true)
		if nameLabel and nameLabel:IsA("TextLabel") and TeamConfig.IsTeamId(nameLabel.Text) then
			return nameLabel.Text
		end
		current = current.Parent
	end
	return nil
end

local function refreshCounts()
	local counts: { [string]: number } = {}
	for _, teamId in ipairs(TeamConfig.TeamIds) do counts[teamId] = 0 end
	for _, candidate in ipairs(Players:GetPlayers()) do
		local team = candidate.Team
		if team and counts[team.Name] ~= nil then counts[team.Name] += 1 end
	end
	for teamId, label in pairs(playerCountLabels) do
		if label.Parent then label.Text = string.format("%d/%d", counts[teamId] or 0, TeamConfig.MaxPlayersPerTeam) end
	end
end

local function refreshRageState()
	isRage = Workspace:GetAttribute("RageActive") == true
	if popup and isRage then popup.Visible = false end
	if toggleButton then
		toggleButton.Active = not isRage
		toggleButton.AutoButtonColor = not isRage
	end
	for _, button in pairs(teamButtons) do
		button.Active = not isRage
		button.AutoButtonColor = not isRage
	end
end

local function bindGui(candidate: Instance)
	if not candidate:IsA("ScreenGui") then
		warn("[TeamSelectionController] StarterGui.TeamSelectionGui must be a ScreenGui.")
		return
	end
	if screenGui == candidate then return end
	disconnectGuiConnections()
	screenGui = candidate

	local toggle = candidate:FindFirstChild("ToggleBtn", true)
	if toggle and toggle:IsA("GuiButton") then
		toggleButton = toggle
		table.insert(guiConnections, toggle.Activated:Connect(function()
			if not isRage and popup then popup.Visible = not popup.Visible end
		end))
	else
		toggleButton = nil
		warn("[TeamSelectionController] Missing StarterGui.TeamSelectionGui.ToggleBtn (ImageButton).")
	end

	local popupInstance = candidate:FindFirstChild("TeamPopupFrame", true)
	if popupInstance and popupInstance:IsA("Frame") then
		popup = popupInstance
		popup.Visible = false
		for _, descendant in ipairs(popup:GetDescendants()) do
			if descendant:IsA("GuiButton") then
				local teamId = if TeamConfig.IsTeamId(descendant.Name) then descendant.Name else nil
				if not teamId and descendant:IsA("TextButton") and TeamConfig.IsTeamId(descendant.Text) then
					teamId = descendant.Text
				end
				if not teamId then teamId = findTeamId(descendant, popup) end
				if teamId then
					teamButtons[teamId] = descendant
					local item: Instance? = descendant.Parent
					while item and item ~= popup do
						local nameLabel = item:FindFirstChild("TeamName", true)
						if nameLabel and nameLabel:IsA("TextLabel") then
							nameLabel.Text = teamId
							local icon = item:FindFirstChild("TeamIcon", true)
							local team = Teams:FindFirstChild(teamId)
							if icon and icon:IsA("ImageLabel") and team and team:IsA("Team") then
								icon.ImageColor3 = team.TeamColor.Color
							end
							break
						end
						item = item.Parent
					end
					table.insert(guiConnections, descendant.Activated:Connect(function()
						if isRage then return end
						if changeTeamRemote and changeTeamRemote:IsA("RemoteEvent") then
							changeTeamRemote:FireServer(teamId)
						else
							warn("[TeamSelectionController] ChangeTeam remote is unavailable.")
						end
						if popup then popup.Visible = false end
					end))
				end
			elseif descendant:IsA("TextLabel") and descendant.Name == "PlayerCount" then
				local teamId = findTeamId(descendant, popup)
				if teamId then playerCountLabels[teamId] = descendant end
			elseif descendant:IsA("TextLabel") and descendant.Name == "TeamName" then
				-- Keep the displayed team name consistent with the server's team IDs.
				local teamId = findTeamId(descendant.Parent or descendant, popup)
				if teamId then descendant.Text = teamId end
			end
		end
		for _, teamId in ipairs(TeamConfig.TeamIds) do
			if not teamButtons[teamId] then
				warn(string.format("[TeamSelectionController] Missing TextButton for team %s under TeamSelectionGui.TeamPopupFrame.<TeamItem>.", teamId))
			end
			if not playerCountLabels[teamId] then
				warn(string.format("[TeamSelectionController] Missing PlayerCount TextLabel for team %s under TeamSelectionGui.TeamPopupFrame.<TeamItem>.", teamId))
			end
		end
	else
		popup = nil
		warn("[TeamSelectionController] Missing StarterGui.TeamSelectionGui.TeamPopupFrame (Frame).")
	end
	refreshCounts()
	refreshRageState()
end

local existingGui = playerGui:FindFirstChild("TeamSelectionGui")
if existingGui then
	bindGui(existingGui)
else
	warn("[TeamSelectionController] Missing PlayerGui.TeamSelectionGui. Ensure the Studio-authored ScreenGui is included in Rojo sync.")
end
table.insert(globalConnections, playerGui.ChildAdded:Connect(function(child)
	if child.Name == "TeamSelectionGui" then bindGui(child) end
end))

local function watchPlayer(candidate: Player)
	if playerConnections[candidate] then return end
	playerConnections[candidate] = candidate:GetPropertyChangedSignal("Team"):Connect(refreshCounts)
end
for _, candidate in ipairs(Players:GetPlayers()) do watchPlayer(candidate) end
Players.PlayerAdded:Connect(function(candidate)
	watchPlayer(candidate)
	refreshCounts()
end)
Players.PlayerRemoving:Connect(function(candidate)
	local connection = playerConnections[candidate]
	if connection then connection:Disconnect(); playerConnections[candidate] = nil end
	task.defer(refreshCounts)
end)
table.insert(globalConnections, Workspace:GetAttributeChangedSignal("RageActive"):Connect(refreshRageState))
if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
	table.insert(globalConnections, feedbackRemote.OnClientEvent:Connect(function(message)
		if type(message) == "table" and message.EventType == "TeamChangeResult" and type(message.Payload) == "table" then
			if message.Payload.Success ~= true then
				warn(string.format("[TeamSelectionController] Team change rejected: %s", tostring(message.Payload.Reason or "Unknown")))
			end
			refreshCounts()
		end
	end))
end
