--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local knockbackRemote = remotes:WaitForChild(RemoteContracts.Names.KnockbackReplication) :: RemoteEvent

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

knockbackRemote.OnClientEvent:Connect(function(knockbackVelocity: any)
	if typeof(knockbackVelocity) ~= "Vector3" then
		warn("[KnockbackReplication] Invalid knockbackVelocity type:", typeof(knockbackVelocity))
		return
	end

	local root = getCharacterRoot()
	if not root then
		warn("[KnockbackReplication] No character root found")
		return
	end

	if root.Anchored then
		warn("[KnockbackReplication] Root is anchored, skipping knockback")
		return
	end

	local planarVelocity = Vector3.new(knockbackVelocity.X, 0, knockbackVelocity.Z)
	if planarVelocity.Magnitude <= 0 then
		warn("[KnockbackReplication] Zero planar velocity, skipping")
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	local currentPlanar = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	local deltaVelocity = planarVelocity - currentPlanar
	if deltaVelocity.Magnitude <= 0 then
		return
	end

	root:ApplyImpulse(deltaVelocity * root.AssemblyMass)

	print(
		"[KnockbackReplication] Applied one-shot impulse:",
		"TargetVelocityMagnitude=", planarVelocity.Magnitude,
		"DeltaVelocityMagnitude=", deltaVelocity.Magnitude,
		"Mass=", root.AssemblyMass
	)
end)
