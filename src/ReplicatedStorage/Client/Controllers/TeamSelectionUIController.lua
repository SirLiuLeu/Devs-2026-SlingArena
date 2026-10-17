--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TeamConfig = require(ReplicatedStorage.Shared.Config.TeamConfig)
local ConfirmationTextConfig = require(ReplicatedStorage.Shared.Config.ConfirmationTextConfig)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local TeamSelectionUIController = {}
TeamSelectionUIController.__index = TeamSelectionUIController

local FULL_FLASH_COLOR = Color3.fromRGB(255, 45, 45)
local FLASH_TWEEN_SECONDS = 0.12
local COOLDOWN_SECONDS = TeamConfig.ChangeCooldownSeconds

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
		_flashVersions = {},
		_currentTeamId = nil,
		_rageActive = false,
		_localCooldownEndsAt = 0,
		_lastRequestedTeamId = nil,
	}, TeamSelectionUIController)
end

function TeamSelectionUIController:SetConfirmationController(controller)
	self._confirmation = controller
end

function TeamSelectionUIController:SetToastController(controller)
	self._toast = controller
end

function TeamSelectionUIController:_showToast(text: string)
	if self._toast and typeof(self._toast.Enqueue) == "function" then
		self._toast:Enqueue({ Type = "Generic", Text = text })
	else
		warn("[TEAM_SELECTION_UI] " .. text)
	end
end

function TeamSelectionUIController:_refreshToggleStyle()
	local toggle = self._toggle
	if not (toggle and toggle:IsA("GuiButton")) then return end
	local color = self._currentTeamId and TeamConfig.TeamColors[self._currentTeamId]
	if color then
		toggle.BackgroundColor3 = color
		if toggle:IsA("ImageButton") then toggle.ImageColor3 = color end
		if toggle:IsA("TextButton") then
			toggle.TextColor3 = if self._currentTeamId == "White" or self._currentTeamId == "Yellow" then Color3.fromRGB(30, 30, 30) else Color3.new(1, 1, 1)
		end
	else
		if self._toggleOriginalBackground then toggle.BackgroundColor3 = self._toggleOriginalBackground end
		if toggle:IsA("ImageButton") and self._toggleOriginalImageColor then toggle.ImageColor3 = self._toggleOriginalImageColor end
	end
end

function TeamSelectionUIController:_flashFullTeam(teamId: string?)
	if type(teamId) ~= "string" then return end
	local entry = self._teamButtons[teamId]
	local button = entry and entry.button
	if not button or not button.Parent then return end
	local version = (self._flashVersions[teamId] or 0) + 1
	self._flashVersions[teamId] = version
	local originalColor = entry.originalBackgroundColor
	task.spawn(function()
		for _ = 1, 2 do
			if self._flashVersions[teamId] ~= version or not button.Parent then return end
			local toRed = TweenService:Create(button, TweenInfo.new(FLASH_TWEEN_SECONDS), { BackgroundColor3 = FULL_FLASH_COLOR })
			toRed:Play()
			toRed.Completed:Wait()
			if self._flashVersions[teamId] ~= version or not button.Parent then return end
			local restore = TweenService:Create(button, TweenInfo.new(FLASH_TWEEN_SECONDS), { BackgroundColor3 = originalColor })
			restore:Play()
			restore.Completed:Wait()
		end
	end)
end

function TeamSelectionUIController:_teamPlayerCount(teamId: string): number
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local assignedTeamId = player:GetAttribute("TeamId")
		if type(assignedTeamId) ~= "string" and player.Team then assignedTeamId = player.Team.Name end
		if assignedTeamId == teamId then count += 1 end
	end
	return count
end

function TeamSelectionUIController:_requestTeamChange(teamId: string)
	if teamId == self._currentTeamId then return end
	if self._rageActive then
		self:_showToast(ConfirmationTextConfig.Get("RageActive"))
		return
	end
	local remaining = self._localCooldownEndsAt - os.clock()
	if remaining > 0 then
		self:_showToast(ConfirmationTextConfig.Get("Cooldown", { seconds = math.ceil(remaining) }))
		return
	end
	if self:_teamPlayerCount(teamId) >= TeamConfig.MaxPlayersPerTeam then
		self:_flashFullTeam(teamId)
		return
	end
	if not self._changeTeamRemote then
		warnMissing("ReplicatedStorage.LauncherArenaRemotes.ChangeTeam (RemoteEvent)")
		return
	end
	if not self._confirmation then
		warnMissing("ConfirmationGui / ConfirmationUIController")
		return
	end
	self._lastRequestedTeamId = teamId
	local message = ConfirmationTextConfig.Get("ChangeTeam", { team = teamId })
	self._confirmation:RequestConfirm(message, function()
		if self._changeTeamRemote then self._changeTeamRemote:FireServer(teamId) end
	end)
end

