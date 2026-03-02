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
	self._lastAim = {}
	self._pawnsFolder = Workspace:FindFirstChild("SlingPawns")
	if not self._pawnsFolder then
		self._pawnsFolder = Instance.new("Folder")
		self._pawnsFolder.Name = "SlingPawns"
		self._pawnsFolder.Parent = Workspace
	end
	return self
end

function PlayerService:Init()
	Players.CharacterAutoLoads = false
	self:_ensureSlingTemplate()

	Players.PlayerAdded:Connect(function(player)
		self._lastAim[player] = Vector3.new(0, 0, -1)
		self:SpawnPawn(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
		self._lastAim[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self._lastAim[player] = Vector3.new(0, 0, -1)
		self:SpawnPawn(player)
	end
end

function PlayerService:_ensureSlingTemplate(): Model
	local existing = ReplicatedStorage:FindFirstChild("Sling")
	if existing and existing:IsA("Model") then
		return existing
	end
	local sling = Instance.new("Model")
	sling.Name = "Sling"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 0.95
	root.CanCollide = true
	root.CanQuery = false
	root.CollisionGroup = "Players"
	root.Anchored = false
	root.Parent = sling

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Block
	body.Size = Vector3.new(4, 4, 4)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CollisionGroup = "Players"
	body.Anchored = false
	body.CanCollide = true
	body.CustomPhysicalProperties = PhysicalProperties.new(Config.Mass, 0.4, 0.5, 1, 1)
	body.Parent = sling

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BodyWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Parent = sling

	local attachment = Instance.new("Attachment")
	attachment.Name = "Attachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "LinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.MaxForce = math.huge
	linearVelocity.Enabled = false
	linearVelocity.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "AlignOrientation"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.Enabled = true
	align.Parent = root

	sling.PrimaryPart = root
	sling.Parent = ReplicatedStorage
	return sling
end

function PlayerService:GetPawn(player)
	return self._pawnsFolder:FindFirstChild(player.Name)
end

function PlayerService:IsAlive(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	return state ~= nil and state.IsAlive
end

function PlayerService:SetAim(player, direction)
	self._lastAim[player] = direction
end

function PlayerService:GetAim(player)
	return self._lastAim[player] or Vector3.new(0, 0, -1)
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

	local template = self:_ensureSlingTemplate()
	local pawn = template:Clone()
	pawn.Name = player.Name
	local index = spawnIndex or (player.UserId % 8) + 1
	local spawnPosition = self._context.Services.MapService:GetSpawnPoint(index)
	pawn:PivotTo(CFrame.new(spawnPosition))
	pawn.Parent = self._pawnsFolder
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant:SetNetworkOwner(player)
		end
	end

	player.Character = pawn
	self._context.Services.PlayerStateService:ResetForRespawn(player)

	local humanoid = pawn:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self._deathConnections[player] = humanoid.Died:Connect(function()
			if player.Parent == Players then
				self._context.Services.DamagePipelineService:HandlePlayerDeath(player)
			end
		end)
	end

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
