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

local PLAYER_MODULE_TIMEOUT_SECONDS = 10
local LAUNCHER_ACTIONS = {
	LauncherForward = Enum.PlayerActions.CharacterForward,
	LauncherBackward = Enum.PlayerActions.CharacterBackward,
	LauncherLeft = Enum.PlayerActions.CharacterLeft,
	LauncherRight = Enum.PlayerActions.CharacterRight,
}

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

local actionDirections = {
	LauncherForward = "forward",
	LauncherBackward = "backward",
	LauncherLeft = "left",
	LauncherRight = "right",
}

local lastSentAt = 0
local launcherInputActive = false
local controls: any = nil
local printedHumanAssignment = false
local printedHumanInput = false
local printedHumanPhysics = false

local function getPlayerControls(): any
	
	if controls then
		return controls
	end
	local playerScripts = player:WaitForChild("PlayerScripts", PLAYER_MODULE_TIMEOUT_SECONDS)
	if not playerScripts then
		warn("[InputController] PlayerScripts missing; native controls could not be resolved")
		return nil
	end

	local playerModule = playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_TIMEOUT_SECONDS)
	if not playerModule then
		warn("[InputController] PlayerModule missing; native controls could not be resolved")
		return nil
	end
	local module = require(playerModule)
	if type(module) ~= "table" or type(module.GetControls) ~= "function" then
		warn("[InputController] PlayerModule did not expose GetControls")
		return nil
	end

	controls = module:GetControls()
	return controls
end

local function setNativeControlsEnabled(enabled: boolean)
	local playerControls = getPlayerControls()
	if not playerControls then
		return
	end

	if enabled then
		playerControls:Enable()
	else
		playerControls:Disable()
	end
end

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

	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.new(input2D.X, 0, input2D.Y)
	end

	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if forward.Magnitude < PhysicsConfig.Movement.InputDeadzone or right.Magnitude < PhysicsConfig.Movement.InputDeadzone then
		return Vector3.new(input2D.X, 0, input2D.Y)
	end

	local worldInput = (right.Unit * input2D.X) + (forward.Unit * input2D.Y)
	return if worldInput.Magnitude > 1 then worldInput.Unit else worldInput
end

local function onLauncherAction(actionName: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not launcherInputActive then
		return Enum.ContextActionResult.Pass
	end

	local directionName = actionDirections[actionName]
	if directionName then
		local pressed = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		actionState[directionName] = if pressed then 1 else 0
	end

	return Enum.ContextActionResult.Sink
end

local function bindLauncherActions()
	for actionName, playerAction in pairs(LAUNCHER_ACTIONS) do
		ContextActionService:BindAction(actionName, onLauncherAction, false, playerAction)
	end
end

local function unbindLauncherActions()
	for actionName in pairs(LAUNCHER_ACTIONS) do
		ContextActionService:UnbindAction(actionName)
	end
end

local function activateLauncherInput()
	if launcherInputActive then
		return
	end
	launcherInputActive = true
	resetLauncherInput()
	setNativeControlsEnabled(true)
	bindLauncherActions()
end

local function deactivateLauncherInput()
	if not launcherInputActive then
		setNativeControlsEnabled(true)
		return
	end
	launcherInputActive = false
	unbindLauncherActions()
	resetLauncherInput()
	player:SetAttribute("CameraRotateHeld", false)
	setNativeControlsEnabled(true)
end

local function syncInputMode()
	if isLauncherMode() then
		printedHumanAssignment = false
		printedHumanInput = false
		printedHumanPhysics = false
		activateLauncherInput()
	else
		deactivateLauncherInput()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		player:SetAttribute("CameraRotateHeld", true)
	end

	if gameProcessed then
		return
	end
	if launcherInputActive and keyboardState[input.KeyCode] ~= nil then
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
	if launcherInputActive then
		resetLauncherInput()
	end
	player:SetAttribute("CameraRotateHeld", false)
end)

player.CharacterAdded:Connect(function()
	task.defer(syncInputMode)
end)

player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(syncInputMode)

RunService.RenderStepped:Connect(function()
	if not launcherInputActive then
		return
	end

	local now = os.clock()
	if now - lastSentAt < PhysicsConfig.Movement.MoveSendInterval then
		return
	end

	moveRequestRemote:FireServer(computeMoveInput())
	lastSentAt = now
end)

syncInputMode()
