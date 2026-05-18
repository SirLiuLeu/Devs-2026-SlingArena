--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local clientDoLaunchRemote = remotes:WaitForChild(RemoteContracts.Names.ClientDoLaunch) :: RemoteEvent

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
	if planar.Magnitude <= 0.001 then
		return nil
	end

	return planar.Unit
end

clientDoLaunchRemote.OnClientEvent:Connect(function(direction: any, initialSpeed: any, serverMass: any)
	local launchDirection = resolvePlanarDirection(direction)
	if not launchDirection or typeof(initialSpeed) ~= "number" or initialSpeed <= 0 then
		return
	end

	local root = getCharacterRoot()
	if not root or root.Anchored then
		return
	end

	local mass = if typeof(serverMass) == "number" and serverMass > 0 then serverMass else root.AssemblyMass
	if mass <= 0 then
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0, currentVelocity.Y, 0)
	root:ApplyImpulse(launchDirection * (mass * initialSpeed))
end)
