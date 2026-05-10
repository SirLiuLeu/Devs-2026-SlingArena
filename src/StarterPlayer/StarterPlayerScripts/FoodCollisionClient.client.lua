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
local LAUNCH_SCAN_GRACE_SECONDS = 0.25
local PREDICTED_LAUNCH_SCAN_SECONDS = 0.35
local EXISTING_VELOCITY_SCAN_SECONDS = 0.1

local lastHit: { [string]: number } = {}
local currentMovementState = GameStates.PlayerState.Idle
local launchScanGraceEndsAt = 0
local predictedLaunchScanEndsAt = 0
local predictedLaunchDirection: Vector3? = nil
local lastRootPosition: Vector3? = nil
local sweepDebugStart: Part? = nil
local sweepDebugEnd: Part? = nil

local function isLaunching(): boolean
	return currentMovementState == GameStates.PlayerState.Launching
end

local function isPredictedLaunchScanActive(): boolean
	return os.clock() <= predictedLaunchScanEndsAt
end

local function isLaunchHitScanActive(): boolean
	return isLaunching() or isPredictedLaunchScanActive() or os.clock() <= launchScanGraceEndsAt
end

local function refreshExistingLaunchVelocity(root: BasePart)
	if isLaunchHitScanActive() or currentMovementState ~= GameStates.PlayerState.Charging then
		return
	end
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	if velocity.Magnitude < MIN_REPORT_SPEED then
		return
	end
	predictedLaunchDirection = velocity.Unit
	predictedLaunchScanEndsAt = os.clock() + EXISTING_VELOCITY_SCAN_SECONDS
end

local function ensureSweepDebugBall(name: string, color: Color3): Part
	local debugBall = Instance.new("Part")
	debugBall.Name = name
	debugBall.Shape = Enum.PartType.Ball
	debugBall.Anchored = true
	debugBall.CanCollide = false
	debugBall.CanTouch = false
	debugBall.CanQuery = false
	debugBall.CastShadow = false
	debugBall.Material = Enum.Material.Neon
	debugBall.Color = color
	debugBall.Transparency = 1
	debugBall.Parent = workspace
	return debugBall
end

local function setSweepDebugVisible(visible: boolean, startPosition: Vector3?, endPosition: Vector3?, radius: number?)
	if not visible and not sweepDebugStart and not sweepDebugEnd then
		return
	end
	if not sweepDebugStart then
		sweepDebugStart = ensureSweepDebugBall("ClientSphereCastDebug_Start", Color3.fromRGB(80, 220, 255))
	end
	if not sweepDebugEnd then
		sweepDebugEnd = ensureSweepDebugBall("ClientSphereCastDebug_End", Color3.fromRGB(255, 180, 60))
	end
	local startBall = sweepDebugStart :: Part
	local endBall = sweepDebugEnd :: Part

	local transparency = visible and 0.25 or 1
	startBall.Transparency = transparency
	endBall.Transparency = transparency

	if visible and startPosition and endPosition and radius then
		local diameter = math.max(radius * 2, 0.1)
		startBall.Size = Vector3.new(diameter, diameter, diameter)
		endBall.Size = Vector3.new(diameter, diameter, diameter)
		startBall.Position = startPosition
		endBall.Position = endPosition
	end
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
	return isLaunchHitScanActive()
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

local function reportFoodHit(food: Model, hitbox: BasePart, root: BasePart, hitType: string, observedSpeed: number?)
	local foodId = food:GetAttribute("FoodId")
	local rarity = food:GetAttribute("FoodRarity")
	if typeof(foodId) ~= "string" or not canReportFood(rarity) then
		return
	end
	local now = os.clock()
	local cooldownKey = `Food:{foodId}`
	local reportSpeed = math.max(root.AssemblyLinearVelocity.Magnitude, observedSpeed or 0)
	if (lastHit[cooldownKey] or 0) > now or reportSpeed < MIN_REPORT_SPEED then
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

