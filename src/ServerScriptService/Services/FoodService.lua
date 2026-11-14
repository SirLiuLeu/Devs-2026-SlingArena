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
local SPAWN_GRID_JITTER_FRACTION = math.clamp(tonumber(SPAWN_GRID_CONFIG.JitterFraction) or 0.12, 0, 0.25)
local MAX_POOLED_FOOD_PER_TYPE = math.max(0, math.floor(tonumber(SPAWN_GRID_CONFIG.MaxPooledPerType) or 12))
local MAX_CANDIDATE_CHECKS_PER_SLOT_TARGET = math.max(1, math.floor(tonumber(SPAWN_GRID_CONFIG.MaxCandidateChecksPerSlotTarget) or 8))
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

local function getAnchorSurfacePosition(foodModel: Model, spawnAnchor: BasePart, horizontalPosition: Vector3?, groundRaycastParams: RaycastParams?): Vector3?
	local hitbox = resolveFoodHitbox(foodModel)
	if not hitbox or not groundRaycastParams then return nil end
	local xzPosition = horizontalPosition
	if not xzPosition then
		local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
		local halfWidth = math.max(spawnAnchor.Size.X * 0.5 - radius, 0)
		local halfDepth = math.max(spawnAnchor.Size.Z * 0.5 - radius, 0)
		local localX = (math.random() * 2 - 1) * halfWidth
		local localZ = (math.random() * 2 - 1) * halfDepth
		xzPosition = spawnAnchor.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
	end

	local localPosition = spawnAnchor.CFrame:PointToObjectSpace(xzPosition)
	local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
	local halfWidth = math.max(spawnAnchor.Size.X * 0.5 - radius, 0)
	local halfDepth = math.max(spawnAnchor.Size.Z * 0.5 - radius, 0)
	if math.abs(localPosition.X) > halfWidth or math.abs(localPosition.Z) > halfDepth then return nil end

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

	local halfX, halfZ = hitbox.Size.X * 0.5, hitbox.Size.Z * 0.5
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

local function isHpFoodType(foodType: string?): boolean
	if type(foodType) ~= "string" then
		return false
	end
	local rule = FoodConfig.Foods[foodType]
	return rule ~= nil and FoodConfig.IsHpFood(rule.Type)
end

local function getMinNoOverlapDistance(firstFoodType: string?, secondFoodType: string?): number
	-- Reserve a 4-stud edge-to-edge gap only between HP Food items.
	-- Common Food can spawn nearby as long as its hitbox does not overlap.
	if isHpFoodType(firstFoodType) and (secondFoodType == nil or isHpFoodType(secondFoodType)) then
		return math.max(FoodConfig.MinNoOverlapDistance, FoodConfig.HpFoodMinNoOverlapDistance or FoodConfig.MinNoOverlapDistance)
	end
	return FoodConfig.MinNoOverlapDistance
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
	self._maxFoodTemplate = nil
	self._maxFoodPlacementRadius = 0
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
	self._maxFoodTemplate = nil
	self._maxFoodPlacementRadius = 0

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
				local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
				if radius > self._maxFoodPlacementRadius then
					self._maxFoodPlacementRadius = radius
					self._maxFoodTemplate = model
				end
			else
				warn(string.format("[FoodService] Invalid food model shape: %s", model:GetFullName()))
			end
		else
			warn(string.format("[FoodService] Missing food model: %s", foodName))
		end
	end

	if not self._maxFoodTemplate then
		warn("[FoodService] No valid Food model is available; fixed spawn slots cannot be built.")
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

function FoodService:_isSpawnPositionValid(spawnPart: BasePart, candidate: Vector3, foodRadius: number, batchPositions: { Vector3 }, batchRadii: { number }, batchFoodTypes: { string }, foodType: string): boolean
	local localCandidate = spawnPart.CFrame:PointToObjectSpace(candidate)
	local halfWidth = math.max(spawnPart.Size.X * 0.5 - foodRadius, 0)
	local halfDepth = math.max(spawnPart.Size.Z * 0.5 - foodRadius, 0)
	if math.abs(localCandidate.X) > halfWidth or math.abs(localCandidate.Z) > halfDepth then return false end

	for index, prior in ipairs(batchPositions) do
		local spacing = foodRadius + (batchRadii[index] or 0) + getMinNoOverlapDistance(foodType, batchFoodTypes[index])
		if sqrDistanceXZ(candidate, prior) <= spacing * spacing then return false end
	end
	for _, entry in ipairs(self:_collectNearbyEntries(candidate)) do
		local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") then
			local otherRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5
			local spacing = foodRadius + otherRadius + getMinNoOverlapDistance(foodType, entry.FoodType)
			if sqrDistanceXZ(candidate, hitbox.Position) <= spacing * spacing then return false end
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



