--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameStates = require(Shared:WaitForChild("Constants"):WaitForChild("GameStates"))
local PhysicsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PhysicsConfig"))
local CollisionResponse = require(Shared:WaitForChild("Utils"):WaitForChild("CollisionResponse"))
local VelocityDecay = require(Shared:WaitForChild("Utils"):WaitForChild("VelocityDecay"))
local PawnLocator = require(Shared:WaitForChild("Utils"):WaitForChild("PawnLocator"))
local stateUpdateRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("StateUpdate") :: RemoteEvent
local reportFoodRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ReportFoodHit") :: RemoteEvent
local reportCollisionRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ReportCollision") :: RemoteEvent
local gameplayFeedbackRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("GameplayFeedback") :: RemoteEvent
local applySelfBounceRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ApplySelfBounce") :: RemoteEvent
local applyKnockbackRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ApplyKnockback") :: RemoteEvent
local clientDoLaunchRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ClientDoLaunch") :: RemoteEvent
local clockSyncRequestRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ClockSyncRequest") :: RemoteEvent
local clockSyncResponseRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):WaitForChild("ClockSyncResponse") :: RemoteEvent

local GRID_CELL_SIZE = 48
local Y_TOLERANCE = PhysicsConfig.Collision.YTolerance
local HIT_EPSILON = PhysicsConfig.Collision.Range
local REPORT_COOLDOWN = 1
local MIN_REPORT_SPEED = PhysicsConfig.Collision.MinReportSpeed
local LAUNCH_SCAN_GRACE_SECONDS = PhysicsConfig.Launch.ValidationGraceSeconds
local PREDICTED_LAUNCH_SCAN_SECONDS = 0.35
local EXISTING_VELOCITY_SCAN_SECONDS = 0.1

local lastHit: { [string]: number } = {}
local currentMovementState = GameStates.PlayerState.Idle
local launchScanGraceEndsAt = 0
local predictedLaunchScanEndsAt = 0
local predictedLaunchDirection: Vector3? = nil
local activeLaunchId: string? = nil
local lastRootPosition: Vector3? = nil
local selfBounceBlendToken = 0
local serverClockOffset = 0
local clockSyncSamples: { number } = {}
local sweepDebugStart: Part? = nil
local sweepDebugEnd: Part? = nil

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

local function isHumanMode(): boolean
	return player:GetAttribute("ActivePlayerMode") == GameStates.PlayerMode.Human
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
	if not model or getActiveCharacter() == model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end


local function resolveFoodCollisionVelocity(velocity: Vector3, normal: Vector3, rarity: any): Vector3
	if rarity == "Common" then
		return Vector3.new(velocity.X, 0, velocity.Z)
	end
	return CollisionResponse.ResolvePlanarBounce(velocity, normal, {
		Restitution = PhysicsConfig.Collision.FoodRestitution,
		TangentialDamping = PhysicsConfig.Collision.FoodTangentialDamping,
		MinSpeed = PhysicsConfig.Collision.MinPostCollisionSpeed,
		MaxSpeed = PhysicsConfig.Collision.MaxPostCollisionSpeed,
	})
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

	local normal = (root.Position - hitbox.Position).Magnitude > 0.001
		and (root.Position - hitbox.Position).Unit
		or Vector3.new(0, 0, -1)
		
	print(`Reporting food hit: foodId={foodId}, hitType={hitType}, observedSpeed={reportSpeed}`)
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
	-- are played when ApplyKnockback arrives from the server.
end

local function applyPredictedPlayerBounce(targetPlayer: Player, root: BasePart): Vector3
	local targetRoot = getPlayerRoot(targetPlayer)
	local offset = (targetRoot and targetRoot.Position or root.Position) - root.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)
	local normal = if planar.Magnitude > PhysicsConfig.Movement.InputDeadzone then planar.Unit else Vector3.new(1, 0, 0)
	local attackerVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local defenderVelocity = if targetRoot then Vector3.new(targetRoot.AssemblyLinearVelocity.X, 0, targetRoot.AssemblyLinearVelocity.Z) else Vector3.zero
	local predicted = VelocityDecay.ResolvePlayerCollision(attackerVelocity, defenderVelocity, normal).AttackerVelocity
	root.AssemblyLinearVelocity = Vector3.new(predicted.X, root.AssemblyLinearVelocity.Y, predicted.Z)
	return if targetRoot then (root.Position + targetRoot.Position) * 0.5 else root.Position
end

local function reportPlayerHit(targetPlayer: Player, root: BasePart, _observedSpeed: number?)
	local now = os.clock()
	local cooldownKey = `Player:{targetPlayer.UserId}`
	if (lastHit[cooldownKey] or 0) > now then
		return
	end
	lastHit[cooldownKey] = now + REPORT_COOLDOWN
	local hitPosition = applyPredictedPlayerBounce(targetPlayer, root)
	triggerPredictedPlayerHitFeedback(targetPlayer, hitPosition)
	print(`Reporting predicted player hit: targetUserId={targetPlayer.UserId}`)
	reportCollisionRemote:FireServer({
		targetUserId = targetPlayer.UserId,
		clientTimestamp = getSyncedServerTime(),
		hitPosition = hitPosition,
	})
