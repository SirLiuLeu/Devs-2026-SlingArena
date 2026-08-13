--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)
local CollisionValidation = require(script.Parent.Helpers.CollisionValidation)

local FOOD_UI_TEMPLATE_PATH = { "Assets", "UI", "FoodWorldUI" }
local FOOD_HIT_RADIUS_PADDING = PhysicsConfig.Collision.Range
local NORMAL_EPSILON = 1e-5
local MIN_SPEED_EPSILON = 1e-3
local GRID_CELL_SIZE = 48
local VALIDATION_EPSILON = PhysicsConfig.Collision.ValidationTolerance
local DEBUG_FOOD_HIT_REJECTS = false
local SPAWN_POSITION_RETRY_LIMIT = 30

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local function buildRequiredFoodModels(): { [string]: boolean }
	local required = {}
	for foodName in pairs(FoodConfig.Foods) do
		required[foodName] = true
	end
	return required
end

local FoodService = {}
FoodService.__index = FoodService

local FOOD_TYPE_COLORS = {
	Common = Color3.fromRGB(84, 255, 119),
	Uncommon = Color3.fromRGB(102, 217, 255),
	Rare = Color3.fromRGB(90, 161, 255),
	Epic = Color3.fromRGB(188, 119, 255),
	Legendary = Color3.fromRGB(255, 196, 90),
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

local function resolveFoodHitbox(foodModel: Model): BasePart?
	local primaryPart = foodModel.PrimaryPart
	if primaryPart then
		return primaryPart
	end

	local hitbox = foodModel:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		foodModel.PrimaryPart = hitbox
		return hitbox
	end

	return nil
end

local function getAnchorSurfacePosition(foodModel: Model, spawnAnchor: BasePart, horizontalPosition: Vector3?): Vector3?
	local hitbox = resolveFoodHitbox(foodModel)
	if not hitbox then
		warn(string.format("[FoodService] Food model %s is missing a PrimaryPart/Hitbox", foodModel:GetFullName()))
		return nil
	end

	local floorY = spawnAnchor.Position.Y + (spawnAnchor.Size.Y / 2)
	local targetY = floorY + (hitbox.Size.Y / 2)
	local xzPosition = horizontalPosition

	if not xzPosition then
		local localX = (math.random() - 0.5) * spawnAnchor.Size.X
		local localZ = (math.random() - 0.5) * spawnAnchor.Size.Z
		xzPosition = spawnAnchor.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
	end

	return Vector3.new(xzPosition.X, targetY, xzPosition.Z)
end

local function pivotFoodToAnchorSurface(foodModel: Model, spawnAnchor: BasePart, horizontalPosition: Vector3?): Vector3?
	local targetPosition = getAnchorSurfacePosition(foodModel, spawnAnchor, horizontalPosition)
	if not targetPosition then
		return nil
	end

	foodModel:PivotTo(CFrame.new(targetPosition))
	return targetPosition
end

local function spawnFood(foodModel: Model, spawnAnchor: BasePart): Model?
	local clone = foodModel:Clone()
	if not resolveFoodHitbox(clone) then
		clone:Destroy()
		return nil
	end

	anchorFoodModel(clone)
	if not pivotFoodToAnchorSurface(clone, spawnAnchor) then
		clone:Destroy()
		return nil
	end

	return clone
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
	
	for foodName in pairs(buildRequiredFoodModels()) do
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

function FoodService:_getZoneSpawnSetting(zoneName: string, settingName: string): number
	local settings = FoodConfig.ZoneSpawnSettings[zoneName]
	local value = settings and settings[settingName]
	if type(value) == "number" then
		return value
	end
	return 0
end

function FoodService:_getSpawnCountForZone(zoneName: string): number
	return self:_getZoneSpawnSetting(zoneName, "ActivePerSpawn")
end

function FoodService:_getPlacementRadiusForZone(zoneName: string): number
	return self:_getZoneSpawnSetting(zoneName, "PlacementRadius")
end

function FoodService:_getFoodPlacementRadius(template: Model): number
	local hitbox = template:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		return math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
	end
	return 0
end

function FoodService:_isSpawnPositionValid(candidate: Vector3, foodRadius: number, batchPositions: { Vector3 }, batchRadii: { number }): boolean
	for index, prior in ipairs(batchPositions) do
		local spacing = foodRadius + (batchRadii[index] or 0) + FoodConfig.MinNoOverlapDistance
		if sqrDistanceXZ(candidate, prior) <= spacing * spacing then
			return false
		end
	end

	for _, entry in ipairs(self:_collectNearbyEntries(candidate)) do
		local instance = entry.Instance
		local hitbox = instance and instance:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") then
			local otherRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
			local spacing = foodRadius + otherRadius + FoodConfig.MinNoOverlapDistance
			if sqrDistanceXZ(candidate, hitbox.Position) <= spacing * spacing then
				return false
			end
		end
	end

	return true
end

function FoodService:_buildSpawnPosition(spawnPart: BasePart, zoneName: string, foodRadius: number, batchPositions: { Vector3 }, batchRadii: { number }): Vector3?
	local placementRadius = self:_getPlacementRadiusForZone(zoneName)
	if placementRadius <= 0 then
		for _ = 1, SPAWN_POSITION_RETRY_LIMIT do
			local halfWidth = math.max(0, (spawnPart.Size.X / 2) - foodRadius)
			local halfDepth = math.max(0, (spawnPart.Size.Z / 2) - foodRadius)
			local localX = (math.random() * 2 - 1) * halfWidth
			local localZ = (math.random() * 2 - 1) * halfDepth
			local candidate = spawnPart.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
			if self:_isSpawnPositionValid(candidate, foodRadius, batchPositions, batchRadii) then
				return candidate
			end
		end
		return nil
	end

	for _ = 1, SPAWN_POSITION_RETRY_LIMIT do
		local angle = math.random() * math.pi * 2
		local distance = math.sqrt(math.random()) * placementRadius
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local candidate = spawnPart.Position + offset
		if self:_isSpawnPositionValid(candidate, foodRadius, batchPositions, batchRadii) then
			return candidate
		end
	end

	return nil
end

function FoodService:_spawnSingleFoodOnSpawn(mapModel: Model, foodContainer: Folder, spawnPart: BasePart, zoneName: string, batchPositions: { Vector3 }?, batchRadii: { number }?): boolean
	local foodType = self:_pickWeightedType(zoneName)
	if not foodType then
		return false
	end
	local foodRule = FoodConfig.Foods[foodType]
	local template = self._foodModels[foodType]
	if not (foodRule and template) then
		return false
	end

	local activeBatchPositions = batchPositions or {}
	local activeBatchRadii = batchRadii or {}
	local foodRadius = self:_getFoodPlacementRadius(template)
	local spawnPos = self:_buildSpawnPosition(spawnPart, zoneName, foodRadius, activeBatchPositions, activeBatchRadii)
	if not spawnPos then
		warn(string.format("[FoodService] Unable to find valid %s food position for %s", zoneName, spawnPart:GetFullName()))
		return false
	end

	local clone = spawnFood(template, spawnPart)
	if not clone then
		return false
	end
	clone.Name = foodType
	clone.Parent = foodContainer
	local hitbox = resolveFoodHitbox(clone)
	if not hitbox then
		clone:Destroy()
		return false
	end
	local surfaceSpawnPos = pivotFoodToAnchorSurface(clone, spawnPart, spawnPos)
	if not surfaceSpawnPos then
		clone:Destroy()
		return false
	end
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
	clone:SetAttribute("FoodZone", zoneName)
	if entry.MaxHP > 0 then
		self:_attachFoodUI(entry, hitbox)
	end
	self:_publishFoodHp(entry)
	self._foodEntries[clone] = entry
	self._foodById[entry.Id] = entry
	self._foodByInstance[clone] = entry
	self:_addEntryToGrid(entry)
	table.insert(activeBatchPositions, surfaceSpawnPos)
	table.insert(activeBatchRadii, foodRadius)
	return true
end

function FoodService:_spawnFoodBatchOnSpawn(mapModel: Model, foodContainer: Folder, spawnPart: BasePart, zoneName: string)
	local spawnCount = self:_getSpawnCountForZone(zoneName)
	if spawnCount <= 0 then
		return
	end

	local batchPositions = {}
	local batchRadii = {}
	local spawned = 0
	for _ = 1, spawnCount do
		if self:_spawnSingleFoodOnSpawn(mapModel, foodContainer, spawnPart, zoneName, batchPositions, batchRadii) then
			spawned += 1
		end
	end

	if spawned < spawnCount then
		warn(string.format(
			"[FoodService] Spawned %d/%d food for %s; valid non-overlapping positions were exhausted",
			spawned,
			spawnCount,
			spawnPart:GetFullName()
		))
	end
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
					self:_spawnFoodBatchOnSpawn(mapModel, foodContainer, spawnPart, zoneFolder.Name)
				end
			end
		end
	end
end

function FoodService:_rewardFoodKill(entry: any)
	local player = entry.LastHitBy
	local rule = FoodConfig.Foods[entry.FoodType]
	if not (player and rule) then
		return
	end
	self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
	if rule.DiamondRate > 0 and rule.DiamondAmount > 0 and math.random() <= rule.DiamondRate then
		local dataService = getService(self._context, "PlayerDataService")
		if dataService and typeof(dataService.GrantReward) == "function" then
			dataService:GrantReward(player, { Diamonds = rule.DiamondAmount }, "FoodConsumed")
			local stateService = getService(self._context, "PlayerStateService")
			if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
				stateService:RecalculateDerivedStats(player, false)
			end
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
						self:_spawnSingleFoodOnSpawn(mapModel, foodContainer, entry.SpawnPart, entry.ZoneName)
					end
				end
			end
		end)
	end
