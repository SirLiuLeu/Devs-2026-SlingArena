--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local slingPawns = Workspace:WaitForChild("SlingPawns")

local HEIGHT_OFFSET = 12
local DISTANCE_OFFSET = 18
local LOOK_HEIGHT = 3
local FOLLOW_SHARPNESS = 10

local desiredCFrame: CFrame? = nil

local function resolveRootPart(): BasePart?
	local pawn = slingPawns:FindFirstChild(player.Name)
	if not pawn or not pawn:IsA("Model") then
		return nil
	end

	local root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox")
	if root and root:IsA("BasePart") then
		if pawn.PrimaryPart == nil then
			pawn.PrimaryPart = root
		end
		return root
	end

	local fallback = pawn:FindFirstChildWhichIsA("BasePart")
	if fallback then
		pawn.PrimaryPart = fallback
		return fallback
	end

	return nil
end

local function computeDesiredCFrame(root: BasePart): CFrame
	local camera = Workspace.CurrentCamera
	local lookTarget = root.Position + Vector3.new(0, LOOK_HEIGHT, 0)

	local velocity = root.AssemblyLinearVelocity
	local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local followDirection = if planarVelocity.Magnitude > 0.1 then planarVelocity.Unit else Vector3.new(0, 0, -1)

	if camera then
		local currentLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		if currentLook.Magnitude > 0.1 and planarVelocity.Magnitude <= 0.1 then
			followDirection = currentLook.Unit
		end
	end

	local cameraPosition = lookTarget - (followDirection * DISTANCE_OFFSET) + Vector3.new(0, HEIGHT_OFFSET, 0)
	return CFrame.lookAt(cameraPosition, lookTarget)
end

RunService.RenderStepped:Connect(function(deltaTime)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	local root = resolveRootPart()
	if not root then
		desiredCFrame = nil
		return
	end

	local target = computeDesiredCFrame(root)
	if desiredCFrame == nil then
		desiredCFrame = target
		camera.CFrame = target
		return
	end

	local alpha = 1 - math.exp(-FOLLOW_SHARPNESS * deltaTime)
	desiredCFrame = desiredCFrame:Lerp(target, alpha)
	camera.CFrame = desiredCFrame
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	desiredCFrame = nil
end)

slingPawns.ChildAdded:Connect(function(child)
	if child.Name == player.Name then
		desiredCFrame = nil
	end
end)
