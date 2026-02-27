--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local aimRemote = remotes:WaitForChild("SlingAimRemote") :: RemoteEvent
local releaseRemote = remotes:WaitForChild("SlingReleaseRemote") :: RemoteEvent

local charging = false
local aiming = false
local currentCharge = 0
local lastAimSent = 0
local aimDirection = Vector3.new(0, 0, -1)

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

	if os.clock() - lastAimSent >= 0.05 then
		lastAimSent = os.clock()
		aimRemote:FireServer(aimDirection)
	end
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
	currentCharge = 0
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
	releaseRemote:FireServer(aimDirection, currentCharge)
end)

RunService.RenderStepped:Connect(function(dt)
	if aiming then
		updateAimFromMouse()
	end

	if charging then
		currentCharge = math.clamp(currentCharge + (Config.ChargeRatePerSecond * dt), 0, Config.MaxCharge)
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
