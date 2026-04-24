--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local MOVE_SPEED = 36
local MOVE_FORCE = 5000
local MAX_INPUT_MAGNITUDE = 1
local ROTATION_SHARPNESS = 14

local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local moveRequestRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest) :: RemoteEvent
local slingPawns = Workspace:WaitForChild("SlingPawns")

local controllers: {[Player]: LinearVelocity} = {}
local facingDirections: {[Player]: Vector3} = {}

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
		return root
	end

	local firstPart = pawn:FindFirstChildWhichIsA("BasePart")
	if firstPart then
		pawn.PrimaryPart = firstPart
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
		linearVelocity.Attachment0 = attachment
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		linearVelocity.MaxForce = MOVE_FORCE
		linearVelocity.VectorVelocity = Vector3.zero
		linearVelocity.Parent = root
	end

	return linearVelocity
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

local function rotateRootTowards(root: BasePart, targetDirection: Vector3, dt: number)
	local planarDirection = Vector3.new(targetDirection.X, 0, targetDirection.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end

	local targetLook = planarDirection.Unit
	local targetCFrame = CFrame.lookAt(root.Position, root.Position + targetLook, Vector3.yAxis)
	local alpha = 1 - math.exp(-ROTATION_SHARPNESS * dt)
	root.CFrame = root.CFrame:Lerp(targetCFrame, alpha)
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
	local direction = sanitizeDirection(directionInput)
	movementController.VectorVelocity = direction * MOVE_SPEED

	if direction.Magnitude > 0.001 then
		facingDirections[player] = direction.Unit
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	for player, direction in pairs(facingDirections) do
		local root = getPawnRoot(player)
		if root then
			rotateRootTowards(root, direction, deltaTime)
		end
	end
end)

local function clearPlayer(player: Player)
	controllers[player] = nil
	facingDirections[player] = nil
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
