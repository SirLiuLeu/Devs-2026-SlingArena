--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local chargeStartRemote = remotes:WaitForChild(RemoteContracts.Names.ChargeStart) :: RemoteEvent
local chargeReleaseRemote = remotes:WaitForChild(RemoteContracts.Names.ChargeRelease) :: RemoteEvent

local charging = false
local aiming = false
local aimDirection = Vector3.new(0, 0, -1)

local function bindCameraToCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end
	if camera and humanoid then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = humanoid
	end
end

player.CharacterAdded:Connect(bindCameraToCharacter)
if player.Character then
	bindCameraToCharacter(player.Character)
end

local previewPart = Instance.new("Part")
previewPart.Name = "AimPreview"
previewPart.Anchored = true
previewPart.CanCollide = false
previewPart.Color = Color3.fromRGB(255, 238, 99)
previewPart.Material = Enum.Material.Neon
previewPart.Size = Vector3.new(0.4, 0.4, 10)
previewPart.Transparency = 1
previewPart.Parent = workspace

local function getRoot()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isClickingPawn()
	local target = mouse.Target
	if not target then
		return false
	end
	local character = player.Character
	if not character then
		return false
	end
	return target:IsDescendantOf(character)
end

local function updateAimFromMouse()
	local root = getRoot()
	if not root then
		return
	end
	local hitPos = mouse.Hit.Position
	local planar = Vector3.new(hitPos.X - root.Position.X, 0, hitPos.Z - root.Position.Z)
	if planar.Magnitude < 0.001 then
		return
	end
	aimDirection = planar.Unit

	previewPart.Transparency = 0.1
	previewPart.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 2, 0), root.Position + Vector3.new(0, 2, 0) + aimDirection) * CFrame.new(0, 0, -5)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not isClickingPawn() then
		return
	end

	aiming = true
	charging = true
	chargeStartRemote:FireServer(aimDirection)
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not charging then
		return
	end

	charging = false
	aiming = false
	previewPart.Transparency = 1
	chargeReleaseRemote:FireServer(aimDirection)
end)

RunService.RenderStepped:Connect(function(dt)
	if aiming then
		updateAimFromMouse()
	end

	local root = getRoot()
	if camera and root then
		local sizeScale = root.Size.X / 4
		local followDistance = 18 + (sizeScale * 3)
		local desiredPosition = root.Position - aimDirection * followDistance + Vector3.new(0, 12 + sizeScale * 2, 0)
		local desiredCFrame = CFrame.lookAt(desiredPosition, root.Position)
		camera.CFrame = camera.CFrame:Lerp(desiredCFrame, math.clamp(dt * 6, 0, 1))
	end
end)
