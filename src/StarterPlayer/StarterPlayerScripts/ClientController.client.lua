--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")

local startCharge = remotes:WaitForChild("StartCharge") :: RemoteEvent
local releaseCharge = remotes:WaitForChild("ReleaseCharge") :: RemoteEvent
local stateUpdate = remotes:WaitForChild("StateUpdate") :: RemoteEvent

local charging = false
local camera = workspace.CurrentCamera
local localState: any = nil

stateUpdate.OnClientEvent:Connect(function(state)
	localState = state
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not charging then
		charging = true
		startCharge:FireServer()
	end
	if input.KeyCode == Enum.KeyCode.R then
		(remotes:WaitForChild("PrestigeReset") :: RemoteEvent):FireServer()
	end
	if input.KeyCode == Enum.KeyCode.B then
		(remotes:WaitForChild("PurchaseMatchBuff") :: RemoteEvent):FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and charging then
		charging = false
		local direction = Vector3.new(0, 0, -1)
		if camera then
			direction = camera.CFrame.LookVector
		end
		releaseCharge:FireServer(direction)
	end
end)

RunService.RenderStepped:Connect(function()
	if localState and localState.IsAlive == false then
		charging = false
	end
end)
