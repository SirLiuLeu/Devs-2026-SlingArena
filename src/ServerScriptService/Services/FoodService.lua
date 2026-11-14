--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)
local CollisionValidation = require(script.Parent.Helpers.CollisionValidation)

local FOOD_UI_TEMPLATE_PATH = { "Assets", "UI", "FoodWorldUI" }
local FOOD_HIT_RADIUS_PADDING = PhysicsConfig.Collision.Range
local NORMAL_EPSILON = 1e-5
local MIN_SPEED_EPSILON = 1e-3
local GRID_CELL_SIZE = 48
local SPAWN_GRID_CONFIG = FoodConfig.SpawnGrid or {}
local SPAWN_RETRY_DELAY_SECONDS = math.max(tonumber(SPAWN_GRID_CONFIG.BlockedRetryInterval) or 2, 0.25)
local SPAWN_SCHEDULER_INTERVAL_SECONDS = math.max(tonumber(SPAWN_GRID_CONFIG.SchedulerInterval) or 0.1, 0.05)
local MAX_SPAWN_PER_SCHEDULER_TICK = math.max(1, math.floor(tonumber(SPAWN_GRID_CONFIG.MaxSpawnPerTick) or 12))
local MAX_POOLED_FOOD_PER_TYPE = math.max(0, math.floor(tonumber(SPAWN_GRID_CONFIG.MaxPooledPerType) or 12))
local MAX_CANDIDATE_REGION_CHECKS_PER_TARGET = math.max(1, math.floor(tonumber(SPAWN_GRID_CONFIG.MaxCandidateChecksPerSlotTarget) or 8))
local VALIDATION_EPSILON = PhysicsConfig.Collision.ValidationTolerance
local DEBUG_FOOD_HIT_REJECTS = false

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)

local function getFoodWorldPosition(food: Instance?): Vector3?
	if not food then return nil end
	local hitbox = food:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then return hitbox.Position end
	if food:IsA("BasePart") then return food.Position end
	if food:IsA("Model") then return food:GetPivot().Position end
	return nil
end

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
	local hitbox = foodModel:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		if foodModel.PrimaryPart ~= hitbox then
			foodModel.PrimaryPart = hitbox
		end
		return hitbox
	end

	local primaryPart = foodModel.PrimaryPart
	return if primaryPart and primaryPart:IsA("BasePart") then primaryPart else nil
end

local function getAnchorSurfacePosition(foodModel: Model, spawnAnchor: BasePart, horizontalPosition: Vector3?, groundRaycastParams: RaycastParams?, footprintSize: Vector2?, ignoreSpawnBounds: boolean?): Vector3?
	local hitbox = resolveFoodHitbox(foodModel)
	if not hitbox or not groundRaycastParams then return nil end
	local footprintX = if footprintSize then footprintSize.X else hitbox.Size.X
	local footprintZ = if footprintSize then footprintSize.Y else hitbox.Size.Z
	local xzPosition = horizontalPosition
	if not xzPosition then
		local radius = math.max(footprintX, footprintZ) * 0.5
		local halfWidth = math.max(spawnAnchor.Size.X * 0.5 - radius, 0)
		local halfDepth = math.max(spawnAnchor.Size.Z * 0.5 - radius, 0)
		local localX = (math.random() * 2 - 1) * halfWidth
		local localZ = (math.random() * 2 - 1) * halfDepth
		xzPosition = spawnAnchor.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
	end

	local localPosition = spawnAnchor.CFrame:PointToObjectSpace(xzPosition)
	local halfWidth = spawnAnchor.Size.X * 0.5 - footprintX * 0.5
	local halfDepth = spawnAnchor.Size.Z * 0.5 - footprintZ * 0.5
	if not ignoreSpawnBounds and (halfWidth < 0 or halfDepth < 0
		or math.abs(localPosition.X) > halfWidth or math.abs(localPosition.Z) > halfDepth) then
		return nil
	end

	local spawnPlaneY = spawnAnchor.Position.Y + spawnAnchor.Size.Y * 0.5
	local startY = math.max(spawnPlaneY, xzPosition.Y) + math.max(1, FoodConfig.GroundRaycastStartHeight or 50)
	local direction = Vector3.new(0, -math.max(1, FoodConfig.GroundRaycastDepth or 300), 0)
	local minNormalY = math.clamp(tonumber(FoodConfig.GroundMinNormalY) or 0.9, 0, 1)
	local maxVerticalOffset = math.max(0, tonumber(FoodConfig.GroundMaxVerticalOffset) or 4)
	local maxCornerHeightDifference = math.max(0, tonumber(FoodConfig.GroundMaxCornerHeightDifference) or 1.5)

	local center = Workspace:Raycast(Vector3.new(xzPosition.X, startY, xzPosition.Z), direction, groundRaycastParams)
	if not center or center.Normal.Y < minNormalY
		or math.abs(center.Position.Y - spawnPlaneY) > maxVerticalOffset then
		return nil
	end

	local halfX, halfZ = footprintX * 0.5, footprintZ * 0.5
	local corners = {
		Vector3.new(-halfX, 0, -halfZ), Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, -halfZ), Vector3.new(halfX, 0, halfZ),
	}
	local minY, maxY = center.Position.Y, center.Position.Y
	for _, offset in ipairs(corners) do
		local result = Workspace:Raycast(Vector3.new(xzPosition.X + offset.X, startY, xzPosition.Z + offset.Z), direction, groundRaycastParams)
		if not result or result.Normal.Y < minNormalY
			or math.abs(result.Position.Y - spawnPlaneY) > maxVerticalOffset then
			return nil
		end
		minY = math.min(minY, result.Position.Y)
		maxY = math.max(maxY, result.Position.Y)
	end
	if maxY - minY > maxCornerHeightDifference then return nil end
	return Vector3.new(xzPosition.X, center.Position.Y + hitbox.Size.Y * 0.5, xzPosition.Z)