end



local function sphereCastLaunching(root: BasePart, dt: number, previousPosition: Vector3?)
    local currentPos = root.Position
    local castStart = previousPosition or currentPos
    local velocity = root.AssemblyLinearVelocity
    local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local speed = planarVelocity.Magnitude

    -- 1. TÍNH QUÃNG ĐƯỜNG THỰC TẾ GIỮA 2 FRAME (CỐT LÕI CỦA CCD)
    local motion = currentPos - castStart
    local planarMotion = Vector3.new(motion.X, 0, motion.Z)
    
    local castVector: Vector3
    
    -- 2. XÁC ĐỊNH HƯỚNG VÀ ĐỘ DÀI TIA QUÉT
    if planarMotion.Magnitude >= 0.001 then
        -- TRƯỜNG HỢP CHUẨN: Nhân vật có di chuyển. 
        -- Quét chính xác quãng đường vừa nối từ frame trước đến frame này.
        castVector = planarMotion
    else
        -- FALLBACK: Frame đầu tiên chưa có chuyển động rõ rệt, 
        -- hoặc `previousPosition` bị nil. Lúc này mới dùng đến vận tốc để quét bù.
        if speed >= MIN_REPORT_SPEED then
            -- Quét một đoạn ngắn bằng quãng đường dự kiến đi được trong 1 frame (V * dt)
            castVector = planarVelocity.Unit * math.max(speed * dt, 0.1)
        else
            setSweepDebugVisible(false, nil, nil, nil)
            return
        end
    end

    local direction = castVector.Unit
    local baseDistance = castVector.Magnitude
    local observedSpeed = math.max(speed, baseDistance / math.max(dt, 1 / 240))

    if observedSpeed < MIN_REPORT_SPEED then
        setSweepDebugVisible(false, nil, nil, nil)
        return
    end

    -- 3. CỘNG PADDING VÀ THỰC HIỆN SPHERECAST
    local castDistance = baseDistance + PhysicsConfig.Collision.SphereCastDistancePadding
    local radius = (math.max(root.Size.X, root.Size.Z) * 0.5) + PhysicsConfig.Collision.SphereCastRadiusPadding
    
    setSweepDebugVisible(true, castStart, castStart + direction * castDistance, radius)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local activeCharacter = getActiveCharacter()
    params.FilterDescendantsInstances = if activeCharacter then { activeCharacter } else {}
    params.IgnoreWater = true
    
    -- Quét từ vị trí CUỐI CÙNG của frame trước, hướng tới vị trí HIỆN TẠI
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
end

RunService.RenderStepped:Connect(function(dt)
	local root = getRoot()
	if not root then
		lastRootPosition = nil
		setSweepDebugVisible(false, nil, nil, nil)
		return
	end

	if isHumanMode() then
		lastRootPosition = nil
		setSweepDebugVisible(false, nil, nil, nil)
		detectCommonFoodByDistance(root)
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

clientDoLaunchRemote.OnClientEvent:Connect(function(direction: any, _initialSpeed: any, _serverMass: any, launchId: any)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end
	predictedLaunchDirection = planarDirection.Unit
	if typeof(launchId) == "string" then
		activeLaunchId = launchId
	end
	predictedLaunchScanEndsAt = os.clock() + PREDICTED_LAUNCH_SCAN_SECONDS
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

applySelfBounceRemote.OnClientEvent:Connect(function(correctedVelocity: any)
	if typeof(correctedVelocity) ~= "Vector3" then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	selfBounceBlendToken += 1
	local token = selfBounceBlendToken
	local blendDuration = 0.125
	local elapsed = 0
	local startVelocity = root.AssemblyLinearVelocity
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		if token ~= selfBounceBlendToken or not root.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		elapsed += dt
		local alpha = math.clamp(elapsed / blendDuration, 0, 1)
		local blended = startVelocity:Lerp(Vector3.new(correctedVelocity.X, startVelocity.Y, correctedVelocity.Z), alpha)
		root.AssemblyLinearVelocity = blended
		if alpha >= 1 and connection then
			connection:Disconnect()
		end
	end)
end)

applyKnockbackRemote.OnClientEvent:Connect(function(knockbackImpulse: any, _damage: any)
	if typeof(knockbackImpulse) ~= "Vector3" then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.new(knockbackImpulse.X, root.AssemblyLinearVelocity.Y, knockbackImpulse.Z)
	-- Local hit reaction/VFX/SFX/damage presentation can subscribe here without allowing
	-- the attacker to author defender physics.
end)
