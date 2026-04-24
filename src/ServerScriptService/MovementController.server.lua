--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PhysicsConfig = require(script.Parent.Config.PhysicsConfig)

local MAX_INPUT_MAGNITUDE = 1

local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local moveRequestRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest) :: RemoteEvent
local slingPawns = Workspace:WaitForChild("SlingPawns")

local controllers: {[Player]: LinearVelocity} = {}

local function applyRootPhysicalProperties(root: BasePart)
	local physical = PhysicsConfig.PhysicalProperties
	local elasticity = if PhysicsConfig.Stability.ZeroElasticity then 0 else physical.Elasticity
	root.CustomPhysicalProperties = PhysicalProperties.new(
		physical.Density,
		physical.Friction,
		elasticity,
		physical.FrictionWeight,
		physical.ElasticityWeight
	)
end

local function getPawnRoot(player: Player): BasePart?
	local pawn = slingPawns:FindFirstChild(player.Name)
	if not pawn or not pawn:IsA("Model") then
		return nil
	end

	local root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox")
	if root and root:IsA("BasePart") then
		if pawn.PrimaryPart == nil then
			pawn.PrimaryPart = root
		end
		applyRootPhysicalProperties(root)
		return root
	end

	local firstPart = pawn:FindFirstChildWhichIsA("BasePart")
	if firstPart then
		pawn.PrimaryPart = firstPart
		applyRootPhysicalProperties(firstPart)
		return firstPart
	end

	return nil
end

local function createController(root: BasePart): LinearVelocity
	local attachment = root:FindFirstChild("MoveAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "MoveAttachment"
		attachment.Parent = root
	end

	local linearVelocity = root:FindFirstChild("MoveLinearVelocity")
	if not linearVelocity or not linearVelocity:IsA("LinearVelocity") then
		linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Name = "MoveLinearVelocity"
	end
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.ForceLimitsEnabled = true
	linearVelocity.MaxForce = if PhysicsConfig.Stability.UseInfiniteForce then math.huge else PhysicsConfig.Movement.MaxForce
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Enabled = false
	linearVelocity.Parent = root

	return linearVelocity
end

local function assignNetworkOwnership(root: BasePart, player: Player)
	if root.Anchored then
		return
	end

	local canSetOwnership = root:CanSetNetworkOwnership()
	if not canSetOwnership then
		return
	end

	pcall(function()
		root:SetNetworkOwner(player)
	end)
end

local function getOrCreateController(player: Player, root: BasePart): LinearVelocity
	local existing = controllers[player]
	if existing and existing.Parent == root then
		return existing
	end

	local controller = createController(root)
	controllers[player] = controller
	return controller
end

local function sanitizeDirection(directionInput: Vector3): Vector3
	local planar = Vector3.new(directionInput.X, 0, directionInput.Z)
	if planar.Magnitude < 0.001 then
		return Vector3.zero
	end
	if planar.Magnitude > MAX_INPUT_MAGNITUDE then
		return planar.Unit
	end
	return planar
end

moveRequestRemote.OnServerEvent:Connect(function(player: Player, directionInput: Vector3)
	if typeof(directionInput) ~= "Vector3" then
		return
	end

	if not RemoteContracts.Validate(RemoteContracts.Names.MoveRequest, directionInput) then
		return
	end

	local root = getPawnRoot(player)
	if not root then
		return
	end

	local movementController = getOrCreateController(player, root)
	assignNetworkOwnership(root, player)
	local direction = sanitizeDirection(directionInput)
	local targetVelocity = Vector3.new(direction.X, 0, direction.Z) * PhysicsConfig.Movement.MoveSpeed
	movementController.VectorVelocity = targetVelocity
	movementController.Enabled = targetVelocity.Magnitude > 0.001
end)

local function clearPlayer(player: Player)
	controllers[player] = nil
end

Players.PlayerRemoving:Connect(clearPlayer)
slingPawns.ChildRemoved:Connect(function(child)
	if not child:IsA("Model") then
		return
	end
	local player = Players:FindFirstChild(child.Name)
	if player then
		clearPlayer(player)
	end
end)