end

local function pivotFoodToAnchorSurface(foodModel: Model, targetHitboxPosition: Vector3): boolean
	local hitbox = resolveFoodHitbox(foodModel)
	if not hitbox then return false end
	local pivotToHitbox = foodModel:GetPivot():ToObjectSpace(hitbox.CFrame)
	foodModel:PivotTo(CFrame.new(targetHitboxPosition) * pivotToHitbox:Inverse())
	return true
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
	self._spawnSlotsByPart = {}
	self._spawnSchedulerRunning = false
	self._foodPool = {}
	self._foodSpawnsByZone = {}
	self._foodEntries = {}
	self._foodById = {}
	self._foodGrid = {}
	self._foodByInstance = {}
	self._playerConsumeCooldown = {}
	self._foodHitByLaunchTarget = {}
	self._groundRaycastParamsByMap = {}
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

function FoodService:_getSpawnCountForZone(zoneName: string, spawnPart: BasePart?): number
	local settings = FoodConfig.ZoneSpawnSettings[zoneName]
	if not settings then return 0 end
	local fixedCount = tonumber(settings.ActivePerSpawn)
	if fixedCount and fixedCount > 0 then return math.floor(fixedCount) end
	if settings.AreaBased == true and spawnPart then
		return FoodConfig.GetSpawnCountForArea(spawnPart.Size.X * spawnPart.Size.Z)
	end
	return 0
end



function FoodService:_getFoodPlacementRadius(template: Model): number
	local hitbox = template:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		return math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
	end
	return 0
end

function FoodService:_isSpawnPositionValid(spawnPart: BasePart, candidate: Vector3, foodRadius: number, _batchPositions: { Vector3 }, _batchRadii: { number }, _batchFoodTypes: { string }, foodType: string, ignoreSpawnBounds: boolean?): boolean
	local localCandidate = spawnPart.CFrame:PointToObjectSpace(candidate)
	local foodTemplate = self._foodModels[foodType]
	local hitbox = foodTemplate and resolveFoodHitbox(foodTemplate)
	if hitbox and not ignoreSpawnBounds then
		local halfWidth = spawnPart.Size.X * 0.5 - hitbox.Size.X * 0.5
		local halfDepth = spawnPart.Size.Z * 0.5 - hitbox.Size.Z * 0.5
		if halfWidth < 0 or halfDepth < 0
			or math.abs(localCandidate.X) > halfWidth or math.abs(localCandidate.Z) > halfDepth then
			return false
		end
	end

	for _, entry in ipairs(self:_collectNearbyEntries(candidate)) do
		local otherHitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
		if hitbox and otherHitbox and otherHitbox:IsA("BasePart") then
			local halfOverlapX = (hitbox.Size.X + otherHitbox.Size.X) * 0.5
			local halfOverlapZ = (hitbox.Size.Z + otherHitbox.Size.Z) * 0.5
			local offset = flattenXZ(candidate - otherHitbox.Position)
			if math.abs(offset.X) < halfOverlapX and math.abs(offset.Z) < halfOverlapZ then
				return false
			end
		end
	end

	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	if stateService and playerService then
		for _, player in ipairs(Players:GetPlayers()) do
			local state = stateService:GetState(player)
			if not state or state.LocationState == GameStates.SessionState.Lobby or state.IsAlive ~= true then continue end
			local root = playerService:GetRoot(player)
			if root then
				local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
				local spacing = foodRadius + playerRadius + math.max(0, FoodConfig.MinPlayerSpawnClearance or 0)
				if sqrDistanceXZ(candidate, root.Position) <= spacing * spacing then return false end
			end
		end
	end
	return true
end

