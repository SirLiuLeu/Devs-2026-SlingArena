--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local DEFAULT_FOOD_RESPAWN_DELAY = 10
local FOODS_PER_SPAWN = 5
local FOOD_ZONE_TYPES = {
	Edge = { "Food1" },
	Middle = { "Food1" },
	Center = { "Food1" },
}

local FOOD_TYPE_STATS = {
	Food1 = { Exp = BalanceConfig.FoodExp, HP = BalanceConfig.FoodHealth },
}

local FoodService = {}
FoodService.__index = FoodService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

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

local function listSpawnAnchors(container: Instance?): { BasePart }
	local anchors = {}
	if not container then
		return anchors
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") and string.find(descendant.Name, "FoodSpawn", 1, true) == 1 then
			table.insert(anchors, descendant)
		end
	end
	table.sort(anchors, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
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
	local _ = mapCenter
	local configuredZone = anchor:GetAttribute("Zone")
	if type(configuredZone) == "string" and FOOD_ZONE_TYPES[configuredZone] then
		return configuredZone
	end
	return "Middle"
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

function FoodService:Init()
	local directArena = Workspace:FindFirstChild("ArenaMap")
	if directArena and directArena:IsA("Model") then
		self:ClearMapFood(directArena)
		self:SpawnFoodForMap(directArena)
	end

	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not mapsRoot or not mapsRoot:IsA("Folder") then
		return
	end
	for _, child in ipairs(mapsRoot:GetChildren()) do
		if child:IsA("Model") and isArenaMapName(child.Name) then
			self:ClearMapFood(child)
			self:SpawnFoodForMap(child)
		end
	end
end

local function anchorFoodModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function FoodService:_buildSpawnPosition(centerState: any): Vector3
	return centerState.Anchor.Position
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
	anchorFoodModel(clone)
	local spawnPosition = self:_buildSpawnPosition(centerState)
	local currentPivot = clone:GetPivot()
	local translation = spawnPosition - root.Position
	clone:PivotTo(currentPivot + translation)
	root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	self._foodSpawnByInstance[clone] = { CenterKey = centerState.CenterKey }
	root.Touched:Connect(function(hit)
		self:_onFoodTouched(clone, hit)
	end)
	return true
end

function FoodService:_spawnMissingFoodsForCenter(centerState: any)
	centerState.ActiveCount = 0
	for foodModel, info in pairs(self._foodSpawnByInstance) do
		if info.CenterKey == centerState.CenterKey and foodModel and foodModel.Parent then
			centerState.ActiveCount += 1
		end
	end
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

	local anchors = listSpawnAnchors(mapModel:FindFirstChild("FoodSpawns"))
	local mapCenter = getMapCenter(anchors, mapModel)
	if #anchors == 0 then
		warn(string.format("[FoodService] No FoodSpawn* parts found under %s.FoodSpawns", mapModel:GetFullName()))
		return
	end
	for index, anchor in ipairs(anchors) do
		local centerKey = string.format("%s:%s:%d", mapModel.Name, anchor.Name, index)
		local state = self._foodSpawnStateByCenter[centerKey] or {
			CenterKey = centerKey,
			MapModel = mapModel,
			FoodContainer = foodContainer,
			Anchor = anchor,
			Zone = getZoneForAnchor(anchor, mapCenter),
			TemplatesByName = templatesByName,
			FallbackTemplate = fallbackTemplate,
			ActiveCount = 0,
		}
		state.MapModel = mapModel
		state.FoodContainer = foodContainer
		state.Anchor = anchor
		state.Zone = getZoneForAnchor(anchor, mapCenter)
		state.TemplatesByName = templatesByName
		state.FallbackTemplate = fallbackTemplate
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
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		warn("[FoodService] PlayerService unavailable; cannot validate food collision owner.")
		self._foodTouchedDebounce[player] = nil
		return
	end
	if model ~= playerService:GetPawn(player) then
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
	local stateService = getService(self._context, "PlayerStateService")
	if stateService then
		stateService:Heal(player, stats.HP)
		stateService:PublishState(player)
	else
		warn("[FoodService] PlayerStateService unavailable; skipped heal/state publish on consume.")
	end
	task.delay(0.1, function()
		self._foodTouchedDebounce[player] = nil
	end)
end

function FoodService:LoadMapResources(mapName: string)
	local mapModel: Model? = nil
	if mapName == "ArenaMap" then
		local directArena = Workspace:FindFirstChild("ArenaMap")
		if directArena and directArena:IsA("Model") then
			mapModel = directArena
		end
	end
	if not mapModel then
		local mapsRoot = Workspace:FindFirstChild("Maps")
		if mapsRoot and mapsRoot:IsA("Folder") then
			local nested = mapsRoot:FindFirstChild(mapName)
			if nested and nested:IsA("Model") then
				mapModel = nested
			end
		end
	end
	if not mapModel then
		return
	end
	if isArenaMapName(mapName) then
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
