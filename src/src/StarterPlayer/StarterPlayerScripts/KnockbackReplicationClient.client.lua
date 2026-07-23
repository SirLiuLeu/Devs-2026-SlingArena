--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local knockbackRemote = remotes:WaitForChild(RemoteContracts.Names.KnockbackReplication) :: RemoteEvent

local MIN_ASSEMBLY_MASS = 0.001

local function getCharacterRoot(): BasePart?
	return PawnLocator.GetRootPart(PawnLocator.GetLocalPawn())
end

knockbackRemote.OnClientEvent:Connect(function(knockbackDirection: any, knockbackSpeed: any)
	if typeof(knockbackDirection) ~= "Vector3" then
		warn("[KnockbackReplication] Invalid knockbackDirection type:", typeof(knockbackDirection))
		return
	end
	if type(knockbackSpeed) ~= "number" then
		warn("[KnockbackReplication] Invalid knockbackSpeed type:", type(knockbackSpeed))
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

	local planarDirection = Vector3.new(knockbackDirection.X, 0, knockbackDirection.Z)
	if planarDirection.Magnitude <= 0 then
		warn("[KnockbackReplication] Zero planar direction, skipping")
		return
	end

	local speed = math.max(0, knockbackSpeed)
	if speed <= 0 then
		warn("[KnockbackReplication] Non-positive knockback speed, skipping")
		return
	end

	local direction = planarDirection.Unit
	local mass = math.max(root.AssemblyMass, MIN_ASSEMBLY_MASS)
	local impulse = direction * speed * mass
	root:ApplyImpulse(impulse)
end)