end

function FoodService:_rejectFoodHit(player: Player, reason: string, payload: any, details: { [string]: any }?)
	if not DEBUG_FOOD_HIT_REJECTS then
		return
	end
	local foodId = if type(payload) == "table" then payload.foodId else nil
	local fields = {
		`player={player.Name}`,
		`reason={reason}`,
		`foodId={tostring(foodId)}`,
	}
	if details then
		for key, value in pairs(details) do
			table.insert(fields, `{key}={tostring(value)}`)
		end
	end
	warn(`[FoodHitRejected] {table.concat(fields, " ")}`)
end

function FoodService:_validateFoodHit(player: Player, entry: any, payload: any): (boolean, string?, { [string]: any }?, CollisionValidation.ValidationResult?)
	if not entry then
		return false, "missing_or_already_consumed_target", nil, nil
	end
	if not (entry.IsActive and not entry.IsConsumed and entry.Instance and entry.Instance.Parent) then
		return false, "missing_or_already_consumed_target", {
			isActive = entry.IsActive,
			isConsumed = entry.IsConsumed,
		}, nil
	end
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule then
		return false, "missing_food_rule", { foodType = entry.FoodType }, nil
	end
	local hitbox = entry.Instance:FindFirstChild("Hitbox")
	if not (hitbox and hitbox:IsA("BasePart")) then
		return false, "missing_or_already_consumed_target", { missingHitbox = true }, nil
	end
	local validation = CollisionValidation.ValidateAttackerTarget(self._context, player, {
		Kind = "Food",
		Player = nil,
		Part = hitbox,
		RadiusPadding = FOOD_HIT_RADIUS_PADDING,
		RequiresLaunching = (not rule.Touch) and entry.MaxHP > 0,
		AllowTouchStates = rule.Touch == true,
	}, payload)
	if not validation.Ok then
		return false, validation.Reason, validation.Details, validation
	end
	return true, nil, nil, validation
