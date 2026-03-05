--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

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
		self:SpawnPawn(player, 1, "LobbyMap")
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
	end)

	for _, player in Players:GetPlayers() do
		self:SpawnPawn(player, 1, "LobbyMap")
	end

	local debugResetRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.DebugResetSling)
	if debugResetRemote and debugResetRemote:IsA("RemoteEvent") then
		debugResetRemote.OnServerEvent:Connect(function(player)
			self:SpawnPawn(player, nil, self._context.Services.MapService:GetActiveMap() or "LobbyMap")
		end)
	end
end

function PlayerService:_loadSlingTemplate(): Model
	if self._slingTemplate then
		return self._slingTemplate
	end

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local slingModel = assets:WaitForChild("SlingModel")
	assert(slingModel:IsA("Model"), "ReplicatedStorage.Assets.SlingModel must be a Model")

	local template = slingModel:Clone()
	template.Name = "SlingModelTemplate"
	template.Parent = nil

	if Config.SlingScale ~= 1 then
		template:ScaleTo(Config.SlingScale)
	end

	local root = template.PrimaryPart
	if not root then
		root = template:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	assert(root and root:IsA("BasePart"), "SlingModel must contain a valid PrimaryPart")
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

function PlayerService:SpawnPawn(player, spawnIndex: number?, mapName: string?)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)

	local template = self:_loadSlingTemplate()
	local pawn = template:Clone()
	pawn.Name = player.Name
	local index = spawnIndex or (player.UserId % 8) + 1
	local spawnPosition = self._context.Services.MapService:GetSpawnPoint(index, mapName)
	pawn:PivotTo(CFrame.new(spawnPosition, spawnPosition + Vector3.new(0, 0, -1)))
	pawn.Parent = self._pawnsFolder
	pawn:SetAttribute("ScaleValue", Config.SlingScale)
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			descendant:SetNetworkOwner(nil)
		elseif descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end

	player.Character = pawn
	local humanoid = pawn:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
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
	if not pawn then
		return nil
	end
	local root = pawn.PrimaryPart or pawn:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function PlayerService:GrowPawn(player: Player, growthDelta: number)
	local pawn = self:GetPawn(player)
	if not pawn then
		return
	end
	local currentScale = pawn:GetAttribute("ScaleValue")
	if typeof(currentScale) ~= "number" then
		currentScale = pawn:GetScale()
	end
	local newScale = math.max(0.5, currentScale + math.max(0, growthDelta))
	pawn:SetAttribute("ScaleValue", newScale)
	pawn:ScaleTo(newScale)
end

function PlayerService:TeleportCharacterToSpawn(player: Player, spawn: BasePart?): boolean
	if not spawn then
		return false
	end
	local character = player.Character
	if not character or not character:IsA("Model") then
		character = self:GetPawn(player)
	end
	if not character or not character:IsA("Model") then
		return false
	end
	character:PivotTo(spawn.CFrame)
	return true
end

return PlayerService
