--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameStates = require(Shared:WaitForChild("Constants"):WaitForChild("GameStates"))
local PhysicsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PhysicsConfig"))
local PawnLocator = require(Shared:WaitForChild("Utils"):WaitForChild("PawnLocator"))
local PlayerModeState = require(Shared:WaitForChild("Utils"):WaitForChild("PlayerModeState"))
local CollisionClassifier = require(Shared:WaitForChild("Utils"):WaitForChild("CollisionClassifier"))
local SoundManager = require(Shared:WaitForChild("Utils"):WaitForChild("SoundManager"))
local stateUpdateRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("StateUpdate") :: RemoteEvent
local reportFoodRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ReportFoodHit") :: RemoteEvent
local reportCollisionRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ReportCollision") :: RemoteEvent
local gameplayFeedbackRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("GameplayFeedback") :: RemoteEvent
local clientDoLaunchRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ClientDoLaunch") :: RemoteEvent
local clockSyncRequestRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ClockSyncRequest") :: RemoteEvent
local clockSyncResponseRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ClockSyncResponse") :: RemoteEvent

local GRID_CELL_SIZE = 48
local Y_TOLERANCE = PhysicsConfig.Collision.YTolerance
local HIT_EPSILON = PhysicsConfig.Collision.Range
local REPORT_COOLDOWN = PhysicsConfig.Collision.ClientReportCooldown or PhysicsConfig.Collision.Cooldown
local MIN_REPORT_SPEED = PhysicsConfig.Collision.MinReportSpeed
local WALL_CONTACT_RELEASE_SECONDS = 0.05

local lastHit: { [string]: number } = {}
local wallContactActive = false
local lastWallContactSeenAt = 0
local currentMovementState = GameStates.PlayerState.Idle
local predictedLaunchScanEndsAt = 0
local predictedLaunchStartedAt = 0
local predictedLaunchDirection: Vector3? = nil
local activeLaunchId: string? = nil
local serverConfirmedLaunch = false
local lastRootPosition: Vector3? = nil
local serverClockOffset = 0
local clockSyncSamples: { number } = {}
local sweepDebugStart: Part? = nil
local sweepDebugEnd: Part? = nil
local FOOD_SCAN_DEBUG_INTERVAL_SECONDS = 1
local foodScanDebugLastAt: { [string]: number } = {}

local function debugFoodScan(key: string, message: string, intervalSeconds: number?)
  local now = os.clock()
  local interval = intervalSeconds or FOOD_SCAN_DEBUG_INTERVAL_SECONDS
  local lastAt = foodScanDebugLastAt[key]
  if lastAt and now - lastAt < interval then
    return
  end
  foodScanDebugLastAt[key] = now
  print(string.format(
    "[FoodScanDebug] player=%s state=%s launchId=%s %s",
    player.Name,
    tostring(currentMovementState),
    tostring(activeLaunchId),
    message
  ))
end

local function getSyncedServerTime(): number
	return os.clock() + serverClockOffset
end

local function requestClockSync()
	clockSyncRequestRemote:FireServer(os.clock())
end

clockSyncResponseRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or typeof(payload.ClientSendTime) ~= "number" or typeof(payload.ServerCurrentTime) ~= "number" then
		return
	end
	local clientReceiveTime = os.clock()
	local rtt = math.max(0, clientReceiveTime - payload.ClientSendTime)
	local estimatedServerAtReceive = payload.ServerCurrentTime + (rtt * 0.5)
	local sampleOffset = estimatedServerAtReceive - clientReceiveTime
	table.insert(clockSyncSamples, sampleOffset)
	local maxSamples = PhysicsConfig.LagCompensation.ClockSyncSamples
	while #clockSyncSamples > maxSamples do
		table.remove(clockSyncSamples, 1)
	end
	local total = 0
	for _, offset in clockSyncSamples do
		total += offset
	end
	serverClockOffset = total / math.max(1, #clockSyncSamples)
end)

task.spawn(function()
	while true do
		requestClockSync()
		task.wait(PhysicsConfig.LagCompensation.ClockSyncIntervalSeconds)
	end
end)

local function isLaunching(): boolean
	return currentMovementState == GameStates.PlayerState.Launching
end

local function isPredictedLaunchScanActive(): boolean
	return os.clock() <= predictedLaunchScanEndsAt
