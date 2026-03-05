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

local function ensureFallbackUI(playerGui: PlayerGui): Frame
	local screen = playerGui:FindFirstChild("SlingArenaDynamicUI") :: ScreenGui?
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name = "SlingArenaDynamicUI"
		screen.ResetOnSpawn = false
		screen.Parent = playerGui
	end
	local root = screen:FindFirstChild("Root") :: Frame?
	if not root then
		root = Instance.new("Frame")
		root.Name = "Root"
		root.Size = UDim2.fromOffset(360, 380)
		root.Position = UDim2.fromOffset(16, 16)
		root.BackgroundColor3 = Color3.fromRGB(26, 30, 38)
		root.Parent = screen
	end
	return root
end

local function ensureLabel(parent: Instance, name: string, y: number): TextLabel
	local label = parent:FindFirstChild(name) :: TextLabel?
	if not label then
		label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromOffset(340, 24)
		label.Position = UDim2.fromOffset(10, y)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(240, 240, 240)
		label.Parent = parent
	end
	return label
end

local function ensureButton(parent: Instance, name: string, text: string, x: number, y: number): TextButton
	local btn = parent:FindFirstChild(name) :: TextButton?
	if not btn then
		btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.fromOffset(160, 28)
		btn.Position = UDim2.fromOffset(x, y)
		btn.BackgroundColor3 = Color3.fromRGB(60, 88, 142)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Parent = parent
	end
	btn.Text = text
	return btn
end

function UIController.new(playerGui: PlayerGui, dependencies: Dependencies)
	local self = setmetatable({}, UIController)
	self.ClientService = dependencies.ClientService
	self.PlayerGui = playerGui
	self.Connections = {}
	self.LocalWins = 0

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

	local root = ensureFallbackUI(playerGui)
	self.LobbyStatusLabel = self.LobbyStatusLabel or ensureLabel(root, "ArenaStatus", 8)
	self.MatchStatusLabel = self.MatchStatusLabel or ensureLabel(root, "MatchStatus", 36)
	self.TimerLabel = self.TimerLabel or ensureLabel(root, "CountdownTimer", 64)
	self.AlivePlayersLabel = self.AlivePlayersLabel or ensureLabel(root, "PlayerCount", 92)
	self.MapLabel = ensureLabel(root, "MapName", 120)
	self.ScoreLabel = self.ScoreLabel or ensureLabel(root, "ExpLabel", 148)
	self.LevelLabel = ensureLabel(root, "LevelLabel", 176)
	self.HpLabel = ensureLabel(root, "HpLabel", 204)
	self.WinnerPopup = self.WinnerPopup or ensureLabel(root, "WinnerPopup", 232)
	self.RespawnLabel = ensureLabel(root, "RespawnLabel", 260)

	self.JoinButton = self.JoinButton or ensureButton(root, "JoinButton", "Join Arena", 10, 290)
	self.LeaveButton = self.LeaveButton or ensureButton(root, "LeaveButton", "Leave Arena", 180, 290)
	self.TeleportForestButton = ensureButton(root, "TeleportForest", "Teleport Forest", 10, 324)
	self.TeleportDesertButton = ensureButton(root, "TeleportDesert", "Teleport Desert", 180, 324)
	self.DebugFoodButton = ensureButton(root, "DebugFood", "Debug Spawn Food", 10, 356)
	self.DebugResetButton = ensureButton(root, "DebugReset", "Debug Reset Sling", 180, 356)

	return self
end

function UIController:Start()
	table.insert(self.Connections, self.JoinButton.MouseButton1Click:Connect(function()
		self.ClientService:RequestJoinArena()
	end))
	table.insert(self.Connections, self.LeaveButton.MouseButton1Click:Connect(function()
		self.ClientService:RequestLeaveArena()
	end))
	table.insert(self.Connections, self.TeleportForestButton.MouseButton1Click:Connect(function()
		self.ClientService:RequestTeleport("ForestArena", "Spawn1")
	end))
	table.insert(self.Connections, self.TeleportDesertButton.MouseButton1Click:Connect(function()
		self.ClientService:RequestTeleport("DesertArena", "SpawnA")
	end))
	table.insert(self.Connections, self.DebugFoodButton.MouseButton1Click:Connect(function()
		self.ClientService:RequestDebugSpawnFood("ForestArena")
	end))
	table.insert(self.Connections, self.DebugResetButton.MouseButton1Click:Connect(function()
		self.ClientService:RequestDebugResetSling()
	end))

	local stateConnection = self.ClientService:BindStateUpdate(function(state)
		self.ScoreLabel.Text = string.format("EXP: %d", math.floor(state.Exp or 0))
		self.LevelLabel.Text = string.format("Level: %d", math.floor(state.Level or 1))
		self.HpLabel.Text = string.format("HP: %d/%d", math.floor(state.CurrentHP or 0), math.floor(state.MaxHP or 100))
		self.MapLabel.Text = string.format("Map: %s", tostring(state.MapName or "LobbyMap"))
		if (state.CurrentHP or 0) <= 0 then
			self.RespawnLabel.Text = "Respawn screen: waiting to respawn..."
		else
			self.RespawnLabel.Text = "Respawn screen: hidden"
		end
	end)
	if stateConnection then
		table.insert(self.Connections, stateConnection)
	end

	local uiStateConnection = self.ClientService:BindUIStateUpdate(function(payload)
		self.LobbyStatusLabel.Text = string.format("ArenaStatus: %s", tostring(payload.ArenaStatus or payload.State or "Lobby"))
		self.MatchStatusLabel.Text = string.format("Match: %s", tostring(payload.State or "Lobby"))
		self.TimerLabel.Text = string.format("CountdownTimer: %d", math.floor(payload.CountdownTimer or payload.TimeLeft or 0))
		self.AlivePlayersLabel.Text = string.format("PlayerCount: %d (alive %d)", payload.PlayerCount or 0, payload.AlivePlayers or 0)
		if self.WinnerPopup and (payload.State or "") ~= "RoundEnd" then
			self.WinnerPopup.Visible = true
			self.WinnerPopup.Text = "Match result screen: pending"
		end
	end)
	if uiStateConnection then
		table.insert(self.Connections, uiStateConnection)
	end

	local resultConnection = self.ClientService:BindRoundResult(function(payload)
		self.WinnerPopup.Visible = true
		self.WinnerPopup.Text = "Match result screen: Winner: " .. tostring(payload.Winner)
		if payload.Winner == Players.LocalPlayer.Name then
			self.LocalWins += 1
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
