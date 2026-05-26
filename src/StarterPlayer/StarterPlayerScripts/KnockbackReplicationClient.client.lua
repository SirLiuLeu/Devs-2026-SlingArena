--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local knockbackRemote = remotes:WaitForChild(RemoteContracts.Names.KnockbackReplication) :: RemoteEvent

local DEFAULT_KNOCKBACK_DURATION = 0.12

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

knockbackRemote.OnClientEvent:Connect(function(knockbackVelocity: any, duration: any)
	print("[KnockbackReplication] Received from server:", "velocity=", knockbackVelocity, "duration=", duration)

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
	print("[KnockbackReplication] Planar velocity:", planarVelocity, "magnitude=", planarVelocity.Magnitude)

	if planarVelocity.Magnitude <= 0 then
		warn("[KnockbackReplication] Zero planar velocity, skipping")
		return
	end

	local attachment = root:FindFirstChild("KnockbackAttachment")
	if not (attachment and attachment:IsA("Attachment")) then
		attachment = Instance.new("Attachment")
		attachment.Name = "KnockbackAttachment"
		attachment.Parent = root
	end

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "KnockbackLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = planarVelocity
	linearVelocity.MaxForce = math.max(root.AssemblyMass, 1) * 12000
	linearVelocity.Parent = root

	local durationSeconds = DEFAULT_KNOCKBACK_DURATION
	if typeof(duration) == "number" then
		durationSeconds = math.max(0, duration)
	end

	print(
		"[KnockbackReplication] Applying LinearVelocity:",
		"VectorVelocity=", linearVelocity.VectorVelocity,
		"MaxForce=", linearVelocity.MaxForce,
		"Duration=", durationSeconds
	)

	Debris:AddItem(linearVelocity, durationSeconds)
end)