local function sphereCastLaunching(root: BasePart, dt: number, previousPosition: Vector3?)
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local predictedDirection = predictedLaunchDirection
	local speed = velocity.Magnitude
	local castStart = previousPosition or root.Position
	local motion = root.Position - castStart
	local planarMotion = Vector3.new(motion.X, 0, motion.Z)
	local castVector = planarMotion

	if predictedDirection and isPredictedLaunchScanActive() and predictedDirection.Magnitude >= 0.001 then
		local predictedUnit = Vector3.new(predictedDirection.X, 0, predictedDirection.Z).Unit
		local travelDistance = math.max(planarMotion.Magnitude, speed * dt, 0.1)
		if castVector.Magnitude < 0.001 or castVector:Dot(predictedUnit) < 0 then
			castVector = predictedUnit * travelDistance
		end
	elseif castVector.Magnitude < 0.001 and speed >= MIN_REPORT_SPEED then
		castVector = velocity.Unit * math.max(speed * dt, 0.1)
	end

	local observedSpeed = math.max(speed, castVector.Magnitude / math.max(dt, 1 / 240))
	if castVector.Magnitude < 0.001 or observedSpeed < MIN_REPORT_SPEED then
		setSweepDebugVisible(false, nil, nil, nil)
		return
	end

	local direction = castVector.Unit
	local castDistance = castVector.Magnitude + PhysicsConfig.Collision.SphereCastDistancePadding
	local radius = (math.max(root.Size.X, root.Size.Z) * 0.5) + PhysicsConfig.Collision.SphereCastRadiusPadding
	setSweepDebugVisible(true, castStart, castStart + direction * castDistance, radius)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true
	local result = workspace:Spherecast(castStart, radius, direction * castDistance, params)
	if not result then
		return
	end
	local part = result.Instance
	local food = getFoodModelFromPart(part)
	if food then
		local hitbox = food:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") then
			reportFoodHit(food, hitbox, root, "ClientLaunchSphereCast", observedSpeed)
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
		lastRootPosition = nil
		setSweepDebugVisible(false, nil, nil, nil)
		return
	end
	local previousPosition = lastRootPosition
	refreshExistingLaunchVelocity(root)
	if isLaunchHitScanActive() then
		sphereCastLaunching(root, dt, previousPosition)
	else
		setSweepDebugVisible(false, nil, nil, nil)
		detectCommonFoodByDistance(root)
	end
	lastRootPosition = root.Position
end)

local function refreshPredictedLaunchFromAttributes()
	local launchedAt = player:GetAttribute("PredictedLaunchStartedAt")
	local direction = player:GetAttribute("PredictedLaunchDirection")
	if typeof(launchedAt) ~= "number" or typeof(direction) ~= "Vector3" then
		return
	end
	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end
	predictedLaunchDirection = planarDirection.Unit
	predictedLaunchScanEndsAt = math.max(predictedLaunchScanEndsAt, launchedAt + PREDICTED_LAUNCH_SCAN_SECONDS)
end

player:GetAttributeChangedSignal("PredictedLaunchStartedAt"):Connect(refreshPredictedLaunchFromAttributes)
player:GetAttributeChangedSignal("PredictedLaunchDirection"):Connect(refreshPredictedLaunchFromAttributes)

stateUpdateRemote.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end
	local movementState = state.MovementState
	if typeof(movementState) == "string" then
		local wasLaunching = isLaunching()
		if movementState == "Move" then
			currentMovementState = GameStates.PlayerState.Moving
		else
			currentMovementState = movementState
		end
		if currentMovementState == GameStates.PlayerState.Launching then
			predictedLaunchScanEndsAt = 0
		elseif wasLaunching then
			launchScanGraceEndsAt = os.clock() + LAUNCH_SCAN_GRACE_SECONDS
		end
	end
end)

gameplayFeedbackRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or message.EventType ~= "FoodHitRejected" then
		return
	end
	-- Server rejection is authoritative, but no heavy client correction is attempted.
end)
