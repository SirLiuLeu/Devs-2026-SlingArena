--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local CONSUME_COOLDOWN = 0.12
local DEFAULT_HIT_COOLDOWN = 0.18
local FOOD_UI_TEMPLATE_PATH = { "Assets", "UI", "FoodWorldUI" }
local DAMAGE_MIN_VELOCITY = 20
local DAMAGE_MAX_VELOCITY = 170
local DAMAGE_BASE = 100
local FOOD_HIT_RADIUS_PADDING = PhysicsConfig.Collision.Range
local NORMAL_EPSILON = 1e-5
local MIN_SPEED_EPSILON = 1e-3
local REFLECTION_DAMPING = 0.88
local LAST_HIT_VELOCITY_DAMPING = 0.9
local GRID_CELL_SIZE = 48
local Y_TOLERANCE = PhysicsConfig.Collision.YTolerance
local VALIDATION_EPSILON = PhysicsConfig.Collision.ValidationTolerance
local MAX_ALLOWED_SPEED = PhysicsConfig.Collision.MaxAllowedSpeed
-- FIX 1: Raise per-player hit request cooldown to match the client-side REPORT_COOLDOWN
-- increase (0.1s). This prevents the server from processing the rare duplicate that
-- slips through if the client fires two reports just before the cooldown resets.
local HIT_REQUEST_COOLDOWN = 0.1
local SAME_TARGET_FOOD_DEDUPE_SECONDS = 0.28
local MAX_COLLISIONS_PER_LAUNCH = 3

local FIRE_FOOD_BURN_COOLDOWN = 1
local FIRE_FOOD_BURN_DAMAGE_RATIO = 0.4
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local COMMON_ALLOWED_STATES = {
	[GameStates.PlayerState.Launching] = true,
	[GameStates.PlayerState.Moving] = true,
	[GameStates.PlayerState.Idle] = true,
}

