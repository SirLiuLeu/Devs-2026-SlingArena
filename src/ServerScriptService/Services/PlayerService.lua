--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local SPAWN_POSITION = Vector3.new(0, 10, 0)

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new(context)
	local self = setmetatable({}, PlayerService)
	self._context = context
	self._states = {}
	self._deathConnections = {}
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
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
		self._states[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self:_onPlayerAdded(player)
	end
end

function PlayerService:_ensureSlingTemplate(): Model
	local existing = ReplicatedStorage:FindFirstChild("Sling")
	if existing and existing:IsA("Model") then
		if self:_validateSlingTemplate(existing) then
			return existing
		end
		existing:Destroy()
	end

	local sling = Instance.new("Model")
	sling.Name = "Sling"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CollisionGroup = "Players"
	root.Parent = sling

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Block
	body.Size = Vector3.new(4, 4, 4)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CollisionGroup = "Players"
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

function PlayerService:_validateSlingTemplate(template: Model): boolean
	local root = template:FindFirstChild("HumanoidRootPart")
	local body = template:FindFirstChild("Body")
	local humanoid = template:FindFirstChildOfClass("Humanoid")

	if not (root and root:IsA("BasePart")) then
		return false
	end
	if not (body and body:IsA("Part")) then
		return false
	end
	if not humanoid then
		return false
	end

	template.PrimaryPart = root

	local weld = root:FindFirstChild("BodyWeld")
	if not (weld and weld:IsA("WeldConstraint")) then
		local newWeld = Instance.new("WeldConstraint")
		newWeld.Name = "BodyWeld"
		newWeld.Part0 = root
		newWeld.Part1 = body
		newWeld.Parent = root
	elseif weld.Part0 ~= root or weld.Part1 ~= body then
		weld.Part0 = root
		weld.Part1 = body
	end

	if not root:FindFirstChild("Attachment") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "Attachment"
		attachment.Parent = root
	end

	local attachment = root:FindFirstChild("Attachment") :: Attachment
	if not root:FindFirstChild("LinearVelocity") then
		local linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Name = "LinearVelocity"
		linearVelocity.Attachment0 = attachment
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		linearVelocity.VectorVelocity = Vector3.zero
		linearVelocity.MaxForce = math.huge
		linearVelocity.Enabled = false
		linearVelocity.Parent = root
	end

	if not root:FindFirstChild("AlignOrientation") then
		local align = Instance.new("AlignOrientation")
		align.Name = "AlignOrientation"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Enabled = true
		align.Parent = root
	end

	return true
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

function PlayerService:_disconnectDeathSignal(player)
	local connection = self._deathConnections[player]
	if connection then
		connection:Disconnect()
		self._deathConnections[player] = nil
	end
end

function PlayerService:SpawnPawn(player)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	local state = self:GetState(player)
	if not state then
		return
	end

	local template = self:_ensureSlingTemplate()
	local pawn = template:Clone()
	pawn.Name = player.Name
	pawn:PivotTo(CFrame.new(SPAWN_POSITION))
	pawn.Parent = self._pawnsFolder

	player.Character = pawn
	state.Alive = true
	state.HP = Config.BasePlayerHP

	local humanoid = pawn:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self._deathConnections[player] = humanoid.Died:Connect(function()
			if player.Parent ~= Players then
				return
			end
			if not state.Alive then
				return
			end
			state.Alive = false
			self._context.Services.RoundService:OnPlayerEliminated(player)
		end)
	end
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
		local pawn = self:GetPawn(player)
		local humanoid = pawn and pawn:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		else
			self:_destroyPawn(player)
			self._context.Services.RoundService:OnPlayerEliminated(player)
		end
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
	local body = pawn and pawn:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.Size = Vector3.new(4, 4, 4) * state.Size
	end
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
