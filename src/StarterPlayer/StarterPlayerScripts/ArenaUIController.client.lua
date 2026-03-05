
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local arenaUI = playerGui:WaitForChild("ArenaUI")
local joinButton = arenaUI:WaitForChild("JoinArenaButton")
local leaveButton = arenaUI:WaitForChild("LeaveArenaButton")

local remotesRoot = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local joinArena = remotesRoot:WaitForChild("JoinArena")
local leaveArena = remotesRoot:WaitForChild("LeaveArena")

joinButton.MouseButton1Click:Connect(function()
	joinArena:FireServer()
end)

leaveButton.MouseButton1Click:Connect(function()
	leaveArena:FireServer()
end)