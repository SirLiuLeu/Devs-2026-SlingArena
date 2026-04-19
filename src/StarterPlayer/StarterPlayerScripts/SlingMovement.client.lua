--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function buildInputState()
	return {
		W = keyStates[Enum.KeyCode.W],
		A = keyStates[Enum.KeyCode.A],
		S = keyStates[Enum.KeyCode.S],
		D = keyStates[Enum.KeyCode.D],
	}
end

local lastSentState = buildInputState()

local function didStateChange(nextState): boolean
	return nextState.W ~= lastSentState.W
		or nextState.A ~= lastSentState.A
		or nextState.S ~= lastSentState.S
		or nextState.D ~= lastSentState.D
end

local function sendInputIfChanged()
	local nextState = buildInputState()
	if not didStateChange(nextState) then
		return
	end
	lastSentState = nextState
	moveRequestRemote:FireServer(nextState)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if keyStates[input.KeyCode] ~= nil then
		keyStates[input.KeyCode] = true
		sendInputIfChanged()
	end

end)

UserInputService.InputEnded:Connect(function(input)

	if keyStates[input.KeyCode] ~= nil then
		keyStates[input.KeyCode] = false
		sendInputIfChanged()
	end

end)

player.CharacterAdded:Connect(function()
	local changed = false
	for keyCode in pairs(keyStates) do
		if keyStates[keyCode] then
			changed = true
		end
		keyStates[keyCode] = false
	end
	if changed then
		sendInputIfChanged()
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	local changed = false
	for keyCode in pairs(keyStates) do
		if keyStates[keyCode] then
			changed = true
		end
		keyStates[keyCode] = false
	end
	if changed then
		sendInputIfChanged()
	end
end)
