--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local UIController = {}
UIController.__index = UIController

export type Dependencies = {
	ClientService: any,
}

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextButton") then
		return value
	end
	return nil
end

local function resolveTextLabel(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextLabel") then
		return value
	end
	return nil
end

local function warnMissingUiPath(path: string, className: string)
	warn(string.format("[UI_MISSING] %s (%s) is missing. Create it manually in Studio.", path, className))
end

function UIController.new(playerGui: PlayerGui, dependencies: Dependencies)
	local self = setmetatable({}, UIController)
	self.ClientService = dependencies.ClientService
	self.PlayerGui = playerGui
	self.Connections = {}
	self.LocalWins = 0

	-- [UI_CREATION_GUIDE]
	-- Create in Studio:
	-- StarterGui
	--   LobbyUI (ScreenGui)
	--     LobbyUI (Frame)
	--       RootFrame (Frame)
	--         StatusLabel (TextLabel)
	--         JoinButton (TextButton)
	--         LeaveButton (TextButton)
	--         TeleportForest (TextButton)
	--         TeleportDesert (TextButton)
	--         DebugFood (TextButton)
	--         DebugReset (TextButton)
	--         MapName (TextLabel)
	--         LevelLabel (TextLabel)
	--         HpLabel (TextLabel)
	--         RespawnLabel (TextLabel)
	--   MatchUI (ScreenGui)
	--     MatchUI (Frame)
	--       RootFrame (Frame)
	--         StatusLabel (TextLabel)
	--         TimerLabel (TextLabel)
	--         AlivePlayersLabel (TextLabel)
	--         WinnerPopup (TextLabel)
	--   StatsUI (ScreenGui)
	--     StatsUI (Frame)
	--       RootFrame (Frame)
	--         ScoreLabel (TextLabel)
	--         GoldLabel (TextLabel)
	--         WinsLabel (TextLabel)

	self.JoinButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.JoinButton)
	self.LeaveButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.LeaveButton)
	self.LobbyStatusLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Lobby.StatusLabel)
	self.MatchStatusLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.StatusLabel)
	self.TimerLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.TimerLabel)
	self.AlivePlayersLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.AlivePlayersLabel)
	self.WinnerPopup = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.WinnerPopup)
	self.ScoreLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Stats.ScoreLabel)
	self.GoldLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Stats.GoldLabel)
	self.WinsLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Stats.WinsLabel)
	self.MapLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Lobby.MapName)
	self.LevelLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Lobby.LevelLabel)
	self.HpLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Lobby.HpLabel)
	self.RespawnLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Lobby.RespawnLabel)
	self.TeleportForestButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.TeleportForestButton)
	self.TeleportDesertButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.TeleportDesertButton)
	self.DebugFoodButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugFoodButton)
	self.DebugResetButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugResetButton)

	if not self.JoinButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.JoinButton, "TextButton") end
	if not self.LeaveButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.LeaveButton, "TextButton") end
	if not self.LobbyStatusLabel then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.StatusLabel, "TextLabel") end
	if not self.MatchStatusLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.StatusLabel, "TextLabel") end
	if not self.TimerLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.TimerLabel, "TextLabel") end
	if not self.AlivePlayersLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.AlivePlayersLabel, "TextLabel") end
	if not self.WinnerPopup then warnMissingUiPath(ProjectTreeSpec.UI.Match.WinnerPopup, "TextLabel") end
	if not self.ScoreLabel then warnMissingUiPath(ProjectTreeSpec.UI.Stats.ScoreLabel, "TextLabel") end
	if not self.GoldLabel then warnMissingUiPath(ProjectTreeSpec.UI.Stats.GoldLabel, "TextLabel") end
	if not self.WinsLabel then warnMissingUiPath(ProjectTreeSpec.UI.Stats.WinsLabel, "TextLabel") end
	if not self.MapLabel then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.MapName, "TextLabel") end
	if not self.LevelLabel then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.LevelLabel, "TextLabel") end
	if not self.HpLabel then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.HpLabel, "TextLabel") end
	if not self.RespawnLabel then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.RespawnLabel, "TextLabel") end
	if not self.TeleportForestButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.TeleportForestButton, "TextButton") end
	if not self.TeleportDesertButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.TeleportDesertButton, "TextButton") end
	if not self.DebugFoodButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugFoodButton, "TextButton") end
	if not self.DebugResetButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugResetButton, "TextButton") end

	return self