end

local function hasOptimisticRelease(): boolean
	return predictedLaunchStartedAt > 0 and isPredictedLaunchScanActive()
end

local function isLaunchHitScanActive(): boolean
	return isLaunching() and activeLaunchId ~= nil
end

local function rollbackPredictedLaunch()
	predictedLaunchScanEndsAt = 0
	predictedLaunchStartedAt = 0
	predictedLaunchDirection = nil
	serverConfirmedLaunch = false
	player:SetAttribute("PredictedLaunchDirection", nil)
	player:SetAttribute("PredictedLaunchStartedAt", nil)
end

local function startPredictedLaunchScan(direction: Vector3, startedAt: number)
	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end
	predictedLaunchDirection = planarDirection.Unit
	predictedLaunchStartedAt = startedAt
	predictedLaunchScanEndsAt = 0
	serverConfirmedLaunch = false
end

local function syncPredictedLaunchAttributes()
	local startedAt = player:GetAttribute("PredictedLaunchStartedAt")
	local direction = player:GetAttribute("PredictedLaunchDirection")
	if typeof(startedAt) ~= "number" or typeof(direction) ~= "Vector3" then
		return
	end
	if startedAt <= predictedLaunchStartedAt then
		return
	end
	startPredictedLaunchScan(direction, startedAt)
end

local function rollbackUnconfirmedPredictionIfExpired()
	if serverConfirmedLaunch or predictedLaunchStartedAt <= 0 then
		return
	end
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

local function isHumanMode(): boolean
	return not PlayerModeState.IsLauncherMode(player, nil)
end

local function getActiveCharacter(): Model?
	if isHumanMode() then
		return PawnLocator.GetHumanCharacterByPlayer(player)
	end
	return PawnLocator.GetLauncherPawnByPlayer(player) or PawnLocator.GetHumanCharacterByPlayer(player)
end

local function getRoot(): BasePart?
	return PawnLocator.GetRootPart(getActiveCharacter())
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
	if model then
		local characterPlayer = Players:GetPlayerFromCharacter(model)
		if characterPlayer and characterPlayer ~= player then
			return characterPlayer
		end
	end

	-- Launcher pawns live under Workspace.LauncherPawns and are not necessarily
	-- Player.Character; detect any part nested beneath another player's active pawn.
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= player then
			local launcherPawn = PawnLocator.GetLauncherPawnByPlayer(candidate)
			if launcherPawn and part:IsDescendantOf(launcherPawn) then
				return candidate
			end
			local character = candidate.Character
			if character and part:IsDescendantOf(character) then
				return candidate
			end
		end
	end
	return nil
end

local function isPlayerOrLauncherCollisionPart(part: Instance): boolean
	local launcherPawns = workspace:FindFirstChild("LauncherPawns")
	if launcherPawns and part:IsDescendantOf(launcherPawns) then return true end
	for _, candidate in ipairs(Players:GetPlayers()) do
		local pawn = PawnLocator.GetLauncherPawnByPlayer(candidate)
		if pawn and part:IsDescendantOf(pawn) then return true end
		local character = candidate.Character
		if character and part:IsDescendantOf(character) then return true end
	end
	return false
end

local function isTrapCollisionPart(part: Instance): boolean
	local mapsRoot = workspace:FindFirstChild("Maps")
	if not mapsRoot then return false end
	for _, mapModel in ipairs(mapsRoot:GetChildren()) do
		local traps = mapModel:FindFirstChild("Traps")
		if traps and part:IsDescendantOf(traps) then
			return true
		end
	end
	return false
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

