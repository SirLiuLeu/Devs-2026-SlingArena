--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local launcherPawns = Workspace:WaitForChild("LauncherPawns")

local function findPawnModel(): Model?
	local bySuffix = launcherPawns:FindFirstChild(player.Name .. "_Pawn")
	if bySuffix and bySuffix:IsA("Model") then
		return bySuffix
	end

	local byName = launcherPawns:FindFirstChild(player.Name)
	if byName and byName:IsA("Model") then
		return byName
	end

	return nil
end

local function resolveRootPart(): BasePart?
	local pawn = findPawnModel()
	if not pawn then
		return nil
	end
	local root = pawn:FindFirstChild("Hitbox", true) or pawn.PrimaryPart
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

local function applyDefaultCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	local maxAttempts = 20
	local attempt = 0

	local function tryResolve()
		local root = resolveRootPart()
		if root then
			camera.CameraSubject = root
			return
		end

		attempt += 1
		if attempt < maxAttempts then
			task.delay(0.1, tryResolve)
		else
		end
	end

	tryResolve()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyDefaultCamera)

launcherPawns.ChildAdded:Connect(function(child)
	if child.Name == player.Name or child.Name == (player.Name .. "_Pawn") then
		applyDefaultCamera()
	end
end)

applyDefaultCamera()
