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
	self._states = {}
	self._pawnsFolder = Workspace:FindFirstChild("SlingPawns")
	if not self._pawnsFolder then
		self._pawnsFolder = Instance.new("Folder")
		self._pawnsFolder.Name = "SlingPawns"
		self._pawnsFolder.Parent = Workspace
	end
	return self
end

function PlayerService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_destroyPawn(player)
		self._states[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self:_onPlayerAdded(player)
	end
end

function PlayerService:_onPlayerAdded(player)
	self._states[player] = {
		HP = Config.BasePlayerHP,
		Size = Config.BasePlayerSize,
		EXP = 0,
		Alive = true,
		LastAim = Vector3.new(0, 0, -1),
	}
	self:SpawnPawn(player)
end

function PlayerService:GetState(player)
	return self._states[player]
end

function PlayerService:GetPawn(player)
	return self._pawnsFolder:FindFirstChild(player.Name)
end

function PlayerService:IsAlive(player)
	local state = self:GetState(player)
	return state ~= nil and state.Alive
end

function PlayerService:SetAim(player, direction)
	local state = self:GetState(player)
	if state then
		state.LastAim = direction
	end
end

function PlayerService:SpawnPawn(player)
	self:_destroyPawn(player)
	local state = self:GetState(player)
	if not state then
		return
	end

	local pawn = Instance.new("Model")
	pawn.Name = player.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.new(4, 4, 4) * state.Size
	root.Position = Vector3.new(math.random(-25, 25), 6, math.random(-25, 25))
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CustomPhysicalProperties = PhysicalProperties.new(Config.Mass, 0.4, 0.5, 1, 1)
	root.CollisionGroup = "Players"
	root.Parent = pawn
	root:SetNetworkOwner(nil)

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

	pawn.PrimaryPart = root
	pawn.Parent = self._pawnsFolder

	player.Character = pawn
	state.Alive = true
	state.HP = Config.BasePlayerHP
end

function PlayerService:_destroyPawn(player)
	local pawn = self:GetPawn(player)
	if pawn then
		pawn:Destroy()
	end
end

function PlayerService:ApplyDamage(player, amount)
	local state = self:GetState(player)
	if not state or not state.Alive then
		return
	end
	state.HP = math.max(0, state.HP - amount)
	if state.HP <= 0 then
		state.Alive = false
		self:_destroyPawn(player)
		self._context.Services.RoundService:OnPlayerEliminated(player)
	end
end

function PlayerService:AddGrowth(player, amount, exp)
	local state = self:GetState(player)
	if not state then
		return
	end
	state.Size += amount
	state.EXP += exp

	local pawn = self:GetPawn(player)
	local root = pawn and pawn:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		root.Size = Vector3.new(4, 4, 4) * state.Size
	end
end

function PlayerService:GetRoot(player)
	local pawn = self:GetPawn(player)
	local root = pawn and pawn:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

return PlayerService