local function debugCommonFoodCandidatesAlongSweep(castStart: Vector3, castEnd: Vector3, castRadius: number)
  local sweep = Vector3.new(castEnd.X - castStart.X, 0, castEnd.Z - castStart.Z)
  local sweepLengthSquared = sweep:Dot(sweep)

  for _, food in ipairs(getNearbyFood(castStart)) do
    local hitbox = food:FindFirstChild("Hitbox")
    if food:GetAttribute("FoodRarity") == "Common" and hitbox and hitbox:IsA("BasePart") then
      local offset = Vector3.new(hitbox.Position.X - castStart.X, 0, hitbox.Position.Z - castStart.Z)
      local alpha = if sweepLengthSquared > 0.000001 then math.clamp(offset:Dot(sweep) / sweepLengthSquared, 0, 1) else 0
      local closestX = castStart.X + sweep.X * alpha
      local closestZ = castStart.Z + sweep.Z * alpha
      local distanceXZ = (Vector3.new(hitbox.Position.X, 0, hitbox.Position.Z) - Vector3.new(closestX, 0, closestZ)).Magnitude
      local foodRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
      local verticalReach = castRadius + math.max(hitbox.Size.Y * 0.5, Y_TOLERANCE)

      if distanceXZ <= castRadius + foodRadius + HIT_EPSILON
        and math.abs(castStart.Y - hitbox.Position.Y) <= verticalReach then
        local collisionType, taggedInstance = CollisionClassifier.GetType(hitbox)
        local foodId = food:GetAttribute("FoodId")
        debugFoodScan(
          "sweep-candidate:" .. tostring(foodId or food.Name),
          string.format(
            "SweepCandidate food=%s foodId=%s rarity=%s modelHasCollision_Food=%s classifierType=%s taggedAncestor=%s hitbox=%s CanCollide=%s CanQuery=%s distanceXZ=%.2f combinedRadius=%.2f verticalDistance=%.2f queryRespectCanCollide=true",
            food:GetFullName(),
            tostring(foodId),
            tostring(food:GetAttribute("FoodRarity")),
            tostring(CollectionService:HasTag(food, "Collision_Food")),
            tostring(collisionType),
            taggedInstance and taggedInstance:GetFullName() or "nil",
            hitbox:GetFullName(),
            tostring(hitbox.CanCollide),
            tostring(hitbox.CanQuery),
            distanceXZ,
            castRadius + foodRadius + HIT_EPSILON,
            math.abs(castStart.Y - hitbox.Position.Y)
          ),
          1
        )
      end
    end
  end
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
  if typeof(foodId) ~= "string" then
    debugFoodScan(
      "report-missing-id:" .. food:GetFullName(),
      string.format("ReportFoodHitSuppressed reason=missing_FoodId food=%s rarity=%s hitType=%s", food:GetFullName(), tostring(rarity), hitType),
      0.5
    )
    return
  end
  if not canReportFood(rarity) then
    debugFoodScan(
      "report-not-eligible:" .. foodId,
      string.format("ReportFoodHitSuppressed reason=state_not_eligible foodId=%s rarity=%s hitType=%s", foodId, tostring(rarity), hitType),
      0.5
    )
    return
  end

  local now = os.clock()
  local cooldownKey = `Food:{foodId}`
  local reportSpeed = math.max(root.AssemblyLinearVelocity.Magnitude, observedSpeed or 0)
  local cooldownUntil = lastHit[cooldownKey] or 0
  if cooldownUntil > now then
    debugFoodScan(
      "report-cooldown:" .. foodId,
      string.format("ReportFoodHitSuppressed reason=client_cooldown foodId=%s hitType=%s remaining=%.3f speed=%.2f", foodId, hitType, cooldownUntil - now, reportSpeed),
      0.25
    )
    return
  end
  if reportSpeed < MIN_REPORT_SPEED then
    debugFoodScan(
      "report-low-speed:" .. foodId,
      string.format("ReportFoodHitSuppressed reason=below_min_speed foodId=%s hitType=%s speed=%.2f minimum=%.2f", foodId, hitType, reportSpeed, MIN_REPORT_SPEED),
      0.5
    )
    return
  end

  lastHit[cooldownKey] = now + REPORT_COOLDOWN
  markFoodPredicted(food, rarity)

  local normal = (root.Position - hitbox.Position).Magnitude > 0.001
    and (root.Position - hitbox.Position).Unit
    or Vector3.new(0, 0, -1)
  print(`[Report Food Hit] launchId={activeLaunchId} foodId={foodId} speed={reportSpeed} normal={normal} hitType={hitType}`)
  reportFoodRemote:FireServer({
    foodId = foodId,
    launchId = activeLaunchId,
    hitType = hitType,
    currPos = root.Position,
    velocity = root.AssemblyLinearVelocity,
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

local function getPlayerRoot(targetPlayer: Player): BasePart?
	return PawnLocator.GetRootPart(PawnLocator.GetLauncherPawnByPlayer(targetPlayer) or PawnLocator.GetHumanCharacterByPlayer(targetPlayer))
end

local function triggerPredictedPlayerHitFeedback(_targetPlayer: Player, _hitPosition: Vector3)
	-- Local-only prediction hook for immediate VFX/SFX. Authoritative defender hit reactions
	-- are played when KnockbackReplication arrives from the server.
end

local function sanitizeSurfaceNormal(surfaceNormal: Vector3?, attackerVelocity: Vector3): Vector3?
	if typeof(surfaceNormal) ~= "Vector3" then
		return nil
	end
	local planar = Vector3.new(surfaceNormal.X, 0, surfaceNormal.Z)
	if planar.Magnitude <= PhysicsConfig.Movement.InputDeadzone then
		return nil
	end
	local normal = planar.Unit
	local planarVelocity = Vector3.new(attackerVelocity.X, 0, attackerVelocity.Z)
	if planarVelocity.Magnitude > PhysicsConfig.Movement.InputDeadzone and planarVelocity:Dot(normal) < 0 then
		normal = -normal
	end
	return normal
end

local function approximatePartSurfacePosition(position: Vector3, part: BasePart): Vector3
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5
	local closestLocal = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	return part.CFrame:PointToWorldSpace(closestLocal)
end

local function reportPlayerHit(targetPlayer: Player, root: BasePart, observedSpeed: number?, surfaceNormal: Vector3?, sweepStart: Vector3, sweepEnd: Vector3, hitPosition: Vector3)
	if not activeLaunchId then
		return
	end
	local cooldownKey = `Player:{activeLaunchId}:{targetPlayer.UserId}`
	if lastHit[cooldownKey] then
		return
	end
	lastHit[cooldownKey] = math.huge
	local attackerVelocity = root.AssemblyLinearVelocity
	local sanitizedNormal = sanitizeSurfaceNormal(surfaceNormal, attackerVelocity)
	triggerPredictedPlayerHitFeedback(targetPlayer, hitPosition)
	print(`[Report Hit] launchId={activeLaunchId} targetUserId={targetPlayer.UserId} speed={observedSpeed or attackerVelocity.Magnitude} normal={sanitizedNormal} `)
	reportCollisionRemote:FireServer({
		targetUserId = targetPlayer.UserId,
		launchId = activeLaunchId,
		timestamp = getSyncedServerTime(),
		sweepStart = sweepStart,
		sweepEnd = sweepEnd,
		hitPosition = hitPosition,
		surfaceNormal = sanitizedNormal,
		velocity = attackerVelocity,
		observedSpeed = observedSpeed or attackerVelocity.Magnitude,
	})
end

local function reportWallHit(part: Instance, hitType: string, sweepStart: Vector3, hitPosition: Vector3): boolean
	if not activeLaunchId or not part:IsA("BasePart") or part.CanCollide ~= true then
		return false
	end

	local contactPosition = if hitType == "ClientLaunchSphereOverlap"
		then approximatePartSurfacePosition(sweepStart, part)
		else hitPosition
	local now = os.clock()
	if not wallContactActive then
		-- Wall audio is cosmetic: play immediately on the detecting client and never
		-- wait for a server report or server-side sweep validation.
		SoundManager.Play("SFX_Wall_Hit", contactPosition)
		wallContactActive = true
	end
	lastWallContactSeenAt = now
	return true
end


local function buildCollisionFilterParams(): (RaycastParams, OverlapParams)
	local activeCharacter = getActiveCharacter()
	local filterDescendants = if activeCharacter then { activeCharacter } else {}

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filterDescendants
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = filterDescendants
	overlapParams.RespectCanCollide = true

	return raycastParams, overlapParams
end

local function approximateOverlapNormal(castStart: Vector3, part: BasePart, fallbackDirection: Vector3): Vector3
	local offset = castStart - part.Position
	local planarOffset = Vector3.new(offset.X, 0, offset.Z)
	if planarOffset.Magnitude >= 0.001 then
		return planarOffset.Unit
	end
	return -fallbackDirection
end

local function processLaunchHit(part: Instance, root: BasePart, hitType: string, observedSpeed: number, surfaceNormal: Vector3?, sweepStart: Vector3, sweepEnd: Vector3, hitPosition: Vector3): boolean
  local food = getFoodModelFromPart(part)
  if food then
    local hitbox = food:FindFirstChild("Hitbox")
    local foodCollisionType, foodTaggedInstance = CollisionClassifier.GetType(part)
    debugFoodScan(
      "detected-food:" .. tostring(food:GetAttribute("FoodId") or food.Name),
      string.format(
        "LaunchHitDetected hitType=%s part=%s food=%s foodId=%s rarity=%s modelHasCollision_Food=%s classifierType=%s taggedAncestor=%s hitbox=%s hitboxCanCollide=%s hitboxCanQuery=%s observedSpeed=%.2f",
        hitType,
        part:GetFullName(),
        food:GetFullName(),
        tostring(food:GetAttribute("FoodId")),
        tostring(food:GetAttribute("FoodRarity")),
        tostring(CollectionService:HasTag(food, "Collision_Food")),
        tostring(foodCollisionType),
        foodTaggedInstance and foodTaggedInstance:GetFullName() or "nil",
        hitbox and hitbox:GetFullName() or "nil",
        hitbox and hitbox:IsA("BasePart") and tostring(hitbox.CanCollide) or "n/a",
        hitbox and hitbox:IsA("BasePart") and tostring(hitbox.CanQuery) or "n/a",
        observedSpeed
      ),
      0.25
    )
    if hitbox and hitbox:IsA("BasePart") then
      reportFoodHit(food, hitbox, root, hitType, observedSpeed)
    else
      debugFoodScan("missing-hitbox:" .. food:GetFullName(), "LaunchHitSuppressed reason=FoodModelHasNoBasePartHitbox model=" .. food:GetFullName(), 0.5)
    end
    -- Food is a special collision type, never a generic wall.
    return true
  end

  local targetPlayer = getPlayerFromHit(part)
  if targetPlayer then
    reportPlayerHit(targetPlayer, root, observedSpeed, surfaceNormal, sweepStart, sweepEnd, hitPosition)
    return true
  end

  -- Own-character parts and orphaned launcher-pawn parts are not world walls.
  if isPlayerOrLauncherCollisionPart(part) then
    return true
  end

  local collisionType, taggedInstance = CollisionClassifier.GetType(part)
  if collisionType == "Wall" then
    -- Only explicitly tagged Wall geometry may request the wall-hit SFX.
    return reportWallHit(part, hitType, sweepStart, hitPosition)
  elseif collisionType == "Ground" then
    -- Ground is expected to stay under a moving Launcher; ignore it and keep
    -- scanning other overlaps instead of treating every collidable part as Wall.
    return false
  elseif collisionType == "Food" then
    debugFoodScan(
      "tagged-food-without-id:" .. part:GetFullName(),
      string.format(
        "TaggedFoodHitWithoutFoodId hitType=%s part=%s taggedAncestor=%s CanCollide=%s CanQuery=%s getFoodModelFromPart=nil",
        hitType,
        part:GetFullName(),
        taggedInstance and taggedInstance:GetFullName() or "nil",
        part:IsA("BasePart") and tostring(part.CanCollide) or "n/a",
        part:IsA("BasePart") and tostring(part.CanQuery) or "n/a"
      ),
      0.5
    )
    return true
  elseif collisionType == "Lava" or collisionType == "Trap" then
    -- These have their own collision/gameplay categories and must never use wall SFX.
    return true
  end

  -- Preserve compatibility with legacy map traps that have not been tagged yet.
  if isTrapCollisionPart(part) then
    return true
  end

  -- Unknown collidable parts are not Walls by default.
  return false
end

local MAX_GROUND_CAST_SKIPS = 8

local MAX_GROUND_CAST_SKIPS = 8

local function sphereCastSkippingGround(castStart: Vector3, radius: number, castVector: Vector3, raycastParams: RaycastParams): RaycastResult?
  local excludedInstances = table.clone(raycastParams.FilterDescendantsInstances)
  local excludedSet: { [Instance]: boolean } = {}
  for _, instance in ipairs(excludedInstances) do
    excludedSet[instance] = true
  end

  for _ = 1, MAX_GROUND_CAST_SKIPS do
    raycastParams.FilterDescendantsInstances = excludedInstances
    local result = workspace:Spherecast(castStart, radius, castVector, raycastParams)
    if not result then
      return nil
    end

    local collisionType, taggedInstance = CollisionClassifier.GetType(result.Instance)
    if collisionType ~= "Ground" then
      return result
    end

    debugFoodScan(
      "spherecast-ground-skip",
      string.format(
        "SpherecastSkippedGround part=%s taggedAncestor=%s class=%s CanCollide=%s CanQuery=%s",
        result.Instance:GetFullName(),
        taggedInstance and taggedInstance:GetFullName() or "nil",
        taggedInstance and taggedInstance.ClassName or "nil",
        tostring(result.Instance.CanCollide),
        tostring(result.Instance.CanQuery)
      ),
      1
    )

    -- Keep current filtering behavior, but log which tagged object is excluded.
    local ignoreInstance = taggedInstance or result.Instance
    if not (ignoreInstance:IsA("Model") or ignoreInstance:IsA("BasePart")) then
      ignoreInstance = result.Instance
    end
    if excludedSet[ignoreInstance] then
      ignoreInstance = result.Instance
      if excludedSet[ignoreInstance] then
        return nil
      end
    end

    excludedSet[ignoreInstance] = true
    table.insert(excludedInstances, ignoreInstance)
  end

  debugFoodScan("spherecast-ground-skip-limit", "SpherecastStopped reason=max_ground_skips count=" .. tostring(MAX_GROUND_CAST_SKIPS), 1)
  return nil
end

local function sphereCastLaunching(root: BasePart, dt: number, previousPosition: Vector3?)
  local currentPos = root.Position
  local castStart = previousPosition or currentPos
  local velocity = root.AssemblyLinearVelocity
  local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
  local speed = planarVelocity.Magnitude
  local motion = currentPos - castStart
  local planarMotion = Vector3.new(motion.X, 0, motion.Z)
  local castVector: Vector3

  if planarMotion.Magnitude >= 0.001 then
    castVector = planarMotion
  else
    if speed >= MIN_REPORT_SPEED then
      castVector = planarVelocity.Unit * math.max(speed * dt, 0.1)
    else
      debugFoodScan(
        "launch-no-motion",
        string.format("SpherecastNotRun reason=no_planar_motion_and_low_speed speed=%.2f minSpeed=%.2f dt=%.4f", speed, MIN_REPORT_SPEED, dt),
        1
      )
      setSweepDebugVisible(false, nil, nil, nil)
      return
    end
  end

  local direction = castVector.Unit
  local baseDistance = castVector.Magnitude
  local observedSpeed = math.max(speed, baseDistance / math.max(dt, 1 / 240))

  if observedSpeed < MIN_REPORT_SPEED then
    debugFoodScan(
      "launch-low-speed",
      string.format("SpherecastNotRun reason=below_min_speed observedSpeed=%.2f minimum=%.2f planarMotion=%.2f", observedSpeed, MIN_REPORT_SPEED, planarMotion.Magnitude),
      1
    )
    setSweepDebugVisible(false, nil, nil, nil)
    return
  end

  local castDistance = baseDistance + PhysicsConfig.Collision.SphereCastDistancePadding
  local radius = (math.max(root.Size.X, root.Size.Z) * 0.5) + PhysicsConfig.Collision.SphereCastRadiusPadding
  setSweepDebugVisible(true, castStart, castStart + direction * castDistance, radius)

  local raycastParams, overlapParams = buildCollisionFilterParams()
  debugCommonFoodCandidatesAlongSweep(castStart, castStart + direction * castDistance, radius)

  -- Static overlap catches the case where castStart is already inside a target collider.
  local overlapParts = workspace:GetPartBoundsInRadius(castStart, radius, overlapParams)
  debugFoodScan(
    "overlap-summary",
    string.format("LaunchOverlapSummary count=%d radius=%.2f start=(%.1f, %.1f, %.1f) queryRespectCanCollide=true", #overlapParts, radius, castStart.X, castStart.Y, castStart.Z),
    1
  )
  for _, overlapPart in ipairs(overlapParts) do
    if processLaunchHit(overlapPart, root, "ClientLaunchSphereOverlap", observedSpeed, approximateOverlapNormal(castStart, overlapPart, direction), castStart, currentPos, overlapPart.Position) then
      return
    end
  end

  local result = sphereCastSkippingGround(castStart, radius, direction * castDistance, raycastParams)
  if result then
    local resultType, taggedInstance = CollisionClassifier.GetType(result.Instance)
    local food = getFoodModelFromPart(result.Instance)
    debugFoodScan(
      "spherecast-result",
      string.format(
        "SpherecastResult part=%s collisionType=%s taggedAncestor=%s foodModel=%s foodId=%s CanCollide=%s CanQuery=%s castDistance=%.2f radius=%.2f observedSpeed=%.2f",
        result.Instance:GetFullName(),
        tostring(resultType),
        taggedInstance and taggedInstance:GetFullName() or "nil",
        food and food:GetFullName() or "nil",
        food and tostring(food:GetAttribute("FoodId")) or "nil",
        tostring(result.Instance.CanCollide),
        tostring(result.Instance.CanQuery),
        castDistance,
        radius,
        observedSpeed
      ),
      0.5
    )
    processLaunchHit(result.Instance, root, "ClientLaunchSphereCast", observedSpeed, result.Normal, castStart, currentPos, result.Position)
  else
    debugFoodScan(
      "spherecast-miss",
      string.format(
        "SpherecastResult nil castStart=(%.1f, %.1f, %.1f) direction=(%.2f, %.2f, %.2f) castDistance=%.2f radius=%.2f observedSpeed=%.2f queryRespectCanCollide=true",
        castStart.X,
        castStart.Y,
        castStart.Z,
        direction.X,
        direction.Y,
        direction.Z,
        castDistance,
        radius,
        observedSpeed
      ),
      1
    )
  end
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if wallContactActive and now - lastWallContactSeenAt >= WALL_CONTACT_RELEASE_SECONDS then
		wallContactActive = false
	end

	local root = getRoot()
	if not root then
		wallContactActive = false
		lastRootPosition = nil
		setSweepDebugVisible(false, nil, nil, nil)
		return
	end

	if isHumanMode() then
		wallContactActive = false
		lastRootPosition = nil
		setSweepDebugVisible(false, nil, nil, nil)
		detectCommonFoodByDistance(root)
		return
	end

	local previousPosition = lastRootPosition
	syncPredictedLaunchAttributes()
	rollbackUnconfirmedPredictionIfExpired()
	if isLaunchHitScanActive() then
		sphereCastLaunching(root, dt, previousPosition)
	else
		if isLaunching() then
			debugFoodScan("launch-scan-inactive", "LaunchScanNotRun reason=LaunchingButMissingLaunchId; verify ClientDoLaunch event ordering")
		end
		wallContactActive = false
		setSweepDebugVisible(false, nil, nil, nil)
		detectCommonFoodByDistance(root)
	end
	lastRootPosition = root.Position
end)

clientDoLaunchRemote.OnClientEvent:Connect(function(direction: any, _initialSpeed: any, _serverMass: any, launchId: any)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end
	predictedLaunchDirection = planarDirection.Unit
	serverConfirmedLaunch = true
	predictedLaunchStartedAt = 0
	if typeof(launchId) == "string" then
		activeLaunchId = launchId
	end
	debugFoodScan(
		"client-do-launch",
		string.format("ClientDoLaunchReceived launchId=%s direction=(%.2f, %.2f, %.2f)", tostring(launchId), planarDirection.X, planarDirection.Y, planarDirection.Z),
		0.1
	)
	predictedLaunchScanEndsAt = math.huge
	player:SetAttribute("PredictedLaunchDirection", nil)
	player:SetAttribute("PredictedLaunchStartedAt", nil)
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
			if not wasLaunching then
				debugFoodScan("state-enter-launching", "StateUpdateEnteredLaunching activeLaunchId=" .. tostring(activeLaunchId), 0.1)
			end
			serverConfirmedLaunch = true
			predictedLaunchStartedAt = 0
			player:SetAttribute("PredictedLaunchDirection", nil)
			player:SetAttribute("PredictedLaunchStartedAt", nil)
		elseif wasLaunching then
			rollbackPredictedLaunch()
			activeLaunchId = nil
		end
	end
end)

gameplayFeedbackRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or message.EventType ~= "FoodHitRejected" then
		return
	end
	-- Server rejection is authoritative, but no heavy client correction is attempted.
end)