end

function UIController:Start()
	if self.JoinButton then
		table.insert(self.Connections, self.JoinButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestJoinArena()
		end))
	end
	if self.LeaveButton then
		table.insert(self.Connections, self.LeaveButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestLeaveArena()
		end))
	end
	if self.TeleportForestButton then
		table.insert(self.Connections, self.TeleportForestButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestTeleport("ForestArena", "Spawn1")
		end))
	end
	if self.TeleportDesertButton then
		table.insert(self.Connections, self.TeleportDesertButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestTeleport("DesertArena", "SpawnA")
		end))
	end
	if self.DebugFoodButton then
		table.insert(self.Connections, self.DebugFoodButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestDebugSpawnFood("ForestArena")
		end))
	end
	if self.DebugResetButton then
		table.insert(self.Connections, self.DebugResetButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestDebugResetSling()
		end))
	end

	local stateConnection = self.ClientService:BindStateUpdate(function(state)
		if self.ScoreLabel then self.ScoreLabel.Text = string.format("EXP: %d", math.floor(state.Exp or 0)) end
		if self.LevelLabel then self.LevelLabel.Text = string.format("Level: %d", math.floor(state.Level or 1)) end
		if self.HpLabel then self.HpLabel.Text = string.format("HP: %d/%d", math.floor(state.CurrentHP or 0), math.floor(state.MaxHP or 100)) end
		if self.MapLabel then self.MapLabel.Text = string.format("Map: %s", tostring(state.MapName or "LobbyMap")) end
		if self.RespawnLabel then
			if (state.CurrentHP or 0) <= 0 then
				self.RespawnLabel.Text = "Respawn screen: waiting to respawn..."
			else
				self.RespawnLabel.Text = "Respawn screen: hidden"
			end
		end
	end)
	if stateConnection then
		table.insert(self.Connections, stateConnection)
	end

	local uiStateConnection = self.ClientService:BindUIStateUpdate(function(payload)
		if self.LobbyStatusLabel then self.LobbyStatusLabel.Text = string.format("ArenaStatus: %s", tostring(payload.ArenaStatus or payload.State or "Lobby")) end
		if self.MatchStatusLabel then self.MatchStatusLabel.Text = string.format("Match: %s", tostring(payload.State or "Lobby")) end
		if self.TimerLabel then self.TimerLabel.Text = string.format("CountdownTimer: %d", math.floor(payload.CountdownTimer or payload.TimeLeft or 0)) end
		if self.AlivePlayersLabel then self.AlivePlayersLabel.Text = string.format("PlayerCount: %d (alive %d)", payload.PlayerCount or 0, payload.AlivePlayers or 0) end
		if self.WinnerPopup and (payload.State or "") ~= "RoundEnd" then
			self.WinnerPopup.Visible = true
			self.WinnerPopup.Text = "Match result screen: pending"
		end
	end)
	if uiStateConnection then
		table.insert(self.Connections, uiStateConnection)
	end

	local resultConnection = self.ClientService:BindRoundResult(function(payload)
		if self.WinnerPopup then
			self.WinnerPopup.Visible = true
			self.WinnerPopup.Text = "Match result screen: Winner: " .. tostring(payload.Winner)
		end
		if payload.Winner == Players.LocalPlayer.Name then
			self.LocalWins += 1
			if self.WinsLabel then
				self.WinsLabel.Text = string.format("Wins: %d", self.LocalWins)
			end
		end
	end)
	if resultConnection then
		table.insert(self.Connections, resultConnection)
	end
end

function UIController:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return UIController