function FoodService:_buildLatticeRegions(spawnPart: BasePart, requestedCount: number): { any }
	local regionSizeX = math.max(0.5, tonumber(SPAWN_GRID_CONFIG.RegionSizeX) or 4)
	local regionSizeZ = math.max(0.5, tonumber(SPAWN_GRID_CONFIG.RegionSizeZ) or 4)
	local columns = math.max(1, math.floor(spawnPart.Size.X / regionSizeX))
	local rows = math.max(1, math.floor(spawnPart.Size.Z / regionSizeZ))
	local stepX = spawnPart.Size.X / columns
	local stepZ = spawnPart.Size.Z / rows
	local totalRegions = columns * rows
	local candidateBudget = math.min(
		totalRegions,
		math.max(requestedCount * MAX_CANDIDATE_REGION_CHECKS_PER_TARGET, requestedCount + 8)
	)
	local regions = {}
	local selectedIndices = {}

	-- Sample only the bounded candidate budget rather than allocating/shuffling every grid cell in a large FoodSpawn.
	while #regions < candidateBudget do
		local flatIndex = math.random(1, totalRegions)
		if not selectedIndices[flatIndex] then
			selectedIndices[flatIndex] = true
			local zeroIndex = flatIndex - 1
			local column = math.floor(zeroIndex / rows)
			local row = zeroIndex % rows
			local localX = -spawnPart.Size.X * 0.5 + (column + 0.5) * stepX
			local localZ = -spawnPart.Size.Z * 0.5 + (row + 0.5) * stepZ
			table.insert(regions, {
				SpawnPart = spawnPart,
				ZoneName = nil,
				CenterLocalX = localX,
				CenterLocalZ = localZ,
				SizeX = stepX,
				SizeZ = stepZ,
				IsCenter = false,
				Rarity = nil,
			})
		end
	end
	return regions
end

