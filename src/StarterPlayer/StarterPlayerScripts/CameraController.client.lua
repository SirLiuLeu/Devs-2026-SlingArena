--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PlayerModeState = require(ReplicatedStorage.Shared.Utils.PlayerModeState)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local player = Players.LocalPlayer
local launcherPawns = Workspace:WaitForChild("LauncherPawns")
local gameplayFeedbackRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent
local cameraResolveGeneration = 0

local cameraShakeStartedAt = 0
local cameraShakeDuration = 0
local cameraShakeIntensity = 0
local cameraShakeSeed = player.UserId % 997

local function receiveCameraShake(message: any)
	if type(message) ~= "table" or message.EventType ~= "CollisionCameraShake" then return end
	local payload = message.Payload
	if type(payload) ~= "table" then return end

	local config = PhysicsConfig.CameraShake
	local impactSpeed = math.max(0, tonumber(payload.ImpactSpeed) or 0)
	local angleFactor = math.clamp(tonumber(payload.AngleFactor) or 0, 0, 1)
	local speedRange = math.max(1, config.MaxImpactSpeed - config.MinImpactSpeed)
	local speedFactor = math.clamp((impactSpeed - config.MinImpactSpeed) / speedRange, 0, 1)
	local intensity = speedFactor * (angleFactor ^ math.max(0, config.AngleExponent or 1))
	if intensity <= 0 then return end

	local now = os.clock()
	local previousProgress = if cameraShakeDuration > 0
		then math.clamp((now - cameraShakeStartedAt) / cameraShakeDuration, 0, 1)
		else 1
	local remainingIntensity = cameraShakeIntensity * ((1 - previousProgress) ^ 2)
	cameraShakeIntensity = math.max(remainingIntensity, intensity)
	cameraShakeStartedAt = now
	cameraShakeDuration = config.MinDuration + ((config.MaxDuration - config.MinDuration) * cameraShakeIntensity)
end

gameplayFeedbackRemote.OnClientEvent:Connect(receiveCameraShake)

local function applyCameraShake()
	if cameraShakeIntensity <= 0 then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local config = PhysicsConfig.CameraShake
	local elapsed = os.clock() - cameraShakeStartedAt
	local progress = math.clamp(elapsed / math.max(cameraShakeDuration, 0.001), 0, 1)
	if progress >= 1 then cameraShakeIntensity = 0; return end

	local intensity = cameraShakeIntensity * ((1 - progress) ^ 2)
	local time = os.clock() * config.Frequency
	local positionOffset = Vector3.new(
		math.noise(time, cameraShakeSeed, 1),
		math.noise(time, cameraShakeSeed, 2),
		0
	) * config.MaxPositionOffset * intensity
	local maxRotation = math.rad(config.MaxRotationDegrees) * intensity
	local rotationOffset = CFrame.Angles(
		math.noise(time, cameraShakeSeed, 3) * maxRotation,
		math.noise(time, cameraShakeSeed, 4) * maxRotation,
		math.noise(time, cameraShakeSeed, 5) * maxRotation
	)

	-- Apply after Roblox updates the base CFrame; never accumulate offsets.
	camera.CFrame = camera.CFrame * CFrame.new(positionOffset) * rotationOffset
end

RunService:BindToRenderStep(
	"SlingArenaCollisionCameraShake",
	Enum.RenderPriority.Camera.Value + 1,
	applyCameraShake
)

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
