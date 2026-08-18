--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PlayerModeState = require(ReplicatedStorage.Shared.Utils.PlayerModeState)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local player = Players.LocalPlayer
local launcherPawns = Workspace:WaitForChild("LauncherPawns")
local cameraResolveGeneration = 0

local function resolveHumanSubject(): Instance?
	local character = PawnLocator.GetHumanCharacterByPlayer(player)
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end

	return PawnLocator.GetRootPart(character)
end

local function resolveLauncherSubject(): Instance?
	local pawn = PawnLocator.GetLauncherPawnByPlayer(player)
	return PawnLocator.GetRootPart(pawn)
end

local function resolveCameraSubject(): Instance?
	if not PlayerModeState.IsLauncherMode(player, nil) then
		return resolveHumanSubject()
	end
	return resolveLauncherSubject()
end

local function applyDefaultCamera()
	cameraResolveGeneration += 1
	local generation = cameraResolveGeneration

	local function tryResolve(attempt: number)
		if generation ~= cameraResolveGeneration then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			if attempt < 20 then
				task.delay(0.1, function()
					tryResolve(attempt + 1)
				end)
			end
			return
		end

		camera.CameraType = Enum.CameraType.Custom
		local subject = resolveCameraSubject()
		if subject then
			camera.CameraSubject = subject
			return
		end

		if attempt < 20 then
			task.delay(0.1, function()
				tryResolve(attempt + 1)
			end)
		end
	end

	tryResolve(1)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyDefaultCamera)

launcherPawns.ChildAdded:Connect(function(child)
	if child.Name == player.Name or child.Name == (player.Name .. "_Pawn") then
		applyDefaultCamera()
	end
end)

launcherPawns.ChildRemoved:Connect(function(child)
	if child.Name == player.Name or child.Name == (player.Name .. "_Pawn") then
		applyDefaultCamera()
	end
end)

player.CharacterAdded:Connect(function()
	applyDefaultCamera()
end)

player.CharacterRemoving:Connect(function()
	applyDefaultCamera()
end)

player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(applyDefaultCamera)

applyDefaultCamera()
