--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function getSlingCameraTarget(): Instance?
	local character = player.Character
	if not character or not character:IsA("Model") then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end

	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return character:FindFirstChildWhichIsA("BasePart")
end

local function applyCameraSubject()
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

player.CharacterAdded:Connect(function()
	task.defer(applyCameraSubject)
	task.delay(0.2, applyCameraSubject)
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(applyCameraSubject)
end)

task.defer(function()
	while player.Parent do
		applyCameraSubject()
		task.wait(1)
	end
end)