function FoodService:_buildLatticePositions(spawnPart: BasePart, foodRadius: number): { Vector3 }
	local minimumGap = math.max(
		tonumber(FoodConfig.MinNoOverlapDistance) or 3,
		tonumber(FoodConfig.HpFoodMinNoOverlapDistance) or 4
	)
	local cellSize = math.max(foodRadius * 2 + minimumGap, 1)
	local halfWidth = math.max(spawnPart.Size.X * 0.5 - foodRadius, 0)
	local halfDepth = math.max(spawnPart.Size.Z * 0.5 - foodRadius, 0)
	local usableWidth = halfWidth * 2
	local usableDepth = halfDepth * 2
	local columns = math.max(1, math.floor(usableWidth / cellSize))
	local rows = math.max(1, math.floor(usableDepth / cellSize))
	local stepX = if columns > 0 then usableWidth / columns else 0
	local stepZ = if rows > 0 then usableDepth / rows else 0
	local jitterX = math.min(stepX * SPAWN_GRID_JITTER_FRACTION, cellSize * 0.15)
	local jitterZ = math.min(stepZ * SPAWN_GRID_JITTER_FRACTION, cellSize * 0.15)
	local candidates = {}

	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local x = if usableWidth > 0 then -halfWidth + (column + 0.5) * stepX else 0
			local z = if usableDepth > 0 then -halfDepth + (row + 0.5) * stepZ else 0
			x = math.clamp(x + (math.random() * 2 - 1) * jitterX, -halfWidth, halfWidth)
			z = math.clamp(z + (math.random() * 2 - 1) * jitterZ, -halfDepth, halfDepth)
			table.insert(candidates, spawnPart.CFrame:PointToWorldSpace(Vector3.new(x, 0, z)))
		end
	end

	for index = #candidates, 2, -1 do
		local swapIndex = math.random(1, index)
		candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
	end
	return candidates
end

function FoodService:_buildSpawnSlotsForPart(mapModel: Model, spawnPart: BasePart, zoneName: string, reservedPositions: { Vector3 }): ({ any }, number)
	local targetCount = self:_getSpawnCountForZone(zoneName, spawnPart)
	local slots = {}
	if targetCount <= 0 then
		return slots, targetCount
	end

	local template = self._maxFoodTemplate
	local templateHitbox = template and resolveFoodHitbox(template)
	local raycastParams = self._groundRaycastParamsByMap[mapModel]
	if not (template and templateHitbox and raycastParams) then
		return slots, targetCount
	end

	local minimumGap = math.max(
		tonumber(FoodConfig.MinNoOverlapDistance) or 3,
		tonumber(FoodConfig.HpFoodMinNoOverlapDistance) or 4
	)
	local minimumSpacing = self._maxFoodPlacementRadius * 2 + minimumGap
	local minimumSpacingSquared = minimumSpacing * minimumSpacing

	local candidates = self:_buildLatticePositions(spawnPart, self._maxFoodPlacementRadius)
	local candidateCheckBudget = math.min(
		#candidates,
		math.max(targetCount * MAX_CANDIDATE_CHECKS_PER_SLOT_TARGET, targetCount + 8)
	)
	for candidateIndex, candidate in ipairs(candidates) do
		if #slots >= targetCount or candidateIndex > candidateCheckBudget then
			break
		end

		local overlapsReservedSlot = false
		for _, reservedPosition in ipairs(reservedPositions) do
			if sqrDistanceXZ(candidate, reservedPosition) <= minimumSpacingSquared then
				overlapsReservedSlot = true
				break
			end
		end

		if not overlapsReservedSlot then
			local validatedHitboxPosition = getAnchorSurfacePosition(template, spawnPart, candidate, raycastParams)
			if validatedHitboxPosition then
				local groundY = validatedHitboxPosition.Y - templateHitbox.Size.Y * 0.5
				local groundPosition = Vector3.new(candidate.X, groundY, candidate.Z)
				local slot = {
					SpawnPart = spawnPart,
					ZoneName = zoneName,
					Position = groundPosition,
					GroundY = groundY,
					FoodType = nil,
					State = "Unassigned",
					NextAttemptAt = 0,
					BlockedAttempts = 0,
					WarnedBlocked = false,
					Entry = nil,
				}
				table.insert(slots, slot)
				table.insert(reservedPositions, groundPosition)
			end
		end
	end

	return slots, targetCount
end

