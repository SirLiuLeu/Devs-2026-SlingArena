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
local clientDoLaunchRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("ClientDoLaunch") :: RemoteEvent
local knockbackReplicationRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("KnockbackReplication") :: RemoteEvent

local GRID_CELL_SIZE = 48
local Y_TOLERANCE = PhysicsConfig.Collision.YTolerance
local HIT_EPSILON = PhysicsConfig.Collision.Range
-- FIX 1 ROOT CAUSE: REPORT_COOLDOWN was 0.05s (~3 frames at 60fps), causing the same food
-- to be reported multiple times per collision as the sphere cast re-detects each frame.
-- Raised to 0.4s so one physical approach produces at most one report per food.
local REPORT_COOLDOWN = 0.4
local MIN_REPORT_SPEED = PhysicsConfig.Collision.MinReportSpeed
local IMPACT_ABSORPTION = 0.6
local HITSTOP_SECONDS = 0.05
local BOUNCE_RETENTION = 0.7
local LAUNCH_SCAN_GRACE_SECONDS = PhysicsConfig.Launch.ValidationGraceSeconds
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
local launchSessionId = 0
local launchPlayerHitDebounce: { [number]: boolean } = {}

local function isLaunching(): boolean
	return currentMovementState == GameStates.PlayerState.Launching
end

local function isPredictedLaunchScanActive(): boolean
	return os.clock() <= predictedLaunchScanEndsAt
end

local function isLaunchHitScanActive(): boolean
	return isLaunching()
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
	return character and character:FindFirstChild("Hitbox", true) :: BasePart?
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

-- FIX 4 ROOT CAUSE: applyPredictedLaunchFeel was called unconditionally for all food rarities,
-- including Common. Common food must be pass-through (no bounce). The bounce logic is now
-- only called for non-common (HP) food from reportFoodHit, gated by the isCommon parameter.
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

-- FIX 1 + FIX 2 + FIX 4:
-- FIX 1: REPORT_COOLDOWN raised to 0.4s above prevents duplicate sends per food.
-- FIX 2: observedSpeed is now included in the server payload so the server can use
--         the client-measured speed when its own velocity read lags (network delay).
-- FIX 4: applyPredictedLaunchFeel is only called for non-common food (isCommon=false).
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

	-- FIX 4: Only apply bounce feel for non-common (HP) food. Common food is pass-through.
	local isCommon = (rarity == "Common")
	if not isCommon then
		local normal = (root.Position - hitbox.Position).Magnitude > 0.001
			and (root.Position - hitbox.Position).Unit
			or Vector3.new(0, 0, -1)
		applyPredictedLaunchFeel(root, normal)
	end

	-- FIX 2: Send observedSpeed in the payload so the server can use it when its
	-- own velocity read is stale due to client-authoritative physics replication lag.
	print(`Reporting food hit: foodId={foodId}, hitType={hitType}, observedSpeed={reportSpeed}`)
	reportFoodRemote:FireServer({
		foodId = foodId,
		hitType = hitType,
		currPos = root.Position,
		observedSpeed = reportSpeed,
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

local function reportPlayerHit(targetPlayer: Player, root: BasePart, observedSpeed: number?)
	if launchPlayerHitDebounce[targetPlayer.UserId] then
		return
	end
	launchPlayerHitDebounce[targetPlayer.UserId] = true
	local now = os.clock()
	local cooldownKey = `Player:{targetPlayer.UserId}`
	if (lastHit[cooldownKey] or 0) > now then
		return
	end
	lastHit[cooldownKey] = now + REPORT_COOLDOWN
	print(`Reporting player hit: targetUserId={targetPlayer.UserId}, observedSpeed={observedSpeed}`)
	reportCollisionRemote:FireServer({
		targetType = "Player",
		targetUserId = targetPlayer.UserId,
		currPos = root.Position,
		velocity = root.AssemblyLinearVelocity,
		observedSpeed = observedSpeed,
		launchSessionId = launchSessionId,
	})
end

local function applyLocalKnockback(knockbackVelocity: Vector3)
	local root = getRoot()
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "KnockbackAttachment"
	attachment.Parent = root
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "KnockbackLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = knockbackVelocity
	linearVelocity.MaxForce = math.huge
	linearVelocity.Parent = root
	task.delay(0.08, function()
		if linearVelocity.Parent then
			linearVelocity:Destroy()
		end
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
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


local function distancePointToSegmentXZ(point: Vector3, segA: Vector3, segB: Vector3): number
	local ax, az = segA.X, segA.Z
	local bx, bz = segB.X, segB.Z
	local px, pz = point.X, point.Z
	local abx, abz = bx - ax, bz - az
	local ab2 = (abx * abx) + (abz * abz)
	if ab2 <= 1e-6 then
		local dx, dz = px - ax, pz - az
		return math.sqrt((dx * dx) + (dz * dz))
	end
	local apx, apz = px - ax, pz - az
	local t = math.clamp(((apx * abx) + (apz * abz)) / ab2, 0, 1)
	local qx, qz = ax + (abx * t), az + (abz * t)
	local dx, dz = px - qx, pz - qz
	return math.sqrt((dx * dx) + (dz * dz))
end

local function findPlayerHitAlongSweep(castStart: Vector3, castEnd: Vector3, radius: number): Player?
	local closest: Player? = nil
	local closestDist = math.huge
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= player and target.Character then
			local hitbox = target.Character:FindFirstChild("Hitbox", true)
			if hitbox and hitbox:IsA("BasePart") then
				local targetRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
				local d = distancePointToSegmentXZ(hitbox.Position, castStart, castEnd)
				if d <= (radius + targetRadius + PhysicsConfig.Collision.ValidationTolerance) and d < closestDist then
					closest = target
					closestDist = d
				end
			end
		end
	end
	return closest
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

	local castEnd = castStart + direction * castDistance
	local sweptPlayer = findPlayerHitAlongSweep(castStart, castEnd, radius)
	if sweptPlayer then
		reportPlayerHit(sweptPlayer, root, observedSpeed)
		return
	end

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
		reportPlayerHit(targetPlayer, root, observedSpeed)
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

clientDoLaunchRemote.OnClientEvent:Connect(function(direction: any)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end
	predictedLaunchDirection = planarDirection.Unit
	predictedLaunchScanEndsAt = os.clock() + PREDICTED_LAUNCH_SCAN_SECONDS
	launchSessionId += 1
	launchPlayerHitDebounce = {}
end)

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
			predictedLaunchScanEndsAt = 0
			launchScanGraceEndsAt = 0
			launchPlayerHitDebounce = {}
		end
	end
end)

knockbackReplicationRemote.OnClientEvent:Connect(function(knockbackVelocity: any)
	if typeof(knockbackVelocity) ~= "Vector3" then
		return
	end
	applyLocalKnockback(knockbackVelocity)
end)

gameplayFeedbackRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or message.EventType ~= "FoodHitRejected" then
		return
	end
	-- Server rejection is authoritative, but no heavy client correction is attempted.
end)
