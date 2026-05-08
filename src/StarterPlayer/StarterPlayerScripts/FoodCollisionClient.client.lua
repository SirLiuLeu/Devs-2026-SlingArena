--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameStates = require(Shared:WaitForChild("Constants"):WaitForChild("GameStates"))
local PhysicsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PhysicsConfig"))
local stateUpdateRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("StateUpdate") :: RemoteEvent
local reportFoodRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("ReportFoodHit") :: RemoteEvent
local reportCollisionRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("ReportCollision") :: RemoteEvent
local gameplayFeedbackRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("GameplayFeedback") :: RemoteEvent

local GRID_CELL_SIZE = 48
local Y_TOLERANCE = PhysicsConfig.Collision.YTolerance
local HIT_EPSILON = PhysicsConfig.Collision.Range
local REPORT_COOLDOWN = PhysicsConfig.Collision.ReportCooldown
local MIN_REPORT_SPEED = PhysicsConfig.Collision.MinReportSpeed
local IMPACT_ABSORPTION = 0.6
local HITSTOP_SECONDS = 0.05
local BOUNCE_RETENTION = 0.7

local lastHit: { [string]: number } = {}
local currentMovementState = GameStates.PlayerState.Idle

local function isLaunching(): boolean
	return currentMovementState == GameStates.PlayerState.Launching
end

local function gridKey(pos: Vector3): string
	return string.format("%d:%d", math.floor(pos.X / GRID_CELL_SIZE), math.floor(pos.Z / GRID_CELL_SIZE))
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Hitbox") :: BasePart?
end

local function getFoodModelFromPart(part: Instance): Model?
	local cursor: Instance? = part
	while cursor do
		if cursor:IsA("Model") and typeof(cursor:GetAttribute("FoodId")) == "string" then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end

local function getPlayerFromHit(part: Instance): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model or player.Character == model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

local function getTrapPartFromHit(part: Instance): BasePart?
	if part:IsA("BasePart") and part:FindFirstAncestor("Traps") then
		return part
	end
	return nil
end

local function applyPredictedLaunchFeel(root: BasePart, normal: Vector3)
	local velocity = root.AssemblyLinearVelocity
	local compressed = velocity * IMPACT_ABSORPTION
	root.AssemblyLinearVelocity = compressed
	task.delay(HITSTOP_SECONDS, function()
		if not root.Parent then
			return
		end
		local reflected = compressed - (2 * compressed:Dot(normal) * normal)
		root.AssemblyLinearVelocity = reflected * BOUNCE_RETENTION
	end)
end

local function getNearbyFood(position: Vector3): { Model }
	local out = {}
	local foodContainers = workspace:FindFirstChild("Maps")
	if not foodContainers then
		return out
	end
	local keys = {}
	local cx = math.floor(position.X / GRID_CELL_SIZE)
	local cz = math.floor(position.Z / GRID_CELL_SIZE)
	for x = cx - 1, cx + 1 do
		for z = cz - 1, cz + 1 do
			keys[string.format("%d:%d", x, z)] = true
		end
	end
	for _, map in ipairs(foodContainers:GetChildren()) do
		local container = map:FindFirstChild("FoodContainer")
		if container and container:IsA("Folder") then
			for _, food in ipairs(container:GetChildren()) do
				if food:IsA("Model") then
					local hitbox = food:FindFirstChild("Hitbox")
					if hitbox and hitbox:IsA("BasePart") and keys[gridKey(hitbox.Position)] then
						table.insert(out, food)
					end
				end
			end
		end
	end
	return out
end

local function canReportFood(rarity: any): boolean
	if rarity == "Common" then
		return currentMovementState ~= GameStates.PlayerState.Dead
	end
	return isLaunching()
end