-- FIX 3 ROOT CAUSE: The server validation rejects hits when MovementState == "Idle" even
-- though the player has a non-zero horizontal speed. This happens because:
--   1. The client fires ReportFoodHit immediately after clientDoLaunchRemote fires.
--   2. SlingService._stepMovementStates reads root.AssemblyLinearVelocity from the SERVER,
--      which is 0 (physics replication hasn't arrived yet since the root is client-owned).
--   3. Because server-side speed == 0, shouldStop triggers immediately, transitioning
--      the state to Recovering/Idle before the food report arrives.
-- Fix: isLaunchHitValidationActive now also accepts "Idle" state when the per-player
-- LaunchValidationGraceEndsAt attribute is still active. The grace window is already
-- set by SlingService.ReleaseCharge to now + ValidationGraceSeconds * 20, so any food
-- hit reported during that window (even after the premature Idle transition) is accepted.
-- No new attribute is needed — the existing LaunchValidationGraceEndsAt covers this case.
local function isLaunchHitValidationActive(player: Player, movementState: string?): boolean
	if movementState == GameStates.PlayerState.Launching then
		return true
	end
	if movementState == "Recovering" then
		return true
	end
	-- FIX 3: Accept hits from any state while the launch grace window is active.
	-- This covers the premature Idle/Recovering transition caused by server-side
	-- velocity reading 0 immediately after a client-authoritative launch.
	local graceEndsAt = player:GetAttribute("LaunchValidationGraceEndsAt")
	return typeof(graceEndsAt) == "number"
		and graceEndsAt > 0
		and os.clock() <= graceEndsAt
end

local REQUIRED_FOOD_MODELS = {
	CommonBlue = true,
	CommonGreen = true,
	CommonRed = true,
	UncommonIce = true,
	RareAmber = true,
	EpicViolet = true,
	LegendaryGold = true,
	MythicCrystal = true,
	UniqueCore = true,
	UniqueCrown = true,
}

local FoodService = {}
FoodService.__index = FoodService

local FOOD_TYPE_COLORS = {
	Common = Color3.fromRGB(84, 255, 119),
	Uncommon = Color3.fromRGB(102, 217, 255),
	Rare = Color3.fromRGB(90, 161, 255),
	Epic = Color3.fromRGB(188, 119, 255),
	Legendary = Color3.fromRGB(255, 196, 90),
	Mythic = Color3.fromRGB(255, 122, 215),
	Unique = Color3.fromRGB(255, 88, 88),
}

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function isArenaMapName(mapName: string?): boolean
	return type(mapName) == "string" and mapName ~= "LobbyMap" and mapName ~= "Lobby" and string.find(mapName, "Arena", 1, true) ~= nil
end

local function buildPhysicalProperties(): PhysicalProperties
	local physical = PhysicsConfig.PhysicalProperties
	return PhysicalProperties.new(
		physical.Density,
		physical.Friction,
		physical.Elasticity,
		physical.FrictionWeight,
		physical.ElasticityWeight
	)
end

local function anchorFoodModel(model: Model)
	local physicalProperties = buildPhysicalProperties()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CustomPhysicalProperties = physicalProperties
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function flattenXZ(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function sqrDistanceXZ(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

local function sanitizeUnit(v: Vector3, fallback: Vector3): Vector3
	if v.Magnitude <= NORMAL_EPSILON then
		return fallback
	end
	return v.Unit
end

function FoodService.new(context)
	local self = setmetatable({}, FoodService)
	self._context = context
	self._foodModels = {}
	self._foodSpawnsByZone = {}
	self._foodEntries = {}
	self._foodById = {}
	self._foodGrid = {}
	self._foodByInstance = {}
	self._playerConsumeCooldown = {}
	self._slingFoodHitCooldown = {}
	self._hitRequestCooldown = {}
	self._foodHitByLaunchTarget = {}
	return self
end

local function gridKeyFromPosition(pos: Vector3): string
	return string.format("%d:%d", math.floor(pos.X / GRID_CELL_SIZE), math.floor(pos.Z / GRID_CELL_SIZE))
end

function FoodService:_addEntryToGrid(entry: any)
	local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
	if not (hitbox and hitbox:IsA("BasePart")) then
		return
	end
	local key = gridKeyFromPosition(hitbox.Position)
	self._foodGrid[key] = self._foodGrid[key] or {}
	self._foodGrid[key][entry.Id] = entry
	entry.GridKey = key
end

function FoodService:_removeEntryFromGrid(entry: any)
	if not entry.GridKey then
		return
	end
	local bucket = self._foodGrid[entry.GridKey]
	if bucket then
		bucket[entry.Id] = nil
		if next(bucket) == nil then
			self._foodGrid[entry.GridKey] = nil
		end
	end
	entry.GridKey = nil
end

function FoodService:_resolveFoodUiTemplate(): BillboardGui?
	local current = ReplicatedStorage
	for _, childName in ipairs(FOOD_UI_TEMPLATE_PATH) do
		current = current and current:FindFirstChild(childName)
	end
	if current and current:IsA("BillboardGui") then
		return current
	end
	return nil
end

function FoodService:_attachFoodUI(entry: any, hitbox: BasePart)
	local template = self:_resolveFoodUiTemplate()
	if not template then
		return
	end
	local ui = template:Clone()
	ui.Name = "FoodWorldUI"
	ui.Adornee = hitbox
	ui.Enabled = false
	ui.Parent = entry.Instance
	local fill = ui:FindFirstChild("HpBarBackground")
	fill = fill and fill:FindFirstChild("HpBarFill")
	if fill and fill:IsA("Frame") then
		local foodType = FoodConfig.Foods[entry.FoodType] and FoodConfig.Foods[entry.FoodType].Type
		fill.BackgroundColor3 = FOOD_TYPE_COLORS[foodType] or FOOD_TYPE_COLORS.Common
	end
	entry.WorldUI = ui
end

function FoodService:_publishFoodHp(entry: any)
	if not entry or not entry.Instance then
		return
	end
	entry.Instance:SetAttribute("FoodHP", math.max(0, entry.CurrentHP))
	entry.Instance:SetAttribute("FoodMaxHP", math.max(1, entry.MaxHP))
end

function FoodService:Init()
	print("[FoodService] Init called")
	self:_loadFoodModels()
	self:_scanAndSpawnAllArenaMaps()
end

function FoodService:_loadFoodModels()
	self._foodModels = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("FoodModels")

	if not (folder and folder:IsA("Folder")) then
		warn("[FoodService] Missing ReplicatedStorage.Assets.FoodModels")
		return
	end
	
	for foodName in pairs(REQUIRED_FOOD_MODELS) do
		local model = folder:FindFirstChild(foodName)
		if model and model:IsA("Model") then
			local hitbox = model:FindFirstChild("Hitbox")
			local visual = model:FindFirstChild("Visual")
			if hitbox and hitbox:IsA("BasePart") and visual then
				self._foodModels[foodName] = model
			else
				warn(string.format("[FoodService] Invalid food model shape: %s", model:GetFullName()))
			end
		else
			warn(string.format("[FoodService] Missing food model: %s", foodName))
		end
	end
end

function FoodService:_scanAndSpawnAllArenaMaps()
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not (mapsRoot and mapsRoot:IsA("Folder")) then
		return
	end
	for _, child in ipairs(mapsRoot:GetChildren()) do
		if child:IsA("Model") and isArenaMapName(child.Name) then
			self:ClearMapFood(child)
			self:SpawnFoodForMap(child)
		end
	end
end

function FoodService:_pickWeightedType(zoneName: string): string?
	local weights = FoodConfig.ZoneWeights[zoneName]
	if not weights then
		return nil
	end
	local totalWeight = 0
	for rarity, weight in pairs(weights) do
		if weight > 0 and FoodConfig.TypePools[rarity] then
			totalWeight += weight
		end
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = math.random() * totalWeight
	local run = 0
	for rarity, weight in pairs(weights) do
		if weight > 0 and FoodConfig.TypePools[rarity] then
			run += weight
			if roll <= run then
				local pool = FoodConfig.TypePools[rarity]
				if #pool > 0 then
					return pool[math.random(1, #pool)]
				end
			end
		end
	end
	return nil
end

function FoodService:_buildSpawnPosition(spawnPart: BasePart, usedPositions: { Vector3 }): Vector3
	local radius = FoodConfig.SpawnRadius
	local minDistance = FoodConfig.MinNoOverlapDistance
	local minDistanceSq = minDistance * minDistance
	local fallback = spawnPart.Position
	for _ = 1, 6 do
		local offset = Vector3.new(math.random(-radius, radius), 0, math.random(-radius, radius))
		local candidate = spawnPart.Position + offset
		local overlaps = false
		for _, prior in ipairs(usedPositions) do
			if sqrDistanceXZ(candidate, prior) < minDistanceSq then
				overlaps = true
				break
			end
		end
		if not overlaps then
			return candidate
		end
	end
	return fallback
end

function FoodService:_spawnFoodOnSpawn(mapModel: Model, foodContainer: Folder, spawnPart: BasePart, zoneName: string)
	local foodType = self:_pickWeightedType(zoneName)
	if not foodType then
		return
	end
	local foodRule = FoodConfig.Foods[foodType]
	local template = self._foodModels[foodType]
	if not (foodRule and template) then
		return
	end
	local usedPositions = self._foodSpawnsByZone[spawnPart] or {}
	local spawnPos = self:_buildSpawnPosition(spawnPart, usedPositions)
	table.insert(usedPositions, spawnPos)
	self._foodSpawnsByZone[spawnPart] = usedPositions

	local clone = template:Clone()
	clone.Name = foodType
	clone.Parent = foodContainer
	anchorFoodModel(clone)
	local hitbox = clone:FindFirstChild("Hitbox") :: BasePart?
	if not hitbox then
		clone:Destroy()
		return
	end
	clone.PrimaryPart = hitbox
	clone:PivotTo(CFrame.new(spawnPos))
	local entry = {
		Id = game:GetService("HttpService"):GenerateGUID(false),
		Instance = clone,
		FoodType = foodType,
		SpawnPart = spawnPart,
		ZoneName = zoneName,
		IsActive = true,
		IsConsumed = false,
		MaxHP = math.max(0, foodRule.HP),
		CurrentHP = math.max(0, foodRule.HP),
		LastHitBy = nil,
	}
	clone:SetAttribute("FoodId", entry.Id)
	clone:SetAttribute("FoodRarity", foodRule.Type)
	if entry.MaxHP > 0 then
		self:_attachFoodUI(entry, hitbox)
	end
	self:_publishFoodHp(entry)
	self._foodEntries[clone] = entry
	self._foodById[entry.Id] = entry
	self._foodByInstance[clone] = entry
	self:_addEntryToGrid(entry)
end

function FoodService:ClearMapFood(mapModel: Model)
	for instance, entry in pairs(self._foodEntries) do
		if instance and instance.Parent and instance:IsDescendantOf(mapModel) then
			entry.IsActive = false
			self:_removeEntryFromGrid(entry)
			instance:Destroy()
			self._foodEntries[instance] = nil
			if entry.Id then
				self._foodById[entry.Id] = nil
			end
			self._foodByInstance[instance] = nil
		end
	end
end

function FoodService:SpawnFoodForMap(mapModel: Model)
	local foodContainer = mapModel:FindFirstChild("FoodContainer")
	local foodSpawns = mapModel:FindFirstChild("FoodSpawns")
	if not (foodContainer and foodContainer:IsA("Folder")) then
		warn(string.format("[FoodService] Missing required folder: %s", mapModel:GetFullName() .. ".FoodContainer"))
		return
	end
	if not (foodSpawns and foodSpawns:IsA("Folder")) then
		warn(string.format("[FoodService] Missing required folder: %s", mapModel:GetFullName() .. ".FoodSpawns"))
		return
	end
	for _, zoneFolder in ipairs(foodSpawns:GetChildren()) do
		if zoneFolder:IsA("Folder") and FoodConfig.ZoneWeights[zoneFolder.Name] then
			for _, spawnPart in ipairs(zoneFolder:GetChildren()) do
				if spawnPart:IsA("BasePart") then
					self:_spawnFoodOnSpawn(mapModel, foodContainer, spawnPart, zoneFolder.Name)
				end
			end
		end
	end
end

function FoodService:_isPlayerAlive(player: Player): boolean
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return true
	end
	local state = stateService:GetState(player)
	return state ~= nil and state.IsAlive == true
end

function FoodService:_rewardFoodKill(entry: any)
	local player = entry.LastHitBy
	local rule = FoodConfig.Foods[entry.FoodType]
	if not (player and rule) then
		return
	end
	self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
	if rule.DiamondRate > 0 and rule.DiamondAmount > 0 and math.random() <= rule.DiamondRate then
		local stateService = getService(self._context, "PlayerStateService")
		local state = stateService and stateService:GetState(player)
		if state then
			state.Diamonds = math.max(0, state.Diamonds + rule.DiamondAmount)
			stateService:PublishState(player)
		end
	end
end

function FoodService:_consumeFood(entry: any, player: Player)
	if not entry.IsActive or entry.IsConsumed then
		return
	end
	entry.IsConsumed = true
	entry.IsActive = false
	local instance = entry.Instance
	self._foodEntries[instance] = nil
	self:_removeEntryFromGrid(entry)
	if entry.Id then
		self._foodById[entry.Id] = nil
	end
	self._foodByInstance[instance] = nil
	if instance and instance.Parent then
		instance:Destroy()
	end
	local rule = FoodConfig.Foods[entry.FoodType]
	if rule then
		self._context.EventBus:Fire("CollisionDetected", "Food", player, nil, {})
		local stateService = getService(self._context, "PlayerStateService")
		if rule.Touch then
			self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
		end
		if stateService and rule.HealHP > 0 then
			stateService:Heal(player, rule.HealHP)
			stateService:PublishState(player)
		end
		local respawnDelay = rule.RespawnTime
		task.delay(respawnDelay, function()
			if entry.SpawnPart and entry.SpawnPart.Parent then
				local mapModel = entry.SpawnPart:FindFirstAncestorOfClass("Model")
				if mapModel then
					local foodContainer = mapModel:FindFirstChild("FoodContainer")
					if foodContainer and foodContainer:IsA("Folder") then
						self:_spawnFoodOnSpawn(mapModel, foodContainer, entry.SpawnPart, entry.ZoneName)
					end
				end
			end
		end)
	end
end

function FoodService:_computeEffectiveRadius(playerRadius: number, foodRadius: number, speed: number, ping: number): number
	return playerRadius + foodRadius + (speed * ping) + VALIDATION_EPSILON
end

-- FIX 2 + FIX 3: _validateFoodHit now accepts observedSpeed from the client payload and
-- uses it as a fallback when root.AssemblyLinearVelocity reads low due to replication lag.
-- FIX 3: isLaunchHitValidationActive now checks the grace window for any movementState,
-- so a premature Idle/Recovering transition no longer blocks valid hits.
function FoodService:_validateFoodHit(player: Player, entry: any, payload: any): boolean
	if not (entry and entry.IsActive and not entry.IsConsumed and entry.Instance and entry.Instance.Parent) then
		return false
	end
	local playerService = getService(self._context, "PlayerService")
	local root = playerService and playerService:GetRoot(player)
	if not (root and self:_isPlayerAlive(player)) then
		return false
	end

	-- FIX 2: Use max of server-measured speed and client-reported observedSpeed.
	-- Server-side velocity can read 0 immediately after a client-authoritative launch
	-- because physics replication from the client hasn't arrived yet.
	local serverSpeed = root.AssemblyLinearVelocity.Magnitude
	local clientObservedSpeed = (payload and typeof(payload.observedSpeed) == "number")
		and math.clamp(payload.observedSpeed, 0, MAX_ALLOWED_SPEED)
		or 0
	local speed = math.max(serverSpeed, clientObservedSpeed)

	if speed > MAX_ALLOWED_SPEED then
		return false
	end
	local hitbox = entry.Instance:FindFirstChild("Hitbox")
	if not (hitbox and hitbox:IsA("BasePart")) then
		return false
	end
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	local rule = FoodConfig.Foods[entry.FoodType]
	local movementState = state and state.MovementState
	if not (rule and movementState) then
		return false
	end

	-- FIX 2: Use clientObservedSpeed as fallback for horizontalSpeed when server reads 0.
	local serverHorizontalSpeed = flattenXZ(root.AssemblyLinearVelocity).Magnitude
	local horizontalSpeed = math.max(serverHorizontalSpeed, clientObservedSpeed)

	if (not rule.Touch) and entry.MaxHP > 0 then
		if not isLaunchHitValidationActive(player, movementState)
				or horizontalSpeed < PhysicsConfig.Collision.FoodHitMinHorizontalSpeed
			then
			print(string.format("[FoodService] Validation failed: Player movement state %s with horizontal speed %.2f does not meet requirements for hitting foodId=%s", tostring(movementState), horizontalSpeed, tostring(payload and payload.foodId)))
			return false
		end
	elseif not COMMON_ALLOWED_STATES[movementState] then
		-- FIX 3: Also allow common food collection during grace window (covers premature Idle).
		if not isLaunchHitValidationActive(player, movementState) then
			return false
		end
	end

	local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local foodRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + FOOD_HIT_RADIUS_PADDING
	local pingSec = (player:GetNetworkPing() or 0) * 0.5
	local rEffective = self:_computeEffectiveRadius(playerRadius, foodRadius, speed, pingSec)
	local currPos = root.Position
	local reportPos = if payload and typeof(payload.currPos) == "Vector3" then payload.currPos else currPos
	local distancePass = sqrDistanceXZ(currPos, hitbox.Position) <= (rEffective * rEffective)
	local reportedDistancePass = sqrDistanceXZ(reportPos, hitbox.Position) <= (rEffective * rEffective)
	if not (distancePass or reportedDistancePass) then
		return false
	end
	if math.abs(currPos.Y - hitbox.Position.Y) > Y_TOLERANCE and math.abs(reportPos.Y - hitbox.Position.Y) > Y_TOLERANCE then
		return false
	end

	return true
end

function FoodService:_applySlingDamage(entry: any, player: Player, velocity: number)
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule or entry.CurrentHP <= 0 then
		return
	end
	local slingService = getService(self._context, "SlingService")
	local launchState = slingService and slingService:GetLaunchState(player) or nil
	local initialSpeed = launchState and math.max(launchState.initialSpeed or 0, launchState.currentSpeed or 0) or velocity
	local initialDamage = math.clamp(initialSpeed, DAMAGE_MIN_VELOCITY, DAMAGE_MAX_VELOCITY) * DAMAGE_BASE
	local speedRatio = if initialSpeed > 0 then math.clamp(velocity / initialSpeed, 0.3, 1) else 0.3
	local damage = initialDamage * speedRatio
	local stateService = getService(self._context, "PlayerStateService")
	local abilityType = stateService and stateService:GetSlingAbilityType(player) or "NormalSling"
	if abilityType == "FireSling" then
		local burnKey = string.format("%s:%d", tostring(entry.Id), player.UserId)
		local now = os.clock()
		local nextAllowedAt = self._slingFoodHitCooldown[burnKey] or 0
		if now >= nextAllowedAt then
			self._slingFoodHitCooldown[burnKey] = now + FIRE_FOOD_BURN_COOLDOWN
			damage += damage * FIRE_FOOD_BURN_DAMAGE_RATIO
		end
	end
	local before = entry.CurrentHP
	entry.LastHitBy = player
	entry.CurrentHP = math.max(0, entry.CurrentHP - damage)
	local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
	local playerService = getService(self._context, "PlayerService")
	if hitbox and hitbox:IsA("BasePart") and playerService and entry.CurrentHP ~= before then
		playerService:ShowFloatingHpChange(hitbox, entry.CurrentHP - before)
	end
	self:_publishFoodHp(entry)
	if entry.CurrentHP <= 0 then
		self:_rewardFoodKill(entry)
		self:_consumeFood(entry, player)
	end
end

function FoodService:_computeCollisionNormal(playerPosition: Vector3, foodPosition: Vector3, velocity: Vector3): Vector3
	local fallbackNormal = sanitizeUnit(flattenXZ(-velocity), Vector3.new(0, 0, -1))
	return sanitizeUnit(playerPosition - foodPosition, fallbackNormal)
end

function FoodService:_reflectVelocity(velocity: Vector3, normal: Vector3): Vector3
	if velocity.Magnitude <= MIN_SPEED_EPSILON then
		return Vector3.zero
	end
	local unitNormal = sanitizeUnit(normal, Vector3.new(0, 0, -1))
	local reflected = velocity - (2 * velocity:Dot(unitNormal) * unitNormal)
	if reflected.Magnitude <= MIN_SPEED_EPSILON then
		return Vector3.zero
	end
	return reflected * math.max(REFLECTION_DAMPING, LAST_HIT_VELOCITY_DAMPING)
end

function FoodService:_resolvePenetration(root: BasePart, hitbox: BasePart, normal: Vector3)
	local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + FOOD_HIT_RADIUS_PADDING
	local currentOffset = root.Position - hitbox.Position
	local planarDistance = flattenXZ(currentOffset).Magnitude
	local penetrationDepth = radius - planarDistance
	if penetrationDepth <= 0 then
		return
	end
	local pushNormal = sanitizeUnit(flattenXZ(normal), Vector3.new(0, 0, -1))
	local pushOut = pushNormal * (penetrationDepth + 0.05)
	root.CFrame = root.CFrame + Vector3.new(pushOut.X, 0, pushOut.Z)
end

function FoodService:_startCollisionLoop()
	return
end

function FoodService:_collectNearbyEntries(position: Vector3): { any }
	local cx = math.floor(position.X / GRID_CELL_SIZE)
	local cz = math.floor(position.Z / GRID_CELL_SIZE)
	local out = {}
	for gx = cx - 1, cx + 1 do
		for gz = cz - 1, cz + 1 do
			local bucket = self._foodGrid[string.format("%d:%d", gx, gz)]
			if bucket then
				for _, entry in pairs(bucket) do
					table.insert(out, entry)
				end
			end
		end
	end
	return out
end

function FoodService:Start()
	local remote = self._context.Remotes:FindFirstChild("ReportFoodHit")
	local feedbackRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		local now = os.clock()
		if (self._hitRequestCooldown[player] or 0) > now then
			return
		end
		self._hitRequestCooldown[player] = now + HIT_REQUEST_COOLDOWN
		if type(payload) ~= "table" then
			return
		end
		local entry = self._foodById[payload.foodId]
		local slingService = getService(self._context, "SlingService")
		local launchState = slingService and slingService:GetLaunchState(player) or nil
		local launchStart = launchState and launchState.startTime or nil
		local launchId = (typeof(launchStart) == "number") and string.format("%d:%.6f", player.UserId, launchStart) or nil
		if launchState then
			launchState.collisions = launchState.collisions or 0
			if launchState.collisions >= MAX_COLLISIONS_PER_LAUNCH then
				return
			end
		end
		if launchId and entry and entry.Id then
			self._foodHitByLaunchTarget[launchId] = self._foodHitByLaunchTarget[launchId] or {}
			local lastHitAt = self._foodHitByLaunchTarget[launchId][entry.Id]
			if lastHitAt and (now - lastHitAt) < SAME_TARGET_FOOD_DEDUPE_SECONDS then
				return
			end
			self._foodHitByLaunchTarget[launchId][entry.Id] = now
		end

		-- FIX 1: The IsConsumed / IsActive flags act as the authoritative one-hit guard.
		-- _consumeFood sets IsConsumed=true and removes from _foodById atomically before
		-- any async work. Any duplicate report arriving after that finds entry=nil (removed
		-- from _foodById) or entry.IsConsumed=true and is rejected without damage.
		if not self:_validateFoodHit(player, entry, payload) then
			if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
				feedbackRemote:FireClient(player, {
					EventType = "FoodHitRejected",
					Payload = {
						FoodId = payload.foodId,
						ServerResync = true,
					},
				})
			end
			return
		end
		local rule = FoodConfig.Foods[entry.FoodType]
		if not rule then
			return
		end
		if rule.Touch then
			self:_consumeFood(entry, player)
		elseif entry.MaxHP > 0 then
			local playerService = getService(self._context, "PlayerService")
			local root = playerService and playerService:GetRoot(player)
			if root then
				-- FIX 2: Use max of server and client-reported speed for damage calc,
				-- same as in _validateFoodHit, so damage isn't 0 on strong launches.
				local serverHorizontalSpeed = flattenXZ(root.AssemblyLinearVelocity).Magnitude
				local clientObservedSpeed = (payload and typeof(payload.observedSpeed) == "number")
					and math.clamp(payload.observedSpeed, 0, MAX_ALLOWED_SPEED)
					or 0
				local horizontalSpeed = math.max(serverHorizontalSpeed, clientObservedSpeed)

				self:_applySlingDamage(entry, player, horizontalSpeed)

				-- FIX 4: Only apply impulse (bounce) for non-common (HP) food.
				-- Common food is pass-through: no physical response from the server either.
				-- rule.Touch == true means Common food; rule.MustHit == true means HP food.
				if rule.MustHit and not rule.Touch then
					local impulse = flattenXZ(root.AssemblyLinearVelocity) * -root.AssemblyMass * 0.18
					root:ApplyImpulse(Vector3.new(impulse.X, 0, impulse.Z))
				end
				if launchState then
					launchState.collisions = (launchState.collisions or 0) + 1
				end
			end
		end
	end)
end

function FoodService:LoadMapResources(mapName: string)
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not (mapsRoot and mapsRoot:IsA("Folder")) then
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if mapModel and mapModel:IsA("Model") and isArenaMapName(mapName) then
		self:ClearMapFood(mapModel)
		self:SpawnFoodForMap(mapModel)
	end
end

function FoodService:SpawnFoodForActiveMap()
	local mapService = getService(self._context, "MapService")
	local arena = mapService and mapService:GetArenaModel()
	if arena then
		self:SpawnFoodForMap(arena)
	end
end

function FoodService:SpawnFoodForMapName(mapName: string)
	self:LoadMapResources(mapName)
end

return FoodService