function FoodService:_buildSpawnSlotsForPart(mapModel: Model, spawnPart: BasePart, zoneName: string): ({ any }, number)
	local targetCount = self:_getSpawnCountForZone(zoneName, spawnPart)
	if targetCount <= 0 then
		return {}, targetCount
	end

	if zoneName == "CenterZones" then
		return {
			{
				MapModel = mapModel,
				SpawnPart = spawnPart,
				ZoneName = zoneName,
				CenterLocalX = 0,
				CenterLocalZ = 0,
				SizeX = 0,
				SizeZ = 0,
				IsCenter = true,
				Rarity = nil,
			}
		}, targetCount
	end

	local candidates = self:_buildLatticeRegions(spawnPart, targetCount)
	local regions = {}
	for index = 1, math.min(#candidates, targetCount) do
		local region = candidates[index]
		region.MapModel = mapModel
		region.ZoneName = zoneName
		table.insert(regions, region)
	end
	return regions, targetCount
end

function FoodService:_assignFoodTypesForZone(zoneName: string, regions: { any })
	if #regions == 0 then
		return
	end

	local weights = FoodConfig.ZoneWeights[zoneName]
	local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local availableRarities = {}
	local totalWeight = 0
	local remainders = {}

	for order, rarity in ipairs(rarityOrder) do
		local weight = tonumber(weights and weights[rarity]) or 0
		local hasAvailableModel = false
		for _, foodType in ipairs(FoodConfig.TypePools[rarity] or {}) do
			if self._foodModels[foodType] and FoodConfig.Foods[foodType] then
				hasAvailableModel = true
				break
			end
		end
		if weight > 0 and hasAvailableModel then
			totalWeight += weight
			table.insert(availableRarities, { Rarity = rarity, Weight = weight, Order = order })
		end
	end

	if totalWeight <= 0 then
		warn(string.format("[FoodService] Zone %s has regions but no configured Food model is available.", zoneName))
		return
	end

	-- Center markers represent independent hand-placed rewards; preserve their configured per-marker odds.
	if zoneName == "CenterZones" then
		for _, region in ipairs(regions) do
			local roll = math.random() * totalWeight
			local cumulativeWeight = 0
			for _, data in ipairs(availableRarities) do
				cumulativeWeight += data.Weight
				if roll <= cumulativeWeight then
					region.Rarity = data.Rarity
					break
				end
			end
		end
		return
	end

	local rarityCounts = {}
	local allocatedCount = 0
	for _, data in ipairs(availableRarities) do
		local exactCount = #regions * data.Weight / totalWeight
		local wholeCount = math.floor(exactCount)
		rarityCounts[data.Rarity] = wholeCount
		allocatedCount += wholeCount
		table.insert(remainders, {
			Rarity = data.Rarity,
			Fraction = exactCount - wholeCount,
			Order = data.Order,
		})
	end

	table.sort(remainders, function(a, b)
		if a.Fraction == b.Fraction then
			return a.Order < b.Order
		end
		return a.Fraction > b.Fraction
	end)

	for index = 1, #regions - allocatedCount do
		local rarity = remainders[index].Rarity
		rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
	end

	local assignedRarities = {}
	for _, rarity in ipairs(rarityOrder) do
		for _ = 1, rarityCounts[rarity] or 0 do
			table.insert(assignedRarities, rarity)
		end
	end
	for index = #assignedRarities, 2, -1 do
		local swapIndex = math.random(1, index)
		assignedRarities[index], assignedRarities[swapIndex] = assignedRarities[swapIndex], assignedRarities[index]
	end

	for index, region in ipairs(regions) do
		region.Rarity = assignedRarities[index]
	end
end

function FoodService:_createFoodSlotForRegion(region: any, foodType: string, subCellX: number?, subCellZ: number?, subCellsX: number?, subCellsZ: number?): any?
	local spawnPart = region.SpawnPart
	local mapModel = region.MapModel
	local template = self._foodModels[foodType]
	local hitbox = template and resolveFoodHitbox(template)
	local raycastParams = mapModel and self._groundRaycastParamsByMap[mapModel]
	if not (template and hitbox and raycastParams) then
		return nil
	end

	local centerLocalX = region.CenterLocalX
	local centerLocalZ = region.CenterLocalZ
	local areaSizeX = region.SizeX
	local areaSizeZ = region.SizeZ
	if subCellX ~= nil and subCellZ ~= nil and subCellsX and subCellsZ then
		areaSizeX = region.SizeX / subCellsX
		areaSizeZ = region.SizeZ / subCellsZ
		centerLocalX += -region.SizeX * 0.5 + (subCellX + 0.5) * areaSizeX
		centerLocalZ += -region.SizeZ * 0.5 + (subCellZ + 0.5) * areaSizeZ
	end

	if not region.IsCenter and (hitbox.Size.X > areaSizeX or hitbox.Size.Z > areaSizeZ) then
		return nil
	end

	local maxOffsetX = if region.IsCenter then 0 else math.max(0, (areaSizeX - hitbox.Size.X) * 0.5)
	local maxOffsetZ = if region.IsCenter then 0 else math.max(0, (areaSizeZ - hitbox.Size.Z) * 0.5)
	local candidate: Vector3? = nil
	local surfacePosition: Vector3? = nil
	for _ = 1, 4 do
		local localX = centerLocalX + (math.random() * 2 - 1) * maxOffsetX
		local localZ = centerLocalZ + (math.random() * 2 - 1) * maxOffsetZ
		candidate = spawnPart.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
		surfacePosition = getAnchorSurfacePosition(
			template,
			spawnPart,
			candidate,
			raycastParams,
			Vector2.new(hitbox.Size.X, hitbox.Size.Z),
			region.IsCenter
		)
		if surfacePosition then
			break
		end
	end
	if not surfacePosition then
		return nil
	end

	return {
		MapModel = mapModel,
		SpawnPart = spawnPart,
		ZoneName = region.ZoneName,
		Position = surfacePosition,
		GroundY = surfacePosition.Y - hitbox.Size.Y * 0.5,
		FoodType = foodType,
		State = "Pending",
		NextAttemptAt = 0,
		BlockedAttempts = 0,
		WarnedBlocked = false,
		Entry = nil,
		Region = region,
	}
end

function FoodService:_buildFoodSlotsForRegion(region: any): ({ any }, number)
	local slots = {}
	local rarity = region.Rarity
	if not rarity then
		return slots, 0
	end

	local pool = {}
	for _, foodType in ipairs(FoodConfig.TypePools[rarity] or {}) do
		local template = self._foodModels[foodType]
		local hitbox = template and resolveFoodHitbox(template)
		if hitbox then
			table.insert(pool, foodType)
		end
	end
	if #pool == 0 then
		return slots, 0
	end

	local subdivisionsX = if rarity == "Common" and not region.IsCenter
		then math.max(1, math.floor(tonumber(SPAWN_GRID_CONFIG.CommonSubdivisionsX) or 2))
		else 1
	local subdivisionsZ = if rarity == "Common" and not region.IsCenter
		then math.max(1, math.floor(tonumber(SPAWN_GRID_CONFIG.CommonSubdivisionsZ) or 2))
		else 1

	for subX = 0, subdivisionsX - 1 do
		for subZ = 0, subdivisionsZ - 1 do
			local cellSizeX = region.SizeX / subdivisionsX
			local cellSizeZ = region.SizeZ / subdivisionsZ
			local candidateTypes = {}
			for _, foodType in ipairs(pool) do
				local template = self._foodModels[foodType]
				local hitbox = template and resolveFoodHitbox(template)
				if region.IsCenter or (hitbox and hitbox.Size.X <= cellSizeX and hitbox.Size.Z <= cellSizeZ) then
					table.insert(candidateTypes, foodType)
				end
			end

			if #candidateTypes == 0 and rarity == "Common" and not region.IsCenter then
				local fallbackTypes = {}
				for _, foodType in ipairs(pool) do
					local template = self._foodModels[foodType]
					local hitbox = template and resolveFoodHitbox(template)
					if hitbox and hitbox.Size.X <= region.SizeX and hitbox.Size.Z <= region.SizeZ then
						table.insert(fallbackTypes, foodType)
					end
				end
				if #fallbackTypes > 0 then
					local selectedType = fallbackTypes[math.random(1, #fallbackTypes)]
					local slot = self:_createFoodSlotForRegion(region, selectedType)
					if slot then table.insert(slots, slot) end
					return slots, 1
				end
				return slots, 1
			end

			if #candidateTypes > 0 then
				local selectedType = candidateTypes[math.random(1, #candidateTypes)]
				local slot = self:_createFoodSlotForRegion(region, selectedType, subX, subZ, subdivisionsX, subdivisionsZ)
				if slot then table.insert(slots, slot) end
			end
		end
	end

	local expectedCount = if rarity == "Common" and not region.IsCenter then subdivisionsX * subdivisionsZ else 1
	return slots, expectedCount
end

function FoodService:_acquireFoodModel(foodType: string): Model?
	local pool = self._foodPool[foodType]
	local model = if pool and #pool > 0 then table.remove(pool) else nil
	if not model then
		local template = self._foodModels[foodType]
		model = template and template:Clone() or nil
	end
	if not model then
		return nil
	end

	model.Parent = nil
	local oldUi = model:FindFirstChild("FoodWorldUI")
	if oldUi then
		oldUi:Destroy()
	end
	model:SetAttribute("FoodId", nil)
	model:SetAttribute("FoodRarity", nil)
	model:SetAttribute("FoodZone", nil)
	model:SetAttribute("FoodSpawnPart", nil)
	model:SetAttribute("FoodSlotIndex", nil)
	model:SetAttribute("FoodHP", nil)
	model:SetAttribute("FoodMaxHP", nil)
	return model
end

function FoodService:_returnFoodModelToPool(foodType: string, model: Model)
	local oldUi = model:FindFirstChild("FoodWorldUI")
	if oldUi then
		oldUi:Destroy()
	end
	model:SetAttribute("FoodId", nil)
	model:SetAttribute("FoodRarity", nil)
	model:SetAttribute("FoodZone", nil)
	model:SetAttribute("FoodSpawnPart", nil)
	model:SetAttribute("FoodSlotIndex", nil)
	model:SetAttribute("FoodHP", nil)
	model:SetAttribute("FoodMaxHP", nil)
	model.Parent = nil

	local pool = self._foodPool[foodType]
	if not pool then
		pool = {}
		self._foodPool[foodType] = pool
	end
	if #pool >= MAX_POOLED_FOOD_PER_TYPE then
		model:Destroy()
		return
	end
	table.insert(pool, model)
end

function FoodService:_trySpawnSlot(slot: any): boolean
	if slot.State ~= "Pending" then
		return false
	end

	local spawnPart = slot.SpawnPart
	local record = spawnPart and self._spawnSlotsByPart[spawnPart]
	if not (record and record.MapModel and record.MapModel.Parent and record.FoodContainer and record.FoodContainer.Parent and spawnPart.Parent) then
		slot.State = "Disabled"
		return false
	end

	local foodType = slot.FoodType
	local rule = foodType and FoodConfig.Foods[foodType]
	local template = foodType and self._foodModels[foodType]
	local templateHitbox = template and resolveFoodHitbox(template)
	if not (foodType and rule and template and templateHitbox) then
		slot.State = "Disabled"
		warn(string.format("[FoodService] Disabled spawn slot because Food model/config is unavailable: %s", tostring(foodType)))
		return false
	end

	local foodRadius = self:_getFoodPlacementRadius(template)
	local candidate = Vector3.new(
		slot.Position.X,
		slot.GroundY + templateHitbox.Size.Y * 0.5,
		slot.Position.Z
	)
	if not self:_isSpawnPositionValid(
		spawnPart,
		candidate,
		foodRadius,
		{},
		{},
		{},
		foodType,
		slot.Region ~= nil and slot.Region.IsCenter == true
	) then
		slot.BlockedAttempts += 1
		slot.NextAttemptAt = os.clock() + SPAWN_RETRY_DELAY_SECONDS
		if slot.BlockedAttempts >= 5 and not slot.WarnedBlocked then
			slot.WarnedBlocked = true
			warn(string.format(
				"[FoodService] Spawn slot remains temporarily blocked; it will retry without rebuilding the grid. zone=%s spawn=%s slot=%d food=%s",
				slot.ZoneName,
				spawnPart:GetFullName(),
				slot.Index or 0,
				foodType
			))
		end
		return false
	end

	local model = self:_acquireFoodModel(foodType)
	if not model then
		slot.State = "Disabled"
		warn(string.format("[FoodService] Could not acquire Food model for spawn slot: %s", foodType))
		return false
	end
	model.Name = foodType
	anchorFoodModel(model)
	if not pivotFoodToAnchorSurface(model, candidate) then
		self:_returnFoodModelToPool(foodType, model)
		slot.BlockedAttempts += 1
		slot.NextAttemptAt = os.clock() + SPAWN_RETRY_DELAY_SECONDS
		return false
	end

	local hitbox = resolveFoodHitbox(model)
	if not hitbox then
		self:_returnFoodModelToPool(foodType, model)
		slot.State = "Disabled"
		warn(string.format("[FoodService] Food model lost its Hitbox during spawn: %s", foodType))
		return false
	end

	local entry = {
		Id = game:GetService("HttpService"):GenerateGUID(false),
		Instance = model,
		FoodType = foodType,
		SpawnPart = spawnPart,
		ZoneName = slot.ZoneName,
		Slot = slot,
		IsActive = true,
		IsConsumed = false,
		MaxHP = math.max(0, rule.HP),
		CurrentHP = math.max(0, rule.HP),
		LastHitBy = nil,
	}
	model:SetAttribute("FoodId", entry.Id)
	model:SetAttribute("FoodRarity", rule.Type)
	model:SetAttribute("FoodZone", slot.ZoneName)
	model:SetAttribute("FoodSpawnPart", spawnPart:GetFullName())
	model:SetAttribute("FoodSlotIndex", slot.Index)
	model.Parent = record.FoodContainer
	if entry.MaxHP > 0 then
		self:_attachFoodUI(entry, hitbox)
	end
	self:_publishFoodHp(entry)
	self._foodEntries[model] = entry
	self._foodById[entry.Id] = entry
	self._foodByInstance[model] = entry
	self:_addEntryToGrid(entry)

	slot.Entry = entry
	slot.State = "Occupied"
	slot.BlockedAttempts = 0
	slot.WarnedBlocked = false
	return true
end

function FoodService:_startSpawnScheduler()
	if self._spawnSchedulerRunning then
		return
	end
	self._spawnSchedulerRunning = true

	task.spawn(function()
		while self._spawnSchedulerRunning do
			local now = os.clock()
			local processedCount = 0
			local hasPendingSlots = false
			local hasReadyPendingSlots = false
			local earliestPendingAt = nil

			for spawnPart, record in pairs(self._spawnSlotsByPart) do
				if not (spawnPart.Parent and record.MapModel.Parent and record.FoodContainer.Parent) then
					for _, slot in ipairs(record.Slots) do
						slot.State = "Disabled"
						slot.Entry = nil
					end
					self._spawnSlotsByPart[spawnPart] = nil
				else
					for _, slot in ipairs(record.Slots) do
						if slot.State == "Pending" then
							hasPendingSlots = true
							if slot.NextAttemptAt <= now then
								hasReadyPendingSlots = true
								if processedCount < MAX_SPAWN_PER_SCHEDULER_TICK then
									processedCount += 1
									self:_trySpawnSlot(slot)
								end
							else
								earliestPendingAt = if earliestPendingAt then math.min(earliestPendingAt, slot.NextAttemptAt) else slot.NextAttemptAt
							end
						end
					end
				end
				if processedCount >= MAX_SPAWN_PER_SCHEDULER_TICK then
					break
				end
			end

			local waitTime = 1
			if hasReadyPendingSlots then
				waitTime = SPAWN_SCHEDULER_INTERVAL_SECONDS
			elseif hasPendingSlots and earliestPendingAt then
				waitTime = math.clamp(earliestPendingAt - os.clock(), SPAWN_SCHEDULER_INTERVAL_SECONDS, 1)
			end
			task.wait(waitTime)
		end
	end)
end

function FoodService:ClearMapFood(mapModel: Model)
	self._groundRaycastParamsByMap[mapModel] = nil

	for spawnPart, record in pairs(self._spawnSlotsByPart) do
		if spawnPart and spawnPart:IsDescendantOf(mapModel) then
			for _, slot in ipairs(record.Slots) do
				slot.State = "Disabled"
				slot.Entry = nil
			end
			self._spawnSlotsByPart[spawnPart] = nil
		end
	end

	for instance, entry in pairs(self._foodEntries) do
		if instance and instance.Parent and instance:IsDescendantOf(mapModel) then
			entry.IsActive = false
			self:_removeEntryFromGrid(entry)
			self._foodEntries[instance] = nil
			if entry.Id then
				self._foodById[entry.Id] = nil
			end
			self._foodByInstance[instance] = nil
			if entry.Slot then
				entry.Slot.Entry = nil
				entry.Slot.State = "Disabled"
			end
			self:_returnFoodModelToPool(entry.FoodType, instance)
		end
	end
end
function FoodService:_buildGroundRaycastParams(mapModel: Model): RaycastParams?
	local tagName = FoodConfig.GroundSurfaceTag or "Collision_Ground"
	local included = {}
	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		if (instance:IsA("BasePart") or instance:IsA("Model")) and instance:IsDescendantOf(mapModel) then
			table.insert(included, instance)
		end
	end
	if #included == 0 then
		warn(string.format("[FoodService] Map %s has no floor tagged %s; Food spawning is skipped for this map.", mapModel:GetFullName(), tagName))
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = included
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return params
end

function FoodService:SpawnFoodForMap(mapModel: Model)
	self._groundRaycastParamsByMap[mapModel] = self:_buildGroundRaycastParams(mapModel)
	if not self._groundRaycastParamsByMap[mapModel] then return end

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

	local zoneFolders = {}
	for _, child in ipairs(foodSpawns:GetChildren()) do
		if child:IsA("Folder") and FoodConfig.ZoneWeights[child.Name] then
			table.insert(zoneFolders, child)
		end
	end
	table.sort(zoneFolders, function(a, b)
		return a.Name < b.Name
	end)

	for _, zoneFolder in ipairs(zoneFolders) do
		local spawnParts = {}
		for _, child in ipairs(zoneFolder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(spawnParts, child)
			end
		end
		table.sort(spawnParts, function(a, b)
			return a.Name < b.Name
		end)

		local zoneRegions = {}
		local targetRegionCount = 0
		for _, spawnPart in ipairs(spawnParts) do
			local regions, targetCount = self:_buildSpawnSlotsForPart(mapModel, spawnPart, zoneFolder.Name)
			targetRegionCount += targetCount
			self._spawnSlotsByPart[spawnPart] = {
				MapModel = mapModel,
				FoodContainer = foodContainer,
				SpawnPart = spawnPart,
				ZoneName = zoneFolder.Name,
				Regions = regions,
				Slots = {},
			}
			for _, region in ipairs(regions) do
				table.insert(zoneRegions, region)
			end
		end

		self:_assignFoodTypesForZone(zoneFolder.Name, zoneRegions)

		local regionRarityCounts = {}
		local foodRarityCounts = {}
		local expectedFoodSlotCount = 0
		local actualFoodSlotCount = 0
		for _, region in ipairs(zoneRegions) do
			local rarity = region.Rarity
			if rarity then
				regionRarityCounts[rarity] = (regionRarityCounts[rarity] or 0) + 1
				local regionSlots, regionExpectedCount = self:_buildFoodSlotsForRegion(region)
				expectedFoodSlotCount += regionExpectedCount
				local record = self._spawnSlotsByPart[region.SpawnPart]
				if record then
					for _, slot in ipairs(regionSlots) do
						slot.Index = #record.Slots + 1
						table.insert(record.Slots, slot)
						actualFoodSlotCount += 1
						local rule = FoodConfig.Foods[slot.FoodType]
						if rule then
							foodRarityCounts[rule.Type] = (foodRarityCounts[rule.Type] or 0) + 1
						end
					end
				end

			end
		end

		local regionSummary = {}
		local foodSummary = {}
		for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
			local regionCount = regionRarityCounts[rarity] or 0
			local foodCount = foodRarityCounts[rarity] or 0
			if regionCount > 0 then
				table.insert(regionSummary, string.format("%s:%d", rarity, regionCount))
			end
			if foodCount > 0 then
				table.insert(foodSummary, string.format("%s:%d", rarity, foodCount))
			end
		end
		print(string.format(
			"[FoodService] Food regions prepared. map=%s zone=%s regions=%d targetRegions=%d foodSlots=%d expectedFoodSlots=%d regionRarity=%s foodRarity=%s",
			mapModel.Name,
			zoneFolder.Name,
			#zoneRegions,
			targetRegionCount,
			actualFoodSlotCount,
			expectedFoodSlotCount,
			table.concat(regionSummary, ","),
			table.concat(foodSummary, ",")
		))

		if #zoneRegions < targetRegionCount or actualFoodSlotCount < expectedFoodSlotCount then
			warn(string.format(
				"[FoodService] Food region capacity below configured target. map=%s zone=%s validRegions=%d targetRegions=%d validFoodSlots=%d expectedFoodSlots=%d",
				mapModel.Name,
				zoneFolder.Name,
				#zoneRegions,
				targetRegionCount,
				actualFoodSlotCount,
				expectedFoodSlotCount
			))
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
	-- Touch foods are counted by _consumeFood. This branch handles only
	-- hit-to-destroy food so bomb area damage cannot count a Touch food twice.
	if not rule.Touch then
		self._context.EventBus:Fire("DailyQuestFoodCollected", player, entry.FoodType, rule.Type)
	end

	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local reward = { Diamonds = 0, Items = {} }
	local hasReward = false

	if rule.Type == "Legendary" then
		table.insert(reward.Items, { Id = "gift_box", Quantity = 1 })
		hasReward = true
	end

	-- LuckBoosted affects only this server-side roll; it never changes the diamond amount.
	local diamondRate = rule.DiamondRate
	local luckFlag = stateService and stateService:GetFlag(player, "LuckBoosted")
	local luckPercent = luckFlag and luckFlag.Data and tonumber(luckFlag.Data.DiamondDropChanceBonusPercent) or 0
	diamondRate = math.clamp(diamondRate * (1 + math.max(0, luckPercent) / 100), 0, 1)
	if diamondRate > 0 and rule.DiamondAmount > 0 and math.random() <= diamondRate then
		reward.Diamonds = rule.DiamondAmount
		hasReward = true
	end

	if hasReward and dataService and typeof(dataService.GrantReward) == "function" then
		local reason = if rule.Type == "Legendary" then "LegendaryFoodLastHit" else "FoodConsumed"
		dataService:GrantReward(player, reward, reason)
		if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
			stateService:RecalculateDerivedStats(player, false)
		end
		local itemService = ServiceResolver.Get(self._context, "ItemService")
		if itemService and typeof(itemService.PublishInventory) == "function" then
			itemService:PublishInventory(player)
		end
	elseif hasReward and rule.Type == "Legendary" then
		warn("[FoodService] PlayerDataService unavailable; Legendary Gift Box reward was not granted.")
	end
end

function FoodService:_getActiveFoodCountForSpawn(spawnPart: BasePart): number
	local count = 0
	for _, entry in pairs(self._foodEntries) do
		if entry.IsActive and not entry.IsConsumed and entry.SpawnPart == spawnPart then
			count += 1
		end
	end
	return count
end

function FoodService:_consumeFood(entry: any, player: Player)
	if not entry.IsActive or entry.IsConsumed then
		return
	end
	local soundPosition = getFoodWorldPosition(entry.Instance)
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
		self:_returnFoodModelToPool(entry.FoodType, instance)
	end
	local rule = FoodConfig.Foods[entry.FoodType]
	if rule then
		if rule.Touch and rule.Type == "Common" and soundPosition then
			SoundManager.Play("SFX_Food_Consume", soundPosition)
		end
		self._context.EventBus:Fire("CollisionDetected", "Food", player, nil, {})
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		if rule.Touch then
			self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
			self._context.EventBus:Fire("DailyQuestFoodCollected", player, entry.FoodType, rule.Type)
		end
		if stateService and rule.HealHP > 0 then
			stateService:Heal(player, rule.HealHP)
			stateService:PublishState(player)
		end
		local slot = entry.Slot
		if slot then
			slot.Entry = nil
			slot.State = "Pending"
			slot.NextAttemptAt = os.clock() + math.max(0, tonumber(rule.RespawnTime) or SPAWN_RETRY_DELAY_SECONDS)
			slot.BlockedAttempts = 0
			slot.WarnedBlocked = false
		end
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


function FoodService:ApplyDamageToFood(foodOrEntry: any, amount: number, player: Player?, shouldPlayHitSound: boolean?, allowHumanAttacker: boolean?): boolean
	local entry = if type(foodOrEntry) == "table" then foodOrEntry else self._foodByInstance[foodOrEntry]
	local rule = entry and FoodConfig.Foods[entry.FoodType]
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if (stateService and stateService:IsHuman(player) and allowHumanAttacker ~= true) or not (entry and rule and player) or entry.CurrentHP <= 0 or entry.IsConsumed then
		return false
	end
	local damage = math.max(0, amount)
	if damage <= 0 then
		return false
	end
	local before = entry.CurrentHP
	entry.LastHitBy = player
	entry.CurrentHP = math.max(0, entry.CurrentHP - damage)
	local soundPosition = getFoodWorldPosition(entry.Instance)
	if soundPosition and entry.CurrentHP <= 0 then
		SoundManager.Play("SFX_Food_Destroy", soundPosition)
	elseif soundPosition and shouldPlayHitSound ~= false then
		SoundManager.Play("SFX_Food_Hit", soundPosition)
	end
	local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	if hitbox and hitbox:IsA("BasePart") and playerService and entry.CurrentHP ~= before then
		playerService:ShowFloatingText(hitbox, "Damage", before - entry.CurrentHP)
	end
	self:_publishFoodHp(entry)
	if entry.CurrentHP <= 0 then
		self:_rewardFoodKill(entry)
		self:_consumeFood(entry, player)
	end
	return true
end

-- Bomb area damage is resolved by FoodService so LastHitBy, food rewards,
-- respawn scheduling, and FoodConsumed events remain owned by this service.
function FoodService:ApplyAreaDamageToFood(center: Vector3, radius: number, amount: number, player: Player, maxDamageFalloffPercent: number?): number
	if typeof(center) ~= "Vector3" or not player or radius < 0 or amount <= 0 then
		return 0
	end

	local falloffPercent = math.clamp(tonumber(maxDamageFalloffPercent) or 0, 0, 100) / 100
	local candidates = {}
	for _, entry in pairs(self._foodEntries) do
		if entry and entry.IsActive and not entry.IsConsumed and entry.Instance and entry.Instance.Parent then
			local position = getFoodWorldPosition(entry.Instance)
			local distance = if position then (position - center).Magnitude else math.huge
			if position and distance <= radius then
				table.insert(candidates, { Entry = entry, Distance = distance })
			end
		end
	end

	local damagedCount = 0
	for _, candidate in ipairs(candidates) do
		local distanceRatio = if radius > 0 then math.clamp(candidate.Distance / radius, 0, 1) else 0
		local scaledDamage = amount * (1 - falloffPercent * distanceRatio)
		if self:ApplyDamageToFood(candidate.Entry, scaledDamage, player, false, true) then
			damagedCount += 1
		end
	end
	return damagedCount
end

function FoodService:_applyLauncherDamage(entry: any, player: Player, velocity: number)
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule or entry.CurrentHP <= 0 then
		return
	end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local damagePipeline = ServiceResolver.Get(self._context, "DamagePipelineService")
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
	self:_startSpawnScheduler()
	local remote = self._context.Remotes:FindFirstChild("ReportFoodHit")
	local feedbackRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		local now = os.clock()
		local rateLimiter = ServiceResolver.Get(self._context, "RateLimiter")
		if rateLimiter and not rateLimiter:Allow(RemoteContracts.Names.ReportFoodHit, tostring(player.UserId), 1, now) then
			self:_rejectFoodHit(player, "rate_limited", payload, nil)
			return
		end
		local entry = (type(payload) == "table") and self._foodById[payload.foodId] or nil
		local dedupeService = ServiceResolver.Get(self._context, "HitCooldownDedupe")

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
			local playerService = ServiceResolver.Get(self._context, "PlayerService")
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
	local mapService = ServiceResolver.Get(self._context, "MapService")
	local arena = mapService and mapService:GetArenaModel()
	if arena then
		self:ClearMapFood(arena)
		self:SpawnFoodForMap(arena)
	end
end

function FoodService:SpawnFoodForMapName(mapName: string)
	self:LoadMapResources(mapName)
end

return FoodService
