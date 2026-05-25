--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local knockbackRemote = remotes:WaitForChild(RemoteContracts.Names.KnockbackReplication) :: RemoteEvent

local KNOCKBACK_MAX_DURATION = 0.15
local KNOCKBACK_MIN_DURATION = 0.05

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
	if typeof(knockbackVelocity) ~= "Vector3" then
		return
	end

	local root = getCharacterRoot()
	if not root or root.Anchored then
		return
	end

	local planarVelocity = Vector3.new(knockbackVelocity.X, 0, knockbackVelocity.Z)
	if planarVelocity.Magnitude <= 0 then
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

	local durationSeconds = KNOCKBACK_MAX_DURATION
	if typeof(duration) == "number" then
		durationSeconds = math.clamp(duration, KNOCKBACK_MIN_DURATION, KNOCKBACK_MAX_DURATION)
	end

	Debris:AddItem(linearVelocity, durationSeconds)
end)