end

function FoodService:_resolveFoodCollisionVelocity(root: BasePart, hitbox: BasePart, payload: any, rule: any): Vector3
	local rootVelocity = CombatCollision.FlattenXZ(root.AssemblyLinearVelocity)
	local reportedVelocity = (payload and typeof(payload.velocity) == "Vector3")
		and CombatCollision.FlattenXZ(payload.velocity)
		or Vector3.zero
	local velocity = if rootVelocity.Magnitude >= reportedVelocity.Magnitude then rootVelocity else reportedVelocity
	if rule.Touch then
		return velocity
	end
	local normal = self:_computeCollisionNormal(root.Position, hitbox.Position, velocity)
	return CombatCollision.ResolveAttackerBounce(velocity, Vector3.zero, normal).AttackerVelocity
end


function FoodService:ApplyDamageToFood(foodOrEntry: any, amount: number, player: Player?): boolean
	local entry = if type(foodOrEntry) == "table" then foodOrEntry else self._foodByInstance[foodOrEntry]
	local rule = entry and FoodConfig.Foods[entry.FoodType]
	local stateService = getService(self._context, "PlayerStateService")
	if (stateService and stateService:IsHuman(player)) or not (entry and rule and player) or entry.CurrentHP <= 0 or entry.IsConsumed then
		return false
	end
	local damage = math.max(0, amount)
	if damage <= 0 then
		return false
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
	return true