local function markFoodPredicted(food: Model, rarity: any)
	if rarity ~= "Common" then
		return
	end
	for _, obj in ipairs(food:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Transparency = 1
		elseif obj:IsA("Decal") then
			obj.Transparency = 1
		end
	end
end

local function reportFoodHit(food: Model, hitbox: BasePart, root: BasePart, hitType: string)
	local foodId = food:GetAttribute("FoodId")
	local rarity = food:GetAttribute("FoodRarity")
	if typeof(foodId) ~= "string" or not canReportFood(rarity) then
		return
	end
	local now = os.clock()
	local cooldownKey = `Food:{foodId}`
	if (lastHit[cooldownKey] or 0) > now or root.AssemblyLinearVelocity.Magnitude < MIN_REPORT_SPEED then
		return
	end
	lastHit[cooldownKey] = now + REPORT_COOLDOWN
	markFoodPredicted(food, rarity)
	local normal = (root.Position - hitbox.Position).Magnitude > 0.001 and (root.Position - hitbox.Position).Unit or Vector3.new(0, 0, -1)
	applyPredictedLaunchFeel(root, normal)
	reportFoodRemote:FireServer({
		foodId = foodId,
		hitType = hitType,
		currPos = root.Position,
	})
end

local function detectCommonFoodByDistance(root: BasePart)
	local currPos = root.Position
	for _, food in ipairs(getNearbyFood(currPos)) do
		local hitbox = food:FindFirstChild("Hitbox")
		local rarity = food:GetAttribute("FoodRarity")
		if rarity == "Common" and hitbox and hitbox:IsA("BasePart") then
			local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
			local foodRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + HIT_EPSILON
			local rEffective = playerRadius + foodRadius + (root.AssemblyLinearVelocity.Magnitude * (player:GetNetworkPing() * 0.5)) + HIT_EPSILON
			local dXZ = (Vector3.new(currPos.X, 0, currPos.Z) - Vector3.new(hitbox.Position.X, 0, hitbox.Position.Z)).Magnitude
			if dXZ <= rEffective and math.abs(currPos.Y - hitbox.Position.Y) <= Y_TOLERANCE then
				reportFoodHit(food, hitbox, root, "ClientDistanceFoodOverlap")
			end
		end
	end
end

local function reportPlayerHit(targetPlayer: Player, root: BasePart)
	local now = os.clock()
	local cooldownKey = `Player:{targetPlayer.UserId}`
	if (lastHit[cooldownKey] or 0) > now then
		return
	end
	lastHit[cooldownKey] = now + REPORT_COOLDOWN
	reportCollisionRemote:FireServer({
		targetType = "Player",
		targetUserId = targetPlayer.UserId,
		currPos = root.Position,
		velocity = root.AssemblyLinearVelocity,
	})
end

local function reportTrapHit(trap: BasePart, root: BasePart)
	local now = os.clock()
	local cooldownKey = `Trap:{trap:GetDebugId(0)}`
	if (lastHit[cooldownKey] or 0) > now then
		return
	end
	lastHit[cooldownKey] = now + REPORT_COOLDOWN
	reportCollisionRemote:FireServer({
		targetType = "Trap",
		targetPosition = trap.Position,
		currPos = root.Position,
		velocity = root.AssemblyLinearVelocity,
	})
end

local function sphereCastLaunching(root: BasePart, dt: number)
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local speed = velocity.Magnitude
	if speed < MIN_REPORT_SPEED then
		return
	end
	local direction = velocity.Unit
	local castDistance = math.max(speed * dt, 0.1) + PhysicsConfig.Collision.SphereCastDistancePadding
	local radius = (math.max(root.Size.X, root.Size.Z) * 0.5) + PhysicsConfig.Collision.SphereCastRadiusPadding
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true
	local result = workspace:Spherecast(root.Position, radius, direction * castDistance, params)
	if not result then
		return
	end
	local part = result.Instance
	local food = getFoodModelFromPart(part)
	if food then
		local hitbox = food:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") then
			reportFoodHit(food, hitbox, root, "ClientLaunchSphereCast")
		end
		return
	end
	local targetPlayer = getPlayerFromHit(part)
	if targetPlayer then
		reportPlayerHit(targetPlayer, root)
		return
	end
	local trap = getTrapPartFromHit(part)
	if trap then
		reportTrapHit(trap, root)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local root = getRoot()
	if not root then
		return
	end
	if isLaunching() then
		sphereCastLaunching(root, dt)
	else
		detectCommonFoodByDistance(root)
	end
end)

stateUpdateRemote.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end
	local movementState = state.MovementState
	if typeof(movementState) == "string" then
		if movementState == "Move" then
			currentMovementState = GameStates.PlayerState.Moving
		else
			currentMovementState = movementState
		end
	end
end)

gameplayFeedbackRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or message.EventType ~= "FoodHitRejected" then
		return
	end
	-- Server rejection is authoritative, but no heavy client correction is attempted.
end)
