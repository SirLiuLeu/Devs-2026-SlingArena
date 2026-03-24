--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local stateUpdateRemote = remotes:FindFirstChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent?

local CAMERA_HEIGHT = 16
local CAMERA_DISTANCE = 26
local CAMERA_LOOK_AHEAD = 18
local CAMERA_ROTATION_SPEED = 8
local MIN_RELEASE_SPEED = 6

local lastMovementState = GameStates.Movement.Idle
local releaseCameraEnabled = false

local function getCharacter(): Model?
	local character = player.Character
	if character and character:IsA("Model") then
		return character
	end
	return nil
end

local function getRootPart(): BasePart?
	local character = getCharacter()
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local primary = character.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	return character:FindFirstChildWhichIsA("BasePart")
end

local function getSlingCameraTarget(): Instance?
	local character = getCharacter()
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end

	return getRootPart()
end

local function applyDefaultCameraSubject()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local target = getSlingCameraTarget()
	if target then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = target
	end
end

local function disableReleaseCamera()
	if not releaseCameraEnabled then
		applyDefaultCameraSubject()
		return
	end

	releaseCameraEnabled = false
	applyDefaultCameraSubject()
end

local function shouldFollowReleaseCamera(): boolean
	return lastMovementState == GameStates.Movement.Launched
end

local function stepReleaseCamera(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local root = getRootPart()
	if not camera or not root or not shouldFollowReleaseCamera() then
		disableReleaseCamera()
		return
	end

	local planarVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	if planarVelocity.Magnitude < MIN_RELEASE_SPEED then
		return
	end

	local direction = planarVelocity.Unit
	local focus = root.Position + Vector3.new(0, 4, 0)
	local desiredPosition = focus - direction * CAMERA_DISTANCE + Vector3.new(0, CAMERA_HEIGHT, 0)
	local desiredFocus = focus + direction * CAMERA_LOOK_AHEAD
	local desiredCFrame = CFrame.lookAt(desiredPosition, desiredFocus)
	local alpha = 1 - math.exp(-CAMERA_ROTATION_SPEED * deltaTime)

	releaseCameraEnabled = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
end

if stateUpdateRemote then
	stateUpdateRemote.OnClientEvent:Connect(function(state)
		if not state then
			return
		end
		lastMovementState = tostring(state.MovementState or GameStates.Movement.Idle)
		if lastMovementState ~= GameStates.Movement.Launched then
			disableReleaseCamera()
		end
	end)
end

player.CharacterAdded:Connect(function()
	task.defer(applyDefaultCameraSubject)
	task.delay(0.2, applyDefaultCameraSubject)
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if releaseCameraEnabled then
		releaseCameraEnabled = false
	end
	task.defer(applyDefaultCameraSubject)
end)

RunService.RenderStepped:Connect(function(deltaTime)
	stepReleaseCamera(deltaTime)
end)

applyDefaultCameraSubject()
