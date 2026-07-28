--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local clientDoLaunchRemote = remotes:WaitForChild(RemoteContracts.Names.ClientDoLaunch) :: RemoteEvent
local reportLaunchStoppedRemote = remotes:WaitForChild(RemoteContracts.Names.ReportLaunchStopped) :: RemoteEvent

local activeLaunchId: string? = nil
local stopEvidenceFrames = 0
local monitorConnection: RBXScriptConnection? = nil

local function getCharacterRoot(): BasePart?
	return PawnLocator.GetRootPart(PawnLocator.GetLocalPawn())
end

local function resolvePlanarDirection(direction: any): Vector3?
	if typeof(direction) ~= "Vector3" then
		return nil
	end

	local planar = Vector3.new(direction.X, 0, direction.Z)
	if planar.Magnitude <= 0.001 then
		return nil
	end

	return planar.Unit
end

local function stopMonitoring()
	if monitorConnection then
		monitorConnection:Disconnect()
		monitorConnection = nil
	end
	stopEvidenceFrames = 0
end

local function startStopMonitor(launchId: string)
	stopMonitoring()
	activeLaunchId = launchId
	monitorConnection = RunService.RenderStepped:Connect(function()
		local root = getCharacterRoot()
		if not root or activeLaunchId ~= launchId then
			stopMonitoring()
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if horizontalSpeed <= PhysicsConfig.Launch.StopSpeed then
			stopEvidenceFrames += 1
		else
			stopEvidenceFrames = 0
		end

		if stopEvidenceFrames >= PhysicsConfig.Launch.StopEvidenceFramesRequired then
			reportLaunchStoppedRemote:FireServer({
				launchId = launchId,
				observedSpeed = horizontalSpeed,
			})
			activeLaunchId = nil
			stopMonitoring()
		end
	end)
end

clientDoLaunchRemote.OnClientEvent:Connect(function(direction: any, launchSpeed: any, _serverMass: any, launchId: any)
	local launchDirection = resolvePlanarDirection(direction)
	if not launchDirection or typeof(launchSpeed) ~= "number" or launchSpeed <= 0 or typeof(launchId) ~= "string" then
		return
	end

	local root = getCharacterRoot()
	if not root or root.Anchored then
		return
	end

	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if linearVelocity and linearVelocity:IsA("LinearVelocity") then
		linearVelocity.Enabled = false
	end
	local currentVelocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0, currentVelocity.Y, 0)
	root:ApplyImpulse(launchDirection.Unit * launchSpeed * root.AssemblyMass)
	print("Client applied launch impulse:", launchDirection , launchSpeed , root.AssemblyMass)
	startStopMonitor(launchId)
end)