function FoodService:_assignFoodTypesForZone(zoneName: string, slots: { any })
	if #slots == 0 then
		return
	end

	local weights = FoodConfig.ZoneWeights[zoneName]
	local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local availablePools = {}
	local totalWeight = 0
	local weightedRarities = {}

	for order, rarity in ipairs(rarityOrder) do
		local weight = tonumber(weights and weights[rarity]) or 0
		local availableTypes = {}
		local configuredPool = FoodConfig.TypePools[rarity] or {}
		for _, foodType in ipairs(configuredPool) do
			if self._foodModels[foodType] and FoodConfig.Foods[foodType] then
				table.insert(availableTypes, foodType)
			end
		end

		if weight > 0 and #availableTypes > 0 then
			availablePools[rarity] = availableTypes
			totalWeight += weight
			table.insert(weightedRarities, {
				Rarity = rarity,
				Weight = weight,
				Order = order,
			})
		end
	end

	if totalWeight <= 0 then
		for _, slot in ipairs(slots) do
			slot.State = "Disabled"
		end
		warn(string.format("[FoodService] Zone %s has slots but no configured rarity has an available Food model.", zoneName))
		return
	end

	local rarityCounts = {}
	local remainders = {}
	local allocatedCount = 0
	for _, rarityData in ipairs(weightedRarities) do
		local exactCount = #slots * rarityData.Weight / totalWeight
		local baseCount = math.floor(exactCount)
		rarityCounts[rarityData.Rarity] = baseCount
		allocatedCount += baseCount
		table.insert(remainders, {
			Rarity = rarityData.Rarity,
			Fraction = exactCount - baseCount,
			Order = rarityData.Order,
		})
	end

	table.sort(remainders, function(a, b)
		if a.Fraction == b.Fraction then
			return a.Order < b.Order
		end
		return a.Fraction > b.Fraction
	end)

	local remainingCount = #slots - allocatedCount
	for index = 1, remainingCount do
		local rarity = remainders[index].Rarity
		rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
	end

	local assignedTypes = {}
	for _, rarity in ipairs(rarityOrder) do
		local count = rarityCounts[rarity] or 0
		local pool = availablePools[rarity]
		if pool and #pool > 0 then
			for _ = 1, count do
				table.insert(assignedTypes, pool[math.random(1, #pool)])
			end
		end
	end

	for index = #assignedTypes, 2, -1 do
		local swapIndex = math.random(1, index)
		assignedTypes[index], assignedTypes[swapIndex] = assignedTypes[swapIndex], assignedTypes[index]
	end

	for index, slot in ipairs(slots) do
		slot.FoodType = assignedTypes[index]
		slot.State = if slot.FoodType then "Pending" else "Disabled"
		slot.NextAttemptAt = 0
	end
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
	if not self:_isSpawnPositionValid(spawnPart, candidate, foodRadius, {}, {}, {}, foodType) then
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
							if processedCount < MAX_SPAWN_PER_SCHEDULER_TICK and slot.NextAttemptAt <= now then
								processedCount += 1
								self:_trySpawnSlot(slot)
							end
						end
					end
				end
				if processedCount >= MAX_SPAWN_PER_SCHEDULER_TICK then
					break
				end
			end

			task.wait(if hasPendingSlots then SPAWN_SCHEDULER_INTERVAL_SECONDS else 1)
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

	local reservedPositions = {}
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

		local zoneSlots = {}
		local targetSlotCount = 0
		for _, spawnPart in ipairs(spawnParts) do
			local slots, targetCount = self:_buildSpawnSlotsForPart(mapModel, spawnPart, zoneFolder.Name, reservedPositions)
			targetSlotCount += targetCount
			self._spawnSlotsByPart[spawnPart] = {
				MapModel = mapModel,
				FoodContainer = foodContainer,
				SpawnPart = spawnPart,
				ZoneName = zoneFolder.Name,
				Slots = slots,
			}
			for index, slot in ipairs(slots) do
				slot.Index = index
				table.insert(zoneSlots, slot)
			end
		end

		self:_assignFoodTypesForZone(zoneFolder.Name, zoneSlots)

		local rarityCounts = {}
		for _, slot in ipairs(zoneSlots) do
			local rule = slot.FoodType and FoodConfig.Foods[slot.FoodType]
			if rule then
				rarityCounts[rule.Type] = (rarityCounts[rule.Type] or 0) + 1
			end
		end
		local raritySummary = {}
		for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
			local count = rarityCounts[rarity] or 0
			if count > 0 then
				table.insert(raritySummary, string.format("%s:%d", rarity, count))
			end
		end
		print(string.format(
			"[FoodService] Fixed slots prepared. map=%s zone=%s slots=%d target=%d rarity=%s",
			mapModel.Name,
			zoneFolder.Name,
			#zoneSlots,
			targetSlotCount,
			table.concat(raritySummary, ",")
		))

		if #zoneSlots < targetSlotCount then
			warn(string.format(
				"[FoodService] Fixed Food grid capacity below configured target. map=%s zone=%s validSlots=%d targetSlots=%d",
				mapModel.Name,
				zoneFolder.Name,
				#zoneSlots,
				targetSlotCount
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
