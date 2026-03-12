--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local DEFAULT_FOOD_RESPAWN_DELAY = 10
local FOODS_PER_SPAWN = 5
local FOOD_SPAWN_RADIUS = 5
local FOOD_MIN_SEPARATION = 2

local FOOD_ZONE_TYPES = {
	Edge = { "Food5", "Food6", "Food7" },
	Middle = { "Food2", "Food3", "Food4", "Food5", "Food6", "Food7" },
	Center = { "Food1", "Food2", "Food3", "Food4" },
}

local FOOD_TYPE_STATS = {
	Food1 = { Exp = 12, HP = 4 },
	Food2 = { Exp = 18, HP = 6 },
	Food3 = { Exp = 24, HP = 8 },
	Food4 = { Exp = 30, HP = 10 },
	Food5 = { Exp = 36, HP = 12 },
	Food6 = { Exp = 44, HP = 14 },
	Food7 = { Exp = 52, HP = 16 },
}

local FoodService = {}
FoodService.__index = FoodService

local function isArenaMapName(mapName: string?): boolean
	return type(mapName) == "string" and mapName ~= "LobbyMap" and mapName ~= "Lobby" and string.find(mapName, "Arena", 1, true) ~= nil
end

local function getFoodRespawnDelay(): number
	local configuredRespawnDelay = BalanceConfig.FoodRespawnDelay
	if type(configuredRespawnDelay) ~= "number" or configuredRespawnDelay < 0 then
		return DEFAULT_FOOD_RESPAWN_DELAY
	end
	return configuredRespawnDelay
end

local function listSpawnAnchors(container: Instance?, expectedName: string): { BasePart }
	local anchors = {}
	if not container then
		return anchors
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == expectedName then
			table.insert(anchors, descendant)
		end
	end
	return anchors
end

local function getMapCenter(positionAnchors: { BasePart }, mapModel: Model): Vector3
	if #positionAnchors == 0 then
		return mapModel:GetPivot().Position
	end
	local sum = Vector3.zero
	for _, anchor in ipairs(positionAnchors) do
		sum += anchor.Position
	end
	return sum / #positionAnchors
end

local function getZoneForAnchor(anchor: BasePart, mapCenter: Vector3): string
	local configuredZone = anchor:GetAttribute("Zone")
	if type(configuredZone) == "string" and FOOD_ZONE_TYPES[configuredZone] then
		return configuredZone
	end
	local offset = anchor.Position - mapCenter
	local distance = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	if distance <= 40 then
		return "Center"
	elseif distance <= 85 then
		return "Middle"
	end
	return "Edge"
end

local function getFoodTemplate(): Model?
	local serverFood = ServerStorage:FindFirstChild("Food")
	if serverFood and serverFood:IsA("Model") then
		return serverFood
	end
	local templates = ServerStorage:FindFirstChild("FoodTemplates")
	if templates and templates:IsA("Folder") then
		for _, child in ipairs(templates:GetChildren()) do
			if child:IsA("Model") then
				return child
			end
		end
	end
	return nil
end

function FoodService.new(context)
	local self = setmetatable({}, FoodService)
	self._context = context
	self._foodTouchedDebounce = {}
	self._foodSpawnByInstance = {}
	self._foodSpawnStateByCenter = {}
	return self
end

function FoodService:Init() end

function FoodService:_resolveFoodFloorPosition(mapModel: Model, wantedPosition: Vector3, halfHeight: number): Vector3
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { mapModel }
	local result = Workspace:Raycast(wantedPosition + Vector3.new(0, 128, 0), Vector3.new(0, -512, 0), raycastParams)
	if result then
		return Vector3.new(wantedPosition.X, result.Position.Y + halfHeight, wantedPosition.Z)
	end
	return Vector3.new(wantedPosition.X, mapModel:GetPivot().Position.Y + halfHeight, wantedPosition.Z)
end

