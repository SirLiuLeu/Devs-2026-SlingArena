--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")

local joinArena = remotes:WaitForChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
local leaveArena = remotes:WaitForChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
local stateUpdate = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent
local uiStateUpdate = remotes:WaitForChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
local roundResult = remotes:WaitForChild(RemoteContracts.Names.RoundResult) :: RemoteEvent

local lobby = playerGui:WaitForChild("LobbyUI")
local stats = playerGui:WaitForChild("StatsUI")
local match = playerGui:WaitForChild("MatchUI")

local localWins = 0

local lobbyStatusLabel = lobby.RootFrame.StatusLabel :: TextLabel
lobby.RootFrame.JoinButton.MouseButton1Click:Connect(function() joinArena:FireServer() end)
lobby.RootFrame.LeaveButton.MouseButton1Click:Connect(function() leaveArena:FireServer() end)

stateUpdate.OnClientEvent:Connect(function(state)
	stats.RootFrame.ScoreLabel.Text = string.format("Score: %d", math.floor(state.Exp or 0))
	stats.RootFrame.GoldLabel.Text = string.format("Gold: %d", math.floor(state.Diamonds or 0))
	stats.RootFrame.WinsLabel.Text = string.format("Wins: %d", localWins)
end)

uiStateUpdate.OnClientEvent:Connect(function(payload)
	lobbyStatusLabel.Text = string.format("Status: %s", payload.State or "Lobby")
	match.RootFrame.StatusLabel.Text = string.format("Status: %s", payload.State or "Lobby")
	match.RootFrame.TimerLabel.Text = string.format("Time: %d", math.floor(payload.TimeLeft or 0))
	match.RootFrame.AlivePlayersLabel.Text = string.format("Alive: %d", payload.AlivePlayers or 0)
	if payload.State ~= "RoundEnd" then
		match.RootFrame.WinnerPopup.Visible = false
	end
end)

roundResult.OnClientEvent:Connect(function(payload)
	match.RootFrame.WinnerPopup.Text = "Winner: " .. tostring(payload.Winner)
	match.RootFrame.WinnerPopup.Visible = true
	if payload.Winner == player.Name then
		localWins += 1
		stats.RootFrame.WinsLabel.Text = string.format("Wins: %d", localWins)
	end
end)
