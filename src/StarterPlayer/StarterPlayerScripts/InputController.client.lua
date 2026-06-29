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
	print("[InputController] Resolving native controls...")
	local playerScripts = player:WaitForChild("PlayerScripts", PLAYER_MODULE_TIMEOUT_SECONDS)
	if not playerScripts then
		warn("[InputController] PlayerScripts missing; native controls could not be resolved")
		return nil
	end

	local playerModule = playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_TIMEOUT_SECONDS)
	if not playerModule then
		print("[InputController] PlayerModule missing; native controls could not be resolved")
		warn("[InputController] PlayerModule missing; native controls could not be resolved")
		return nil
	end
	print("3", playerModule)
	local module = require(playerModule)
	print("4", "module")
	if type(module) ~= "table" or type(module.GetControls) ~= "function" then
		warn("[InputController] PlayerModule did not expose GetControls")
		return nil
	end

	controls = module:GetControls()
	print("[InputController] Native controls resolved", controls)
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
		local character = player.Character
		if character and not printedHumanAssignment then
			printedHumanAssignment = true
			print(string.format(
				"[Human Debug] Client Human Assignment: playerCharacter=%s character=%s mode=%s launcherInputActive=%s",
				tostring(character ~= nil),
				character:GetFullName(),
				tostring(player:GetAttribute("ActivePlayerMode")),
				tostring(launcherInputActive)
			))
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		player:SetAttribute("CameraRotateHeld", true)
	end

	if gameProcessed then
		return
	end
	if not launcherInputActive and not printedHumanInput and keyboardState[input.KeyCode] ~= nil then
		printedHumanInput = true
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		print(string.format(
			"[Human Debug] Human Input Started: key=%s humanoid=%s walkSpeed=%s jumpPower=%s autoRotate=%s state=%s moveDirection=%s",
			input.KeyCode.Name,
			tostring(humanoid ~= nil),
			tostring(humanoid and humanoid.WalkSpeed),
			tostring(humanoid and humanoid.JumpPower),
			tostring(humanoid and humanoid.AutoRotate),
			tostring(humanoid and humanoid:GetState().Name),
			tostring(humanoid and humanoid.MoveDirection)
		))
		task.delay(0.25, function()
			if printedHumanPhysics then
				return
			end
			printedHumanPhysics = true
			local delayedCharacter = player.Character
			local delayedHumanoid = delayedCharacter and delayedCharacter:FindFirstChildOfClass("Humanoid")
			local root = delayedCharacter and delayedCharacter:FindFirstChild("HumanoidRootPart")
			print(string.format(
				"[Human Debug] First Human Movement Physics: characterParent=%s rootParent=%s rootAnchored=%s velocity=%s moveDirection=%s",
				if delayedCharacter and delayedCharacter.Parent then delayedCharacter.Parent:GetFullName() else "nil",
				if root and root.Parent then root.Parent:GetFullName() else "nil",
				tostring(root and root:IsA("BasePart") and root.Anchored),
				tostring(root and root:IsA("BasePart") and root.AssemblyLinearVelocity),
				tostring(delayedHumanoid and delayedHumanoid.MoveDirection)
			))
		end)
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

	moveRequestRemote:FireServer(computeMoveInput(), computeAimDirection())
	lastSentAt = now
end)

syncInputMode()