function TeamSelectionUIController:Start()
	local ui = ProjectTreeSpec.UI.TeamSelection
	self._gui = PathResolver.resolvePath(self._playerGui, ui.ScreenGui) :: ScreenGui?
	self._toggle = PathResolver.resolvePath(self._playerGui, ui.ToggleButton)
	self._popup = PathResolver.resolvePath(self._playerGui, ui.PopupFrame)
	if not self._gui then warnMissing("StarterGui.TeamSelectionGui (ScreenGui)") end
	if not (self._toggle and self._toggle:IsA("GuiButton")) then warnMissing("TeamSelectionGui.ToggleBtn (GuiButton)") end
	if not (self._popup and self._popup:IsA("GuiObject")) then warnMissing("TeamSelectionGui.TeamPopupFrame (Frame)") end
	if self._toggle and self._toggle:IsA("GuiButton") then
		self._toggleOriginalBackground = self._toggle.BackgroundColor3
		if self._toggle:IsA("ImageButton") then self._toggleOriginalImageColor = self._toggle.ImageColor3 end
	end
	if self._popup and self._popup:IsA("GuiObject") then self._popup.Visible = false end
	if self._toggle and self._toggle:IsA("GuiButton") and self._popup and self._popup:IsA("GuiObject") then
		table.insert(self._connections, self._toggle.Activated:Connect(function()
			self._popup.Visible = not self._popup.Visible
		end))
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer.Team then self._currentTeamId = localPlayer.Team.Name end
	local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	self._changeTeamRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.ChangeTeam) :: RemoteEvent?
	self._feedbackRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	local stateUpdate = remotes and remotes:FindFirstChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent?
	local uiStateUpdate = remotes and remotes:FindFirstChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent?
	if not self._changeTeamRemote then warnMissing("ReplicatedStorage.LauncherArenaRemotes.ChangeTeam (RemoteEvent)") end

	if self._popup then
		for _, item in ipairs(self._popup:GetChildren()) do
			if not item:IsA("GuiObject") or item:IsA("UIListLayout") or item:IsA("UIGridLayout") or item:IsA("UIPadding") then continue end
			local button = if item:IsA("TextButton") then item else item:FindFirstChildWhichIsA("TextButton", true)
			if not (button and button:IsA("TextButton")) then continue end
			local teamId = getTeamId(item, button)
			if not teamId then
				warn(string.format("[TEAM_SELECTION_UI] Could not resolve team ID for %s; button ignored.", item:GetFullName()))
				continue
			end
			self._teamButtons[teamId] = {
				item = item,
				button = button,
				originalBackgroundColor = button.BackgroundColor3,
			}
			table.insert(self._connections, button.Activated:Connect(function()
				self:_requestTeamChange(teamId)
			end))
		end
	end

	if stateUpdate and stateUpdate:IsA("RemoteEvent") then
		table.insert(self._connections, stateUpdate.OnClientEvent:Connect(function(state)
			if type(state) == "table" then
				self._currentTeamId = if type(state.TeamId) == "string" then state.TeamId else nil
				self:_refreshToggleStyle()
			end
		end))
	end
	if uiStateUpdate and uiStateUpdate:IsA("RemoteEvent") then
		table.insert(self._connections, uiStateUpdate.OnClientEvent:Connect(function(state)
			if type(state) ~= "table" then return end
			local payload = if type(state.Payload) == "table" then state.Payload else state
			if type(payload.RageActive) == "boolean" then self._rageActive = payload.RageActive end
		end))
	end
	if self._feedbackRemote then
		table.insert(self._connections, self._feedbackRemote.OnClientEvent:Connect(function(message)
			if type(message) ~= "table" or message.EventType ~= "TeamChangeResult" or type(message.Payload) ~= "table" then return end
			local payload = message.Payload
			if payload.Success == true then
				self._currentTeamId = if type(payload.TeamId) == "string" then payload.TeamId else self._currentTeamId
				self._localCooldownEndsAt = os.clock() + math.max(0, tonumber(payload.CooldownRemaining) or COOLDOWN_SECONDS)
				if self._popup and self._popup:IsA("GuiObject") then self._popup.Visible = false end
				self:_refreshToggleStyle()
			else
				local reason = tostring(payload.Reason or "")
				if reason == "TeamFull" then
					self:_flashFullTeam(self._lastRequestedTeamId)
					self:_showToast(ConfirmationTextConfig.Get("TeamFull"))
				elseif reason == "Cooldown" then
					self:_showToast(ConfirmationTextConfig.Get("Cooldown", { seconds = math.max(1, tonumber(payload.CooldownRemaining) or 1) }))
				elseif reason == "RageActive" then
					self:_showToast(ConfirmationTextConfig.Get("RageActive"))
				elseif reason == "RoundInactive" then
					self:_showToast(ConfirmationTextConfig.Get("TeamChangeUnavailable"))
				end
			end
			self._lastRequestedTeamId = nil
		end))
	end

	for _, team in ipairs(Teams:GetTeams()) do self:_watchTeam(team) end
	table.insert(self._connections, Teams.ChildAdded:Connect(function(child)
		if child:IsA("Team") then self:_watchTeam(child); self:_refreshCounts() end
	end))
	table.insert(self._connections, Teams.ChildRemoved:Connect(function() self:_refreshCounts() end))
	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		table.insert(self._connections, player:GetPropertyChangedSignal("Team"):Connect(function() self:_refreshCounts() end))
		table.insert(self._connections, player:GetAttributeChangedSignal("TeamId"):Connect(function() self:_refreshCounts() end))
		self:_refreshCounts()
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(self._connections, player:GetPropertyChangedSignal("Team"):Connect(function() self:_refreshCounts() end))
		table.insert(self._connections, player:GetAttributeChangedSignal("TeamId"):Connect(function() self:_refreshCounts() end))
	end
	self:_refreshCounts()
	self:_refreshToggleStyle()
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
			countLabel.Text = string.format("%d/%d", self:_teamPlayerCount(teamId), TeamConfig.MaxPlayersPerTeam)
		end
	end
end

function TeamSelectionUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for _, connections in pairs(self._teamConnections) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end
	for teamId in pairs(self._flashVersions) do self._flashVersions[teamId] += 1 end
	table.clear(self._connections)
	table.clear(self._teamConnections)
	table.clear(self._teamButtons)
end

return TeamSelectionUIController
