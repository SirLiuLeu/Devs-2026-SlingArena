--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local UIController = {}
UIController.__index = UIController

export type Dependencies = {
	ClientService: any,
}

export type UIController = {
	ClientService: any,
	PlayerGui: PlayerGui,
	JoinButton: TextButton?,
	LeaveButton: TextButton?,
	LobbyStatusLabel: TextLabel?,
	MatchStatusLabel: TextLabel?,
	TimerLabel: TextLabel?,
	AlivePlayersLabel: TextLabel?,
	WinnerPopup: TextLabel?,
	ScoreLabel: TextLabel?,
	GoldLabel: TextLabel?,
	WinsLabel: TextLabel?,
	Connections: { RBXScriptConnection },
	LocalWins: number,
	Start: (self: UIController) -> (),
	Destroy: (self: UIController) -> (),
}

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextButton") then
		return value
	end
	if value ~= nil then
		warn("[ProjectTreeSpec] Missing:", path)
	end
	return nil
end

local function resolveTextLabel(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextLabel") then
		return value
	end
	if value ~= nil then
		warn("[ProjectTreeSpec] Missing:", path)
	end
	return nil
end

function UIController.new(playerGui: PlayerGui, dependencies: Dependencies): UIController
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

	local stateConnection = self.ClientService:BindStateUpdate(function(state)
		if self.ScoreLabel then
			self.ScoreLabel.Text = string.format("Score: %d", math.floor(state.Exp or 0))
		end
		if self.GoldLabel then
			self.GoldLabel.Text = string.format("Gold: %d", math.floor(state.Diamonds or 0))
		end
		if self.WinsLabel then
			self.WinsLabel.Text = string.format("Wins: %d", self.LocalWins)
		end
	end)
	if stateConnection then
		table.insert(self.Connections, stateConnection)
	end

	local uiStateConnection = self.ClientService:BindUIStateUpdate(function(payload)
		local stateName = payload.State or "Lobby"
		local timeLeft = math.floor(payload.TimeLeft or 0)
		local alive = payload.AlivePlayers or 0

		if self.LobbyStatusLabel then
			self.LobbyStatusLabel.Text = string.format("Status: %s", stateName)
		end
		if self.MatchStatusLabel then
			self.MatchStatusLabel.Text = string.format("Status: %s", stateName)
		end
		if self.TimerLabel then
			self.TimerLabel.Text = string.format("Time: %d", timeLeft)
		end
		if self.AlivePlayersLabel then
			self.AlivePlayersLabel.Text = string.format("Alive: %d", alive)
		end
		if self.WinnerPopup and stateName ~= "RoundEnd" then
			self.WinnerPopup.Visible = false
		end
	end)
	if uiStateConnection then
		table.insert(self.Connections, uiStateConnection)
	end

	local resultConnection = self.ClientService:BindRoundResult(function(payload)
		if self.WinnerPopup then
			self.WinnerPopup.Text = "Winner: " .. tostring(payload.Winner)
			self.WinnerPopup.Visible = true
		end

		if payload.Winner == game:GetService("Players").LocalPlayer.Name then
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
