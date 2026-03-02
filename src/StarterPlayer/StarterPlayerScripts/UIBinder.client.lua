--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")

local joinArena = remotes:WaitForChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
local leaveArena = remotes:WaitForChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
local attrUpgrade = remotes:WaitForChild(RemoteContracts.Names.AttributeUpgrade) :: RemoteEvent
local stateUpdate = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent
local uiStateUpdate = remotes:WaitForChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
local roundResult = remotes:WaitForChild(RemoteContracts.Names.RoundResult) :: RemoteEvent

local lobby = playerGui:WaitForChild("LobbyUI")
local stats = playerGui:WaitForChild("StatsUI")
local match = playerGui:WaitForChild("MatchUI")

local statusLabel = lobby.Frame.StatusLabel :: TextLabel
lobby.Frame.JoinButton.MouseButton1Click:Connect(function() joinArena:FireServer() end)
lobby.Frame.LeaveButton.MouseButton1Click:Connect(function() leaveArena:FireServer() end)

stats.ToggleButton.MouseButton1Click:Connect(function() stats.StatsPanel.Visible = not stats.StatsPanel.Visible end)
stats.StatsPanel.CloseButton.MouseButton1Click:Connect(function() stats.StatsPanel.Visible = false end)
stats.StatsPanel.DamageRow.MouseButton1Click:Connect(function() attrUpgrade:FireServer("Damage") end)
stats.StatsPanel.HPRow.MouseButton1Click:Connect(function() attrUpgrade:FireServer("MaxHP") end)
stats.StatsPanel.RegenRow.MouseButton1Click:Connect(function() attrUpgrade:FireServer("Regen") end)
stats.StatsPanel.RangeRow.MouseButton1Click:Connect(function() attrUpgrade:FireServer("Range") end)
stats.StatsPanel.ReflectRow.MouseButton1Click:Connect(function() attrUpgrade:FireServer("Reflect") end)

stateUpdate.OnClientEvent:Connect(function(state)
	stats.StatsPanel.DamageRow.Text = string.format("Damage: %.1f (+)", state.BaseDamage or 0)
	stats.StatsPanel.HPRow.Text = string.format("HP: %.1f (+)", state.MaxHP or 0)
	stats.StatsPanel.RegenRow.Text = string.format("Regen: %d (+)", (state.Attributes and state.Attributes.Regen) or 0)
	stats.StatsPanel.RangeRow.Text = string.format("Range: %d (+)", (state.Attributes and state.Attributes.Range) or 0)
	stats.StatsPanel.ReflectRow.Text = string.format("Reflect: %d%% (+)", math.floor(((state.Attributes and state.Attributes.Reflect) or 0) * 1))
end)

uiStateUpdate.OnClientEvent:Connect(function(payload)
	statusLabel.Text = string.format("Status: %s", payload.State or "Lobby")
	match.Frame.StatusLabel.Text = string.format("Status: %s", payload.State or "Lobby")
	match.Frame.TimerLabel.Text = string.format("Time: %d", math.floor(payload.TimeLeft or 0))
	match.Frame.AlivePlayersLabel.Text = string.format("Alive: %d", payload.AlivePlayers or 0)
	if payload.State ~= "RoundEnd" then
		match.Frame.WinnerPopup.Visible = false
	end
end)

roundResult.OnClientEvent:Connect(function(payload)
	match.Frame.WinnerPopup.Text = "Winner: " .. tostring(payload.Winner)
	match.Frame.WinnerPopup.Visible = true
end)
