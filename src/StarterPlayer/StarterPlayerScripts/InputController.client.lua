--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local moveRequestRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest) :: RemoteEvent
local launcherPawns = Workspace:WaitForChild("LauncherPawns")


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

local function isLauncherMode(): boolean
	return player:GetAttribute("ActivePlayerMode") ~= GameStates.PlayerMode.Human
end

local function resetLauncherInput()
	for keyCode in pairs(keyboardState) do
		keyboardState[keyCode] = false
	end
	actionState.forward = 0
	actionState.backward = 0
	actionState.left = 0
	actionState.right = 0
	lastSentVector = Vector3.zero
	lastSentAt = 0
end

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
	if output.Magnitude < PhysicsConfig.Movement.MobileDeadzone then
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
	local joystickAim = player:GetAttribute("LauncherAimDirection")
	if typeof(joystickAim) == "Vector3" then
		local planarJoystickAim = Vector3.new(joystickAim.X, 0, joystickAim.Z)
		if planarJoystickAim.Magnitude >= PhysicsConfig.Movement.InputDeadzone then
			return planarJoystickAim.Unit
		end
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local planarLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if planarLook.Magnitude < PhysicsConfig.Movement.InputDeadzone then
		return Vector3.new(0, 0, -1)
	end
	return planarLook.Unit
end

local function onDirectionalAction(directionName: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not isLauncherMode() then
		actionState[directionName] = 0
		return Enum.ContextActionResult.Pass
	end
	local pressed = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	actionState[directionName] = if pressed then 1 else 0
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("LauncherForward", function(_, state)
	return onDirectionalAction("forward", state)
end, false, Enum.PlayerActions.CharacterForward)
ContextActionService:BindAction("LauncherBackward", function(_, state)
	return onDirectionalAction("backward", state)
end, false, Enum.PlayerActions.CharacterBackward)
ContextActionService:BindAction("LauncherLeft", function(_, state)
	return onDirectionalAction("left", state)
end, false, Enum.PlayerActions.CharacterLeft)
ContextActionService:BindAction("LauncherRight", function(_, state)
	return onDirectionalAction("right", state)
end, false, Enum.PlayerActions.CharacterRight)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		player:SetAttribute("CameraRotateHeld", true)
	end

	if gameProcessed then
		return
	end
	if isLauncherMode() and keyboardState[input.KeyCode] ~= nil then
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

launcherPawns.ChildAdded:Connect(function(child)
	if child.Name ~= player.Name and child.Name ~= (player.Name .. "_Pawn") then
		return
	end
	resetLauncherInput()
	player:SetAttribute("CameraRotateHeld", false)
end)

player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(function()
	if not isLauncherMode() then
		resetLauncherInput()
		player:SetAttribute("CameraRotateHeld", false)
	end
end)

RunService.RenderStepped:Connect(function()
	if not isLauncherMode() then
		return
	end

	local now = os.clock()
	if now - lastSentAt < PhysicsConfig.Movement.MoveSendInterval then
		return
	end

	local input = computeMoveInput()
	moveRequestRemote:FireServer(input, computeAimDirection())
	lastSentVector = input
	lastSentAt = now
end)