function FoodService:_chooseSpawnPosition(centerPosition: Vector3, occupied: { Vector3 }): Vector3
	for _ = 1, 12 do
		local candidate = centerPosition + Vector3.new(math.random(-FOOD_SPAWN_RADIUS, FOOD_SPAWN_RADIUS), 0, math.random(-FOOD_SPAWN_RADIUS, FOOD_SPAWN_RADIUS))
		local valid = true
		for _, pos in ipairs(occupied) do
			if (Vector3.new(candidate.X, 0, candidate.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < FOOD_MIN_SEPARATION then
				valid = false
				break
			end
		end
		if valid then
			return candidate
		end
	end
	return centerPosition
end

function FoodService:_spawnFoodFromCenterState(centerState: any): boolean
	local allowedTypes = FOOD_ZONE_TYPES[centerState.Zone] or FOOD_ZONE_TYPES.Middle
	local foodType = allowedTypes[math.random(1, #allowedTypes)]
	local template = centerState.TemplatesByName[foodType] or centerState.FallbackTemplate
	if not template then
		return false
	end
	local clone = template:Clone()
	clone.Name = string.format("%s_%s", foodType, centerState.CenterKey)
	clone:SetAttribute("SpawnedByServer", true)
	clone:SetAttribute("FoodType", foodType)
	clone.Parent = centerState.FoodContainer
	local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if not root then
		clone:Destroy()
		return false
	end
	clone.PrimaryPart = root
	local spawnPosition = self:_chooseSpawnPosition(centerState.Anchor.Position, centerState.OccupiedPositions)
	local alignedPosition = self:_resolveFoodFloorPosition(centerState.MapModel, spawnPosition, root.Size.Y * 0.5)
	table.insert(centerState.OccupiedPositions, alignedPosition)
	clone:PivotTo(CFrame.new(alignedPosition))
	self._foodSpawnByInstance[clone] = { CenterKey = centerState.CenterKey }
	root.Touched:Connect(function(hit)
		self:_onFoodTouched(clone, hit)
	end)
	return true
end

function FoodService:_spawnMissingFoodsForCenter(centerState: any)
	while centerState.ActiveCount < FOODS_PER_SPAWN do
		if not self:_spawnFoodFromCenterState(centerState) then
			break
		end
		centerState.ActiveCount += 1
	end
end

function FoodService:ClearMapFood(mapModel: Model)
	for instance in pairs(self._foodSpawnByInstance) do
		if instance and instance.Parent and instance:IsDescendantOf(mapModel) then
			instance:Destroy()
		end
		self._foodSpawnByInstance[instance] = nil
	end
	for centerKey, state in pairs(self._foodSpawnStateByCenter) do
		if state.MapModel == mapModel then
			self._foodSpawnStateByCenter[centerKey] = nil
		end
	end
end

function FoodService:SpawnFoodForMap(mapModel: Model)
	local foodContainer = mapModel:FindFirstChild("FoodContainer")
	if not foodContainer or not foodContainer:IsA("Folder") then
		warn(string.format("[FoodService] Missing food container: %s.FoodContainer", mapModel:GetFullName()))
		return
	end
	local templatesByName = {}
	local serverTemplates = ServerStorage:FindFirstChild("FoodTemplates")
	if serverTemplates and serverTemplates:IsA("Folder") then
		for _, item in ipairs(serverTemplates:GetChildren()) do
			if item:IsA("Model") then
				templatesByName[item.Name] = item
			end
		end
	end
	local fallbackTemplate = getFoodTemplate()
	if not fallbackTemplate and next(templatesByName) == nil then
		warn("[FoodService] Food spawning aborted: no template models were found.")
		return
	end

	local anchors = listSpawnAnchors(mapModel:FindFirstChild("FoodSpawns"), "FoodSpawn")
	local mapCenter = getMapCenter(anchors, mapModel)
	for index, anchor in ipairs(anchors) do
		local centerKey = string.format("%s:%d", mapModel.Name, index)
		local state = {
			CenterKey = centerKey,
			MapModel = mapModel,
			FoodContainer = foodContainer,
			Anchor = anchor,
			Zone = getZoneForAnchor(anchor, mapCenter),
			TemplatesByName = templatesByName,
			FallbackTemplate = fallbackTemplate,
			ActiveCount = 0,
			OccupiedPositions = {},
		}
		self._foodSpawnStateByCenter[centerKey] = state
		self:_spawnMissingFoodsForCenter(state)
	end
end

function FoodService:_onFoodTouched(food: Model, hit: BasePart)
	if not food.Parent or food:GetAttribute("Consumed") then
		return
	end
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return
	end
	if model ~= self._context.Services.PlayerService:GetPawn(player) then
		return
	end
	if self._foodTouchedDebounce[player] then
		return
	end
	self._foodTouchedDebounce[player] = true
	food:SetAttribute("Consumed", true)
	local spawnInfo = self._foodSpawnByInstance[food]
	self._foodSpawnByInstance[food] = nil
	local foodType = food:GetAttribute("FoodType")
	local stats = FOOD_TYPE_STATS[foodType] or { Exp = BalanceConfig.FoodExp, HP = BalanceConfig.FoodHealth }
	food:Destroy()

	if spawnInfo then
		local centerState = self._foodSpawnStateByCenter[spawnInfo.CenterKey]
		if centerState then
			centerState.ActiveCount = math.max(0, centerState.ActiveCount - 1)
			task.delay(getFoodRespawnDelay(), function()
				if centerState.MapModel.Parent and centerState.FoodContainer.Parent then
					self:_spawnMissingFoodsForCenter(centerState)
				end
			end)
		end
	end

	self._context.EventBus:Fire("CollisionDetected", "Food", player, food, {})
	self._context.EventBus:Fire("FoodConsumed", player, stats.Exp)
	self._context.Services.PlayerStateService:Heal(player, stats.HP)
	self._context.Services.PlayerStateService:PublishState(player)
	task.delay(0.1, function()
		self._foodTouchedDebounce[player] = nil
	end)
end

function FoodService:LoadMapResources(mapName: string)
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not mapsRoot then
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		return
	end
	self:ClearMapFood(mapModel)
	if isArenaMapName(mapName) then
		self:SpawnFoodForMap(mapModel)
	end
end

function FoodService:SpawnFoodForActiveMap()
	local arena = self._context.Services.MapService:GetArenaModel()
	if arena then
		self:SpawnFoodForMap(arena)
	end
end

function FoodService:SpawnFoodForMapName(mapName: string)
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not mapsRoot then
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if mapModel and mapModel:IsA("Model") then
		self:SpawnFoodForMap(mapModel)
	end
end

return FoodService
