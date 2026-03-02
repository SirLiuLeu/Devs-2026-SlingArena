--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new(context)
	local self = setmetatable({}, PlayerService)
	self._context = context
	self._deathConnections = {}
	self._pawnsFolder = Workspace:FindFirstChild("SlingPawns")
	self._slingTemplate = nil
	if not self._pawnsFolder then
		self._pawnsFolder = Instance.new("Folder")
		self._pawnsFolder.Name = "SlingPawns"
		self._pawnsFolder.Parent = Workspace
	end
	return self
end

function PlayerService:Init()
	Players.CharacterAutoLoads = false
	self:_loadSlingTemplate()

	Players.PlayerAdded:Connect(function(player)
		self:SpawnPawn(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
	end)

	for _, player in Players:GetPlayers() do
		self:SpawnPawn(player)
	end
end

function PlayerService:_loadSlingTemplate(): Model
	if self._slingTemplate then
		return self._slingTemplate
	end

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local cubeSling = assets:WaitForChild("CubeSling")
	assert(cubeSling:IsA("Model"), "ReplicatedStorage.Assets.CubeSling must be a Model")

	local template = cubeSling:Clone()
	template.Name = "CubeSlingTemplate"
	template.Parent = nil

	if Config.SlingScale ~= 1 then
		template:ScaleTo(Config.SlingScale)
	end

	local root = template:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "CubeSling must contain HumanoidRootPart")
	template.PrimaryPart = root

	local attachment = root:FindFirstChild("Attachment")
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	local alignOrientation = root:FindFirstChild("AlignOrientation")
	local body = template:FindFirstChild("Body")
	local bodyWeld = template:FindFirstChild("BodyWeld")

	if attachment and attachment:IsA("Attachment") then
		if linearVelocity and linearVelocity:IsA("LinearVelocity") then
			linearVelocity.Attachment0 = attachment
			linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			linearVelocity.Enabled = false
		end
		if alignOrientation and alignOrientation:IsA("AlignOrientation") then
			alignOrientation.Attachment0 = attachment
			alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
			alignOrientation.RigidityEnabled = true
		end
	end

	if body and body:IsA("BasePart") then
		body.CustomPhysicalProperties = PhysicalProperties.new(Config.Mass, 0.4, 0.5, 1, 1)
	end
	if bodyWeld and bodyWeld:IsA("WeldConstraint") and body and body:IsA("BasePart") then
		bodyWeld.Part0 = root
		bodyWeld.Part1 = body
	end

	self._slingTemplate = template
	return template
end

function PlayerService:GetPawn(player)
	return self._pawnsFolder:FindFirstChild(player.Name)
end

function PlayerService:IsAlive(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	return state ~= nil and state.IsAlive
end

function PlayerService:_disconnectDeathSignal(player)
	local connection = self._deathConnections[player]
	if connection then
		connection:Disconnect()
		self._deathConnections[player] = nil
	end
end

function PlayerService:SpawnPawn(player, spawnIndex: number?)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)

	local template = self:_loadSlingTemplate()
	local pawn = template:Clone()
	pawn.Name = player.Name
	local index = spawnIndex or (player.UserId % 8) + 1
	local spawnPosition = self._context.Services.MapService:GetSpawnPoint(index)
	pawn:PivotTo(CFrame.new(spawnPosition, spawnPosition + Vector3.new(0, 0, -1)))
	pawn.Parent = self._pawnsFolder
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			descendant:SetNetworkOwner(player)
		elseif descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end

	player.Character = pawn
	self._context.Services.PlayerStateService:ResetForRespawn(player)

	return pawn
end

function PlayerService:DespawnPawn(player)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	self._context.Services.PlayerStateService:SetAlive(player, false)
end

function PlayerService:_destroyPawn(player)
	local pawn = self:GetPawn(player)
	if pawn then
		pawn:Destroy()
	end
end

function PlayerService:IsGrounded(player): boolean
	local root = self:GetRoot(player)
	if not root then
		return false
	end
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -4, 0))
	return result ~= nil
end

function PlayerService:GetRoot(player)
	local pawn = self:GetPawn(player)
	local root = pawn and pawn:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

return PlayerService
