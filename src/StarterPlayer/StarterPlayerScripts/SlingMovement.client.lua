--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local moveRequestRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest) :: RemoteEvent

local keyStates = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
}

local function computeInputVector(): Vector3
	local x = 0
	local z = 0
	if keyStates[Enum.KeyCode.D] then x += 1 end
	if keyStates[Enum.KeyCode.A] then x -= 1 end
	if keyStates[Enum.KeyCode.W] then z += 1 end
	if keyStates[Enum.KeyCode.S] then z -= 1 end
	return Vector3.new(x, 0, z)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if keyStates[input.KeyCode] ~= nil then
		keyStates[input.KeyCode] = true
	end

end)

UserInputService.InputEnded:Connect(function(input)

	if keyStates[input.KeyCode] ~= nil then
		keyStates[input.KeyCode] = false
	end

end)

player.CharacterAdded:Connect(function()

	for keyCode in pairs(keyStates) do
		keyStates[keyCode] = false
	end
end)

RunService.RenderStepped:Connect(function()

	local inputVector = computeInputVector()

	if inputVector.Magnitude > 1 then
		inputVector = inputVector.Unit
	end

	moveRequestRemote:FireServer(inputVector)
end)
