--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local moveRequestRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest) :: RemoteEvent
local slingPawns = Workspace:WaitForChild("SlingPawns")

local SEND_INTERVAL_SECONDS = 1 / 20
local MOBILE_DEADZONE = 0.15

local keyboardState = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
}

local actionState = {
	forward = 0,
	backward = 0,
	left = 0,
	right = 0,
}

local lastSentVector = Vector3.zero
local lastSentAt = 0


local function composeInput2D(): Vector2
	local x = 0
	local y = 0

	if keyboardState[Enum.KeyCode.D] then x += 1 end
	if keyboardState[Enum.KeyCode.A] then x -= 1 end
	if keyboardState[Enum.KeyCode.W] then y += 1 end
	if keyboardState[Enum.KeyCode.S] then y -= 1 end

	x += (actionState.right - actionState.left)
	y += (actionState.forward - actionState.backward)

	local output = Vector2.new(x, y)
	if output.Magnitude > 1 then
		return output.Unit
	end
	if output.Magnitude < MOBILE_DEADZONE then
		return Vector2.zero
	end
	return output
end

local function computeMoveInput(): Vector3
	local input2D = composeInput2D()
	if input2D.Magnitude <= 0 then
		return Vector3.zero
	end

	return Vector3.new(input2D.X, 0, input2D.Y)
end

local function computeAimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local planarLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if planarLook.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return planarLook.Unit
end

local function onDirectionalAction(directionName: string, state: Enum.UserInputState): Enum.ContextActionResult
	local pressed = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	actionState[directionName] = if pressed then 1 else 0
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("SlingForward", function(_, state)
	return onDirectionalAction("forward", state)
end, false, Enum.PlayerActions.CharacterForward)
ContextActionService:BindAction("SlingBackward", function(_, state)
	return onDirectionalAction("backward", state)
end, false, Enum.PlayerActions.CharacterBackward)
ContextActionService:BindAction("SlingLeft", function(_, state)
	return onDirectionalAction("left", state)
end, false, Enum.PlayerActions.CharacterLeft)
ContextActionService:BindAction("SlingRight", function(_, state)
	return onDirectionalAction("right", state)
end, false, Enum.PlayerActions.CharacterRight)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		player:SetAttribute("CameraRotateHeld", true)
	end

	if gameProcessed then
		return
	end
	if keyboardState[input.KeyCode] ~= nil then
		keyboardState[input.KeyCode] = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		player:SetAttribute("CameraRotateHeld", false)
	end

	if keyboardState[input.KeyCode] ~= nil then
		keyboardState[input.KeyCode] = false
	end
end)

slingPawns.ChildAdded:Connect(function(child)
	if child.Name ~= player.Name and child.Name ~= (player.Name .. "_Pawn") then
		return
	end
	for keyCode in pairs(keyboardState) do
		keyboardState[keyCode] = false
	end
	actionState.forward = 0
	actionState.backward = 0
	actionState.left = 0
	actionState.right = 0
	player:SetAttribute("CameraRotateHeld", false)
	lastSentVector = Vector3.zero
	lastSentAt = 0
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastSentAt < SEND_INTERVAL_SECONDS then
		return
	end

	local input = computeMoveInput()
	moveRequestRemote:FireServer(input, computeAimDirection())
	lastSentVector = input
	lastSentAt = now
end)
