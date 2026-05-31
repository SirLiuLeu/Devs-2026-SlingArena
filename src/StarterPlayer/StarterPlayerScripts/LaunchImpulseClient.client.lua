--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local VelocityDecay = require(ReplicatedStorage.Shared.Utils.VelocityDecay)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local clientDoLaunchRemote = remotes:WaitForChild(RemoteContracts.Names.ClientDoLaunch) :: RemoteEvent
local launchVelocityReportRemote = remotes:WaitForChild(RemoteContracts.Names.LaunchVelocityReport) :: RemoteEvent
local velocityCorrectionRemote = remotes:WaitForChild(RemoteContracts.Names.VelocityCorrection) :: RemoteEvent
local stateUpdateRemote = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent

local isLaunching = false
local nextVelocityReportAt = 0
local correctionStartVelocity = Vector3.zero
local correctionTargetVelocity = Vector3.zero
local correctionElapsed = 0
local correctionDuration = 0

local function getCharacterRoot(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local primaryPart = character.PrimaryPart
	if primaryPart and primaryPart:IsA("BasePart") then
		return primaryPart
	end

	local hitbox = character:FindFirstChild("Hitbox", true)
	if hitbox and hitbox:IsA("BasePart") then
		return hitbox
	end

	return nil
end

local function resolvePlanarDirection(direction: any): Vector3?
	if typeof(direction) ~= "Vector3" then
		return nil
	end

	local planar = Vector3.new(direction.X, 0, direction.Z)
	if planar.Magnitude <= PhysicsConfig.Launch.DirectionDeadzone then
		return nil
	end

	return planar.Unit
end

local function applyDefaultPhysicalProperties(root: BasePart)
	root.CustomPhysicalProperties = PhysicsConfig.DefaultProperties
end

local function applyLaunchPhysicalProperties(root: BasePart)
	root.CustomPhysicalProperties = PhysicsConfig.LaunchProperties
end

local function setHorizontalVelocity(root: BasePart, horizontalVelocity: Vector3)
	local currentVelocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, currentVelocity.Y, horizontalVelocity.Z)
end

local function endPredictedLaunch()
	isLaunching = false
	nextVelocityReportAt = 0
	correctionDuration = 0
	local root = getCharacterRoot()
	if root then
		applyDefaultPhysicalProperties(root)
	end
end

clientDoLaunchRemote.OnClientEvent:Connect(function(direction: any, initialSpeed: any, _serverMass: any)
	local launchDirection = resolvePlanarDirection(direction)
	if not launchDirection or typeof(initialSpeed) ~= "number" or initialSpeed <= 0 then
		return
	end

	local root = getCharacterRoot()
	if not root or root.Anchored then
		return
	end

	isLaunching = true
	nextVelocityReportAt = 0
	correctionDuration = 0
	applyLaunchPhysicalProperties(root)
	setHorizontalVelocity(root, launchDirection * math.min(initialSpeed, PhysicsConfig.Launch.InitialVelocityCap))
end)

velocityCorrectionRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" or typeof(payload.velocity) ~= "Vector3" then
		return
	end
	local root = getCharacterRoot()
	if not root then
		return
	end

	correctionStartVelocity = VelocityDecay.FlattenXZ(root.AssemblyLinearVelocity)
	correctionTargetVelocity = VelocityDecay.FlattenXZ(payload.velocity)
	correctionElapsed = 0
	correctionDuration = math.max(1 / 60, payload.blendSeconds or PhysicsConfig.Launch.VelocityCorrectionBlendSeconds)
	isLaunching = true
	applyLaunchPhysicalProperties(root)
end)

stateUpdateRemote.OnClientEvent:Connect(function(state: any)
	if type(state) ~= "table" or typeof(state.MovementState) ~= "string" then
		return
	end
	local movementState = state.MovementState
	if movementState == GameStates.PlayerState.Launching or movementState == "Launching" then
		isLaunching = true
		local root = getCharacterRoot()
		if root then
			applyLaunchPhysicalProperties(root)
		end
	else
		endPredictedLaunch()
	end
end)

player.CharacterAdded:Connect(function()
	isLaunching = false
	correctionDuration = 0
	nextVelocityReportAt = 0
end)

RunService.Heartbeat:Connect(function(dt)
	local root = getCharacterRoot()
	if not root then
		return
	end

	if not isLaunching then
		applyDefaultPhysicalProperties(root)
		return
	end

	applyLaunchPhysicalProperties(root)
	local fullVelocity = root.AssemblyLinearVelocity
	local horizontalVelocity = VelocityDecay.FlattenXZ(fullVelocity)
	local decayedVelocity = VelocityDecay.StepVelocity(horizontalVelocity, dt)

	if correctionDuration > 0 then
		correctionElapsed += dt
		local alpha = math.clamp(correctionElapsed / correctionDuration, 0, 1)
		decayedVelocity = correctionStartVelocity:Lerp(correctionTargetVelocity, alpha)
		if alpha >= 1 then
			correctionDuration = 0
		end
	end

	setHorizontalVelocity(root, decayedVelocity)
	if decayedVelocity.Magnitude <= PhysicsConfig.Launch.StopSpeed then
		isLaunching = false
		applyDefaultPhysicalProperties(root)
	end

	local now = os.clock()
	if isLaunching and now >= nextVelocityReportAt then
		nextVelocityReportAt = now + PhysicsConfig.Launch.VelocityReportInterval
		launchVelocityReportRemote:FireServer({
			velocity = root.AssemblyLinearVelocity,
			movementState = "Launching",
			clientTime = now,
		})
	end
end)
