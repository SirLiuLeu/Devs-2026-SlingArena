--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteContracts"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")

local joinArena = remotes:WaitForChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
local leaveArena = remotes:WaitForChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
local stateUpdate = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent
local uiStateUpdate = remotes:WaitForChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
local roundResult = remotes:WaitForChild(RemoteContracts.Names.RoundResult) :: RemoteEvent

-- ========= LOBBY UI =========

local lobbyGui = playerGui:WaitForChild("LobbyUI")
local lobbyFrame = lobbyGui:WaitForChild("LobbyUI")
local lobbyRoot = lobbyFrame:WaitForChild("RootFrame")

local lobbyStatusLabel = lobbyRoot:WaitForChild("StatusLabel") :: TextLabel
local joinButton = lobbyRoot:WaitForChild("JoinButton") :: TextButton
local leaveButton = lobbyRoot:WaitForChild("LeaveButton") :: TextButton

joinButton.MouseButton1Click:Connect(function()
	joinArena:FireServer()
end)

leaveButton.MouseButton1Click:Connect(function()
	leaveArena:FireServer()
end)

-- ========= STATS UI =========

local statsGui = playerGui:WaitForChild("StatsUI")
local statsFrame = statsGui:WaitForChild("StatsUI")
local statsRoot = statsFrame:WaitForChild("RootFrame")

local scoreLabel = statsRoot:WaitForChild("ScoreLabel") :: TextLabel
local goldLabel = statsRoot:WaitForChild("GoldLabel") :: TextLabel
local winsLabel = statsRoot:WaitForChild("WinsLabel") :: TextLabel

-- ========= MATCH UI =========

local matchGui = playerGui:WaitForChild("MatchUI")
local matchFrame = matchGui:WaitForChild("MatchUI")
local matchRoot = matchFrame:WaitForChild("RootFrame")

local matchStatusLabel = matchRoot:WaitForChild("StatusLabel") :: TextLabel
local timerLabel = matchRoot:WaitForChild("TimerLabel") :: TextLabel
local aliveLabel = matchRoot:WaitForChild("AlivePlayersLabel") :: TextLabel
local winnerPopup = matchRoot:WaitForChild("WinnerPopup") :: TextLabel

-- ========= STATE =========

local localWins = 0

-- ========= REMOTE EVENTS =========

stateUpdate.OnClientEvent:Connect(function(state)
	scoreLabel.Text = string.format("Score: %d", math.floor(state.Exp or 0))
	goldLabel.Text = string.format("Gold: %d", math.floor(state.Diamonds or 0))
	winsLabel.Text = string.format("Wins: %d", localWins)
end)

uiStateUpdate.OnClientEvent:Connect(function(payload)
	local stateName = payload.State or "Lobby"
	local timeLeft = math.floor(payload.TimeLeft or 0)
	local alive = payload.AlivePlayers or 0

	lobbyStatusLabel.Text = string.format("Status: %s", stateName)
	matchStatusLabel.Text = string.format("Status: %s", stateName)
	timerLabel.Text = string.format("Time: %d", timeLeft)
	aliveLabel.Text = string.format("Alive: %d", alive)

	if stateName ~= "RoundEnd" then
		winnerPopup.Visible = false
	end
end)

roundResult.OnClientEvent:Connect(function(payload)
	winnerPopup.Text = "Winner: " .. tostring(payload.Winner)
	winnerPopup.Visible = true

	if payload.Winner == player.Name then
		localWins += 1
		winsLabel.Text = string.format("Wins: %d", localWins)
	end
end)