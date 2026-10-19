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
			toggle.Text = self._currentTeamId or ""
			toggle.TextColor3 = if self._currentTeamId == "White" or self._currentTeamId == "Yellow" then Color3.fromRGB(30, 30, 30) else Color3.new(1, 1, 1)
		end
	else
		if self._toggleOriginalBackground then toggle.BackgroundColor3 = self._toggleOriginalBackground end
		if toggle:IsA("ImageButton") and self._toggleOriginalImageColor then toggle.ImageColor3 = self._toggleOriginalImageColor end
		if toggle:IsA("TextButton") then
			if self._toggleOriginalText then toggle.Text = self._toggleOriginalText end
			if self._toggleOriginalTextColor then toggle.TextColor3 = self._toggleOriginalTextColor end
		end
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

function TeamSelectionUIController:_logRejectedRequest(reason: string, teamId: any, detail: string?)
	local message = string.format("[TEAM_SELECTION_REJECTED] player=%s reason=%s team=%s detail=%s", Players.LocalPlayer.Name, reason, tostring(teamId), detail or "-")
	if reason == "InvalidRequest" or reason == "InvalidTeam" or reason == "Cooldown" or reason == "RageActive" then
		warn(message)
	else
		print(message)
	end
end

function TeamSelectionUIController:_requestTeamChange(teamId: string)
	print(string.format("[TEAM_CHANGE_CLIENT] stage=button_clicked player=%s requestedTeam=%s currentTeam=%s rageActive=%s cooldownRemaining=%.2f",
		Players.LocalPlayer.Name, teamId, tostring(self._currentTeamId), tostring(self._rageActive), math.max(0, self._localCooldownEndsAt - os.clock())))
	if teamId == self._currentTeamId then
		self:_logRejectedRequest("AlreadyOnTeam", teamId, "Already assigned locally")
		return
	end
	if self._rageActive then
		self:_logRejectedRequest("RageActive", teamId, "Client blocked request because Rage is active")
		self:_showToast(ConfirmationTextConfig.Get("RageActive"))
		return
	end
	local remaining = self._localCooldownEndsAt - os.clock()
	if remaining > 0 then
		self:_logRejectedRequest("Cooldown", teamId, string.format("remaining=%.2f localCooldownEndsAt=%.2f", remaining, self._localCooldownEndsAt))
		self:_showToast(ConfirmationTextConfig.Get("Cooldown", { seconds = math.ceil(remaining) }))
		return
	end
	local teamCount = self:_teamPlayerCount(teamId)
	if teamCount >= TeamConfig.MaxPlayersPerTeam then
		self:_logRejectedRequest("TeamFull", teamId, string.format("clientCount=%d cap=%d", teamCount, TeamConfig.MaxPlayersPerTeam))
		self:_flashFullTeam(teamId)
		self:_showToast(ConfirmationTextConfig.Get("TeamFull"))
		return
	end
	if not (self._changeTeamRemote and self._changeTeamRemote:IsA("RemoteEvent")) then
		self:_logRejectedRequest("MissingRemote", teamId, "LauncherArenaRemotes.ChangeTeam does not exist")
		warnMissing("ReplicatedStorage.LauncherArenaRemotes.ChangeTeam (RemoteEvent)")
		return
	end
	if not self._confirmation then
		warnMissing("ConfirmationGui / ConfirmationUIController")
		return
	end
	if self._pendingTeamConfirmation then
		warn(string.format(
			"[TEAM_CHANGE_CLIENT] stage=confirmation_blocked player=%s pendingTarget=%s clickedTarget=%s",
			Players.LocalPlayer.Name,
			tostring(self._pendingTeamConfirmation.targetTeam),
			teamId
		))
		return
	end

	local sourceTeamId = self._currentTeamId or "None"
	self._lastRequestedTeamId = teamId
	self._pendingTeamConfirmation = { sourceTeam = sourceTeamId, targetTeam = teamId }
	local message = ConfirmationTextConfig.Get("ChangeTeam", {
		currentTeam = sourceTeamId,
		team = teamId,
	})
	print(string.format(
		"[TEAM_CHANGE_CLIENT] stage=confirm_open player=%s fromTeam=%s targetTeam=%s message=%q",
		Players.LocalPlayer.Name,
		sourceTeamId,
		teamId,
		message
	))

	local confirmationShown = self._confirmation:RequestConfirm(message, function()
		self._pendingTeamConfirmation = nil
		print(string.format(
			"[TEAM_CHANGE_CLIENT] stage=confirm_action confirmed=true player=%s fromTeam=%s targetTeam=%s",
			Players.LocalPlayer.Name,
			sourceTeamId,
			teamId
		))
		if self._changeTeamRemote and self._changeTeamRemote:IsA("RemoteEvent") then
			print(string.format(
				"[TEAM_CHANGE_CLIENT] stage=confirmed_send player=%s fromTeam=%s requestedTeam=%s",
				Players.LocalPlayer.Name,
				sourceTeamId,
				teamId
			))
			self._changeTeamRemote:FireServer(teamId)
		else
			warn("[TEAM_SELECTION_UI] Confirm callback could not send ChangeTeam because the RemoteEvent is missing.")
		end
	end, function()
		self._pendingTeamConfirmation = nil
		print(string.format(
			"[TEAM_CHANGE_CLIENT] stage=confirm_action confirmed=false player=%s fromTeam=%s targetTeam=%s",
			Players.LocalPlayer.Name,
			sourceTeamId,
			teamId
		))
	end)

	if not confirmationShown then
		self._pendingTeamConfirmation = nil
		self._lastRequestedTeamId = nil
		warn("[TEAM_SELECTION_UI] ChangeTeam request was not sent because confirmation UI could not be shown.")
	end
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
		if self._toggle:IsA("TextButton") then
			self._toggleOriginalText = self._toggle.Text
			self._toggleOriginalTextColor = self._toggle.TextColor3
		end
	end
	if self._popup and self._popup:IsA("GuiObject") then self._popup.Visible = false end
	if self._toggle and self._toggle:IsA("GuiButton") and self._popup and self._popup:IsA("GuiObject") then
		table.insert(self._connections, self._toggle.Activated:Connect(function()
			self._popup.Visible = not self._popup.Visible
		end))
	end

	local localPlayer = Players.LocalPlayer
	local attributedTeamId = localPlayer:GetAttribute("TeamId")
	self._currentTeamId = if type(attributedTeamId) == "string" then attributedTeamId else (if localPlayer.Team then localPlayer.Team.Name else nil)
	table.insert(self._connections, localPlayer:GetAttributeChangedSignal("TeamId"):Connect(function()
		local teamId = localPlayer:GetAttribute("TeamId")
		self._currentTeamId = if type(teamId) == "string" then teamId else nil
		self:_refreshToggleStyle()
		self:_refreshCounts()
	end))
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
				print(string.format("[TEAM_CHANGE_CLIENT] stage=result success=true requestedTeam=%s serverTeam=%s cooldownRemaining=%s", tostring(self._lastRequestedTeamId), tostring(payload.TeamId), tostring(payload.CooldownRemaining)))
				self._currentTeamId = if type(payload.TeamId) == "string" then payload.TeamId else self._currentTeamId
				self._localCooldownEndsAt = os.clock() + math.max(0, tonumber(payload.CooldownRemaining) or COOLDOWN_SECONDS)
				if self._popup and self._popup:IsA("GuiObject") then self._popup.Visible = false end
				self:_refreshToggleStyle()
			else
				local reason = tostring(payload.Reason or "")
				print(string.format("[TEAM_CHANGE_CLIENT] stage=result success=false requestedTeam=%s reason=%s cooldownRemaining=%s", tostring(self._lastRequestedTeamId), reason, tostring(payload.CooldownRemaining)))
				self:_logRejectedRequest(reason ~= "" and reason or "Unknown", self._lastRequestedTeamId, "Server rejected the team-change request")
				if reason == "TeamFull" then
					self:_flashFullTeam(self._lastRequestedTeamId)
					self:_showToast(ConfirmationTextConfig.Get("TeamFull"))
				elseif reason == "Cooldown" then
					self:_showToast(ConfirmationTextConfig.Get("Cooldown", { seconds = math.max(1, tonumber(payload.CooldownRemaining) or 1) }))
				elseif reason == "RageActive" then
					self:_showToast(ConfirmationTextConfig.Get("RageActive"))
				elseif reason == "RoundInactive" or reason == "InvalidRequest" or reason == "InvalidTeam" or reason == "AlreadyOnTeam" then
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