end

function FoodService:_applyLauncherDamage(entry: any, player: Player, velocity: number)
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule or entry.CurrentHP <= 0 then
		return
	end
	local stateService = getService(self._context, "PlayerStateService")
	local damagePipeline = getService(self._context, "DamagePipelineService")
	local attackerState = stateService and stateService:GetState(player) or {}
	local damage = if damagePipeline and typeof(damagePipeline.ComputeCollisionDamage) == "function"
		then damagePipeline:ComputeCollisionDamage(attackerState, velocity, {
			SourceType = "FoodLauncherCollision",
			InitialImpactSpeed = velocity,
			AttackerAbsoluteSpeed = velocity,
			LaunchEnergy = velocity,
			LauncherMaxSpeed = attackerState and attackerState.LaunchSpeed or PhysicsConfig.Launch.SpeedMin,
			CollisionCount = 0,
			AngleFactor = 1,
		})
		else 0
	self:ApplyDamageToFood(entry, damage, player)
end

function FoodService:_computeCollisionNormal(playerPosition: Vector3, foodPosition: Vector3, velocity: Vector3): Vector3
	local planarVelocity = CombatCollision.FlattenXZ(velocity)
	local fallbackNormal = sanitizeUnit(CombatCollision.FlattenXZ(-velocity), Vector3.new(0, 0, -1))
	local normal = sanitizeUnit(playerPosition - foodPosition, fallbackNormal)
	if planarVelocity.Magnitude > MIN_SPEED_EPSILON and planarVelocity:Dot(normal) < 0 then
		normal = -normal
	end
	return normal
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
		local rateLimiter = getService(self._context, "RateLimiter")
		if rateLimiter and not rateLimiter:Allow(RemoteContracts.Names.ReportFoodHit, tostring(player.UserId), 1, now) then
			self:_rejectFoodHit(player, "rate_limited", payload, nil)
			return
		end
		local entry = (type(payload) == "table") and self._foodById[payload.foodId] or nil
		local dedupeService = getService(self._context, "HitCooldownDedupe")

		if type(payload) ~= "table" then
			self:_rejectFoodHit(player, "invalid_payload", payload, nil)
			return
		end
		if entry and entry.Id and dedupeService and not dedupeService:TryAcquire("FoodHit", `{player.UserId}:{entry.Id}`, PhysicsConfig.Collision.Cooldown, now) then
			self:_rejectFoodHit(player, "same_target_dedupe", payload, { foodId = entry.Id })
			return
		end

		local valid, reason, details = self:_validateFoodHit(player, entry, payload)
		if not valid then
			self:_rejectFoodHit(player, reason or "validation_failed", payload, details)
			if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
				feedbackRemote:FireClient(player, {
					EventType = "FoodHitRejected",
					Payload = {
						FoodId = payload.foodId,
						Reason = reason,
						ServerResync = true,
					},
				})
			end
			return
		end

		local rule = FoodConfig.Foods[entry.FoodType]
		if not rule then
			self:_rejectFoodHit(player, "missing_food_rule", payload, { foodType = entry.FoodType })
			return
		end
		if rule.Touch then
			self:_consumeFood(entry, player)
		elseif entry.MaxHP > 0 then
			local playerService = getService(self._context, "PlayerService")
			local root = playerService and playerService:GetRoot(player)
			local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
			if not (root and hitbox and hitbox:IsA("BasePart")) then
				self:_rejectFoodHit(player, "missing_player_or_target_root", payload, nil)
				return
			end
			local serverHorizontalSpeed = flattenXZ(root.AssemblyLinearVelocity).Magnitude
			local clientObservedSpeed = if typeof(payload.observedSpeed) == "number" then payload.observedSpeed else 0
			local horizontalSpeed = math.max(serverHorizontalSpeed, clientObservedSpeed)

			self._context.EventBus:Fire("CollisionDetected", "Food", player, entry.Instance, { FoodId = entry.Id })
			self:_applyLauncherDamage(entry, player, horizontalSpeed)
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
