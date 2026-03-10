--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local DEFAULT_MAP_DURATION = 120
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

local MapService = {}
MapService.__index = MapService

local function isLobbyMapName(mapName: string?): boolean
	return mapName == "LobbyMap" or mapName == "Lobby"
end

local function isArenaMapName(mapName: string?): boolean
	if type(mapName) ~= "string" then
		return false
	end
	if isLobbyMapName(mapName) then
		return false
	end
	return string.find(mapName, "Arena", 1, true) ~= nil
end

function MapService.new(context)
	local self = setmetatable({}, MapService)
	self._context = context
	self._mapRoot = nil
	self._activeMap = nil
	self._mapDuration = DEFAULT_MAP_DURATION
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
	self._antiGiantZones = {}
	self._safeSpawnZones = {}
	self._sizeRestrictedCorridors = {}
	self._lobbyTouchedDebounce = {}
	self._foodTouchedDebounce = {}
	self._foodSpawnByInstance = {}
	self._foodSpawnStateByCenter = {}
	self._customTrapDebounce = {}
	self._activeArenaMapName = nil
	self._teleportRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.TeleportRequest) :: RemoteEvent
	self._debugSpawnFoodRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.DebugSpawnFood) :: RemoteEvent
	return self
end


local function getFoodRespawnDelay(): number
	local configuredRespawnDelay = BalanceConfig.FoodRespawnDelay
	if type(configuredRespawnDelay) ~= "number" or configuredRespawnDelay < 0 then
		return DEFAULT_FOOD_RESPAWN_DELAY
	end
	return configuredRespawnDelay
end

function MapService.BuildGridCellPositions(boundsCFrame: CFrame, boundsSize: Vector3, cellSize: number): { Vector3 }
	local positions = {}
	if cellSize <= 0 then
		return positions
	end

	local xCellCount = math.max(1, math.floor(boundsSize.X / cellSize))
	local zCellCount = math.max(1, math.floor(boundsSize.Z / cellSize))
	local xStart = -boundsSize.X * 0.5 + (boundsSize.X / xCellCount) * 0.5
	local zStart = -boundsSize.Z * 0.5 + (boundsSize.Z / zCellCount) * 0.5

	for xIndex = 1, xCellCount do
		for zIndex = 1, zCellCount do
			local localX = xStart + (xIndex - 1) * (boundsSize.X / xCellCount)
			local localZ = zStart + (zIndex - 1) * (boundsSize.Z / zCellCount)
			local localPosition = Vector3.new(localX, 0, localZ)
			table.insert(positions, boundsCFrame:PointToWorldSpace(localPosition))
		end
	end

	return positions
end

local function getStudioMapsRoot(): Folder?
	local maps = Workspace:FindFirstChild("Maps")
	if maps and maps:IsA("Folder") then
		return maps
	end
	return nil
end

local function getFoodTemplate(): Model?
	local serverFood = ServerStorage:FindFirstChild("Food")
	if serverFood and serverFood:IsA("Model") then
		print(string.format("[FoodService] Found template: %s (ServerStorage)", serverFood:GetFullName()))
		return serverFood
	end

	local serverTemplates = ServerStorage:FindFirstChild("FoodTemplates")
	if serverTemplates and serverTemplates:IsA("Folder") then
		for _, child in ipairs(serverTemplates:GetChildren()) do
			if child:IsA("Model") then
				print(string.format("[FoodService] Found template: %s (ServerStorage.FoodTemplates)", child.Name))
				return child
			end
		end
	end

	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	if prefabs then
		local prefabFood = prefabs:FindFirstChild("Food")
		if prefabFood and prefabFood:IsA("Model") then
			print(string.format("[FoodService] Found template: %s", prefabFood:GetFullName()))
			return prefabFood
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local foodFolder = assets:FindFirstChild("Food")
	if not foodFolder or not foodFolder:IsA("Folder") then
		return nil
	end
	local basicFood = foodFolder:FindFirstChild("BasicFood")
	if basicFood and basicFood:IsA("Model") then
		print(string.format("[FoodService] Found template: %s", basicFood:GetFullName()))
		return basicFood
	end
	warn("[FoodService] Food template missing. Expected one of: ServerStorage.Food (Model), ServerStorage.FoodTemplates.* (Model), ReplicatedStorage.Prefabs.Food (Model), ReplicatedStorage.Assets.Food.BasicFood (Model).")
	return nil
end

local function getTrapTemplate(): Model?
	local serverTemplates = ServerStorage:FindFirstChild("TrapTemplates")
	if serverTemplates and serverTemplates:IsA("Folder") then
		for _, child in ipairs(serverTemplates:GetChildren()) do
			if child:IsA("Model") then
				print(string.format("[TrapService] Found template: %s (ServerStorage.TrapTemplates)", child.Name))
				return child
			end
		end
	end

	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	if prefabs then
		local prefabTrap = prefabs:FindFirstChild("Trap")
		if prefabTrap and prefabTrap:IsA("Model") then
			print(string.format("[TrapService] Found template: %s", prefabTrap:GetFullName()))
			return prefabTrap
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local trapFolder = assets:FindFirstChild("Trap")
	if not trapFolder or not trapFolder:IsA("Folder") then
		return nil
	end
	local basicTrap = trapFolder:FindFirstChild("BasicTrap")
	if basicTrap and basicTrap:IsA("Model") then
		print(string.format("[TrapService] Found template: %s", basicTrap:GetFullName()))
		return basicTrap
	end
	warn("[TrapService] Trap template missing. Expected one of: ServerStorage.TrapTemplates.* (Model), ReplicatedStorage.Prefabs.Trap (Model), ReplicatedStorage.Assets.Trap.BasicTrap (Model).")
	return nil
end

local function ensureFolder(parent: Instance, folderName: string): Folder
	local existing = parent:FindFirstChild(folderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = parent
	return folder
end

function MapService:GetArenaModel(): Instance?
	if self._mapRoot then
		if self._activeArenaMapName then
			local arenaMap = self._mapRoot:FindFirstChild(self._activeArenaMapName)
			if arenaMap then
				return arenaMap
			end
		end
		for _, child in ipairs(self._mapRoot:GetChildren()) do
			if child:IsA("Model") and isArenaMapName(child.Name) then
				return child
			end
		end
	end

	local mapsRoot = getStudioMapsRoot()
	if mapsRoot then
		for _, map in ipairs(mapsRoot:GetChildren()) do
			if map:IsA("Model") and isArenaMapName(map.Name) then
				return map
			end
		end
	end

	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		return arena
	end

	return nil
end

local function cacheMapPartDefaults(mapModel: Model)
	for _, descendant in ipairs(mapModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("DefaultTransparency") == nil then
				descendant:SetAttribute("DefaultTransparency", descendant.Transparency)
			end
			if descendant:GetAttribute("DefaultCanCollide") == nil then
				descendant:SetAttribute("DefaultCanCollide", descendant.CanCollide)
			end
			if descendant:GetAttribute("DefaultCanTouch") == nil then
				descendant:SetAttribute("DefaultCanTouch", descendant.CanTouch)
			end
		end
	end
end

local function findSpawnPartsInMap(mapModel: Model): { BasePart }
	local points = {}
	local spawnFolder = mapModel:FindFirstChild("SpawnPoints")
	if spawnFolder and spawnFolder:IsA("Folder") then
		for _, descendant in ipairs(spawnFolder:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(points, descendant)
			end
		end
		if #points > 0 then
			return points
		end
	end

	for _, descendant in ipairs(mapModel:GetDescendants()) do
		if descendant:IsA("BasePart") and string.find(descendant.Name, "SpawnPoint", 1, true) then
			table.insert(points, descendant)
		end
	end
	return points
end

function MapService:GetArenaSpawn(mapName: string?): BasePart?
	local arena: Instance? = nil
	if mapName and self._mapRoot then
		arena = self._mapRoot:FindFirstChild(mapName)
	end
	if not arena then
		arena = self:GetArenaModel()
	end
	if not arena then
		return nil
	end
	if not arena:IsA("Model") then
		return nil
	end

	local points = findSpawnPartsInMap(arena)

	if #points == 0 then
		return nil
	end

	local index = math.random(1, #points)
	return points[index]
end

function MapService:GetLobbySpawn(): BasePart?
	if self._mapRoot then
		local lobbyMap = self._mapRoot:FindFirstChild("LobbyMap")
		if lobbyMap then
			for _, descendant in ipairs(lobbyMap:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name == "SpawnPoint" then
					return descendant
				end
			end
		end
	end

	local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
	if lobbySpawn and lobbySpawn:IsA("BasePart") then
		return lobbySpawn
	end

	local mapsRoot = getStudioMapsRoot()
	if mapsRoot then
		local lobbyMap = mapsRoot:FindFirstChild("LobbyMap")
		if lobbyMap and lobbyMap:IsA("Model") then
			for _, descendant in ipairs(lobbyMap:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name == "SpawnPoint" then
					return descendant
				end
			end
		end
	end

	return nil
end

function MapService:_getArenaSpawnPosition(mapName: string?): Vector3
	local spawn = self:GetArenaSpawn(mapName)
	if spawn then
		return spawn.Position
	end
	return Vector3.new(0, 8, 0)
end

function MapService:_getArenaSpawnCFrame(mapName: string?): CFrame
	local spawn = self:GetArenaSpawn(mapName)
	if spawn then
		return spawn.CFrame
	end
	return CFrame.new(0, 8, 0)
end

function MapService:GetRandomArenaPoint(): Vector3
	local arena = self:GetArenaModel()
	if not arena then
		return Vector3.new(math.random(-50, 50), 6, math.random(-50, 50))
	end

	local bounds: BasePart? = nil
	for _, descendant in ipairs(arena:GetDescendants()) do
		if descendant:IsA("BasePart") and (descendant.Name == "ArenaBounds" or descendant.Name == "Bounds") then
			bounds = descendant
			break
		end
	end

	if not bounds and arena:IsA("Model") then
		bounds = arena.PrimaryPart
	end

	if not bounds then
		return arena:GetPivot().Position + Vector3.new(math.random(-30, 30), 4, math.random(-30, 30))
	end

	local sx = bounds.Size.X * 0.5
	local sz = bounds.Size.Z * 0.5
	local localPoint = Vector3.new(math.random() * 2 * sx - sx, 4, math.random() * 2 * sz - sz)
	local worldPoint = bounds.CFrame:PointToWorldSpace(localPoint)
	return Vector3.new(worldPoint.X, bounds.Position.Y + 4, worldPoint.Z)
end

function MapService:Init()
	self._mapRoot = getStudioMapsRoot()
	if not self._mapRoot then
		warn("Workspace.Maps folder is missing. MapService requires Workspace.Maps.LobbyMap and arena models.")
	end
	if self._teleportRemote then
		self._teleportRemote.OnServerEvent:Connect(function(player: Player, mapName: string, spawnName: string)
			self:RequestTeleport(player, mapName, spawnName)
		end)
	end
	if self._debugSpawnFoodRemote then
		self._debugSpawnFoodRemote.OnServerEvent:Connect(function(player: Player, mapName: string)
			self:DebugSpawnFood(player, mapName)
		end)
	end
	self:ActivateMap("LobbyMap")
	self:_hookLobbyGates()
	self:_ensureArenaObstacles()
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
	local parentName = anchor.Parent and anchor.Parent.Name or ""
	if parentName == "EdgeZones" then
		return "Edge"
	elseif parentName == "MidZones" or parentName == "MiddleZones" then
		return "Middle"
	elseif parentName == "CenterZones" then
		return "Center"
	end

	local configuredZone = anchor:GetAttribute("Zone")
	if type(configuredZone) == "string" and FOOD_ZONE_TYPES[configuredZone] then
		return configuredZone
	end

	local offset = anchor.Position - mapCenter
	local distance = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	if distance <= 40 then
		return "Center"
	end
	if distance <= 85 then
		return "Middle"
	end
	return "Edge"
end

function MapService:GetArenaMapNames(): { string }
	local names = {}
	local root = self._mapRoot or getStudioMapsRoot()
	if not root then
		return names
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Model") and isArenaMapName(child.Name) then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

function MapService:GetDefaultArenaMapName(): string
	local arenaNames = self:GetArenaMapNames()
	if #arenaNames > 0 then
		return arenaNames[math.random(1, #arenaNames)]
	end
	return "ArenaMap"
end

function MapService:_resolveFoodFloorPosition(mapModel: Model, wantedPosition: Vector3, halfHeight: number): Vector3
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { mapModel }

	local rayOrigin = wantedPosition + Vector3.new(0, 128, 0)
	local rayDirection = Vector3.new(0, -512, 0)
	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result then
		return Vector3.new(wantedPosition.X, result.Position.Y + halfHeight, wantedPosition.Z)
	end

	local fallbackY = mapModel:GetPivot().Position.Y + halfHeight
	return Vector3.new(wantedPosition.X, fallbackY, wantedPosition.Z)
end

function MapService:GetFoodTypePoolForZone(zoneName: string): { string }
	local allowedTypes = FOOD_ZONE_TYPES[zoneName] or FOOD_ZONE_TYPES.Middle
	local copy = table.clone(allowedTypes)
	return copy
end

function MapService:PickRandomFoodTypeForZone(zoneName: string): string
	local allowedTypes = FOOD_ZONE_TYPES[zoneName] or FOOD_ZONE_TYPES.Middle
	return allowedTypes[math.random(1, #allowedTypes)]
end

function MapService:_buildFoodSpawnCenters(mapModel: Model): { any }
	local anchors = listSpawnAnchors(mapModel:FindFirstChild("FoodSpawns"), "FoodSpawn")
	if #anchors == 0 then
		return {}
	end

	table.sort(anchors, function(a: BasePart, b: BasePart)
		return a:GetFullName() < b:GetFullName()
	end)

	local mapCenter = getMapCenter(anchors, mapModel)
	local centers = {}
	for index, anchor in ipairs(anchors) do
		table.insert(centers, {
			CenterKey = string.format("%s:%d", mapModel.Name, index),
			Anchor = anchor,
			Zone = getZoneForAnchor(anchor, mapCenter),
		})
	end
	return centers
end

function MapService:_chooseSpawnPosition(mapModel: Model, centerPosition: Vector3, occupied: { Vector3 }): Vector3
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

function MapService:_spawnFoodFromCenterState(centerState: any): boolean
	if not centerState.MapModel.Parent or not centerState.FoodContainer.Parent then
		return false
	end

	local foodType = self:PickRandomFoodTypeForZone(centerState.Zone)
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
	local spawnPosition2D = self:_chooseSpawnPosition(centerState.MapModel, centerState.Anchor.Position, centerState.OccupiedPositions)
	local alignedPosition = self:_resolveFoodFloorPosition(centerState.MapModel, spawnPosition2D, root.Size.Y * 0.5)
	table.insert(centerState.OccupiedPositions, alignedPosition)
	clone:PivotTo(CFrame.new(alignedPosition))

	self._foodSpawnByInstance[clone] = {
		CenterKey = centerState.CenterKey,
		MapModel = centerState.MapModel,
		FoodContainer = centerState.FoodContainer,
	}

	root.Touched:Connect(function(hit)
		self:_onFoodTouched(clone, hit)
	end)

	return true
end

function MapService:_spawnMissingFoodsForCenter(centerState: any)
	while centerState.ActiveCount < FOODS_PER_SPAWN do
		local spawned = self:_spawnFoodFromCenterState(centerState)
		if not spawned then
			break
		end
		centerState.ActiveCount += 1
	end
end

function MapService:_spawnFoodForCenters(mapModel: Model, foodContainer: Folder, templatesByName: { [string]: Model }, fallbackTemplate: Model?)
	local centers = self:_buildFoodSpawnCenters(mapModel)
	if #centers == 0 then
		warn(string.format("[FoodService] Missing FoodSpawns/FoodSpawn in map: %s", mapModel:GetFullName()))
		return
	end

	for _, center in ipairs(centers) do
		local state = {
			CenterKey = center.CenterKey,
			MapModel = mapModel,
			FoodContainer = foodContainer,
			Anchor = center.Anchor,
			Zone = center.Zone,
			TemplatesByName = templatesByName,
			FallbackTemplate = fallbackTemplate,
			ActiveCount = 0,
			OccupiedPositions = {},
		}
		self._foodSpawnStateByCenter[center.CenterKey] = state
		self:_spawnMissingFoodsForCenter(state)
	end
end

function MapService:_hookLobbyGates()
	local lobby = self._mapRoot and self._mapRoot:FindFirstChild("LobbyMap")
	if not lobby then return end
	for _, part in ipairs(lobby:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "Gate" then
			part.Touched:Connect(function(hit)
				local model = hit:FindFirstAncestorOfClass("Model")
				if not model then return end
				local player = game.Players:GetPlayerFromCharacter(model)
				if not player then return end
				if self._lobbyTouchedDebounce[player] then return end
				self._lobbyTouchedDebounce[player] = true
				self._context.EventBus:Fire("LobbyGateTouched", player)
				task.delay(1, function() self._lobbyTouchedDebounce[player] = nil end)
			end)
		end
	end
end

function MapService:ActivateMap(mapName: string)
	print(string.format("[MapService] Map selected: %s", mapName))
	if self._mapRoot then
		for _, child in ipairs(self._mapRoot:GetChildren()) do
			if child:IsA("Model") then
				cacheMapPartDefaults(child)
				for _, descendant in ipairs(child:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Transparency = (descendant:GetAttribute("DefaultTransparency") :: number?) or descendant.Transparency
						descendant.CanCollide = (descendant:GetAttribute("DefaultCanCollide") :: boolean?) ~= false
						descendant.CanTouch = (descendant:GetAttribute("DefaultCanTouch") :: boolean?) ~= false
					end
				end
			end
		end
	end
	self._activeMap = mapName
	if isArenaMapName(mapName) then
		self._activeArenaMapName = mapName
	end
	self:Generate()
	self:_spawnMapFoodAndTraps(mapName)
	self:_ensureArenaObstacles()
end

function MapService:Generate()
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
	self._antiGiantZones = {}
	self._safeSpawnZones = {}
	self._sizeRestrictedCorridors = {}
	if not self._mapRoot or not self._activeMap then return end
	local active = self._mapRoot:FindFirstChild(self._activeMap)
	if not active then return end

	for _, descendant in ipairs(active:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "Gate" then
				table.insert(self._gates, descendant)
			elseif descendant.Name == "Trap" then
				table.insert(self._traps, descendant)
			elseif descendant.Name == "SpawnPoint" then
				table.insert(self._spawnPoints, descendant)
			elseif descendant.Name == "ExitZone" then
				table.insert(self._exitZones, descendant)
			elseif descendant.Name == "AntiGiantZone" then
				table.insert(self._antiGiantZones, descendant)
			elseif descendant.Name == "SafeSpawnZone" then
				table.insert(self._safeSpawnZones, descendant)
			elseif descendant.Name == "SizeRestrictedCorridor" then
				table.insert(self._sizeRestrictedCorridors, descendant)
			end
		end
	end

	local mapsRoot = getStudioMapsRoot()
	if mapsRoot then
		for _, map in ipairs(mapsRoot:GetChildren()) do
			if map:IsA("Model") then
				local trapContainer = map:FindFirstChild("TrapContainer")
				if trapContainer and trapContainer:IsA("Folder") then
					for _, trapPart in ipairs(trapContainer:GetDescendants()) do
						if trapPart:IsA("BasePart") then
							table.insert(self._traps, trapPart)
						end
					end
				end
			end
		end
	end
end

local listSpawnPoints = findSpawnPartsInMap

function MapService:_getSpawnPointsForMap(mapName: string): { BasePart }
	if self._mapRoot then
		local mapModel = self._mapRoot:FindFirstChild(mapName)
		if mapModel and mapModel:IsA("Model") then
			return listSpawnPoints(mapModel)
		end
	end

	local mapsRoot = getStudioMapsRoot()
	if not mapsRoot then
		warn(string.format("[MapService] Spawn point detection failed: Workspace.Maps missing for map %s", mapName))
		return {}
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		warn(string.format("[MapService] Spawn point detection failed: Workspace.Maps.%s missing", mapName))
		return {}
	end
	return listSpawnPoints(mapModel)
end

function MapService:IsGateBlocking(gate, playerSize)
	local maxSize = gate:GetAttribute("MaxSize")
	if typeof(maxSize) ~= "number" then
		return false
	end
	return playerSize > maxSize
end



function MapService:GetAntiGiantZones(): { BasePart }
	return self._antiGiantZones
end

function MapService:GetSafeSpawnZones(): { BasePart }
	return self._safeSpawnZones
end

function MapService:GetSizeRestrictedCorridors(): { BasePart }
	return self._sizeRestrictedCorridors
end

function MapService:CanPlayerUseCorridors(player: Player): boolean
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return true
	end
	local limit = BalanceConfig.CorridorSizeLimit
	return state.Size <= limit
end

function MapService:GetMapDuration(): number
	return self._mapDuration
end

function MapService:GetActiveMap(): string?
	return self._activeMap
end

function MapService:GetSpawnPoint(index: number, mapName: string?): Vector3
	if isArenaMapName(mapName) then
		return self:_getArenaSpawnPosition(mapName)
	end
	return self:GetSpawnCFrame(index, mapName).Position
end

function MapService:GetSpawnCFrame(index: number, mapName: string?): CFrame
	if isArenaMapName(mapName) then
		return self:_getArenaSpawnCFrame(mapName)
	end
	local points = self._spawnPoints
	if mapName and mapName ~= self._activeMap then
		points = self:_getSpawnPointsForMap(mapName)
	end
	if #points == 0 then
		warn(string.format("[MapService] Spawn point detection failed: no SpawnPoint found for map=%s activeMap=%s", tostring(mapName), tostring(self._activeMap)))
		return CFrame.new(0, 8, 0)
	end
	local clampedIndex = ((index - 1) % #points) + 1
	print(string.format("[MapService] Spawn found: %s (index %d/%d)", points[clampedIndex].Name, clampedIndex, #points))
	return points[clampedIndex].CFrame
end

function MapService:GetGates()
	return self._gates
end

function MapService:GetTrapBlocks()
	return self._traps
end

function MapService:GetExitZones()
	return self._exitZones
end

function MapService:_spawnMapFoodAndTraps(mapName: string)
	local mapsRoot = getStudioMapsRoot()
	if not mapsRoot then
		-- CREATE MANUALLY IN STUDIO: Workspace.Maps
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		warn(string.format("[INSTANCE_MISSING] Workspace.Maps.%s (Model) is missing.", mapName))
		return
	end
	self:ClearMapFood(mapModel)
	self:ClearMapTraps(mapModel)
	if not isArenaMapName(mapName) then
		return
	end
	self:SpawnFoodForMap(mapModel)
	self:SpawnTrapForMap(mapModel, 4)
end

function MapService:SpawnFood(_count: number?)
	local arena = self:GetArenaModel()
	if not arena or not arena:IsA("Model") then
		return
	end
	if not isArenaMapName(arena.Name) then
		return
	end
	self:SpawnFoodForMap(arena)
end

function MapService:ClearMapTraps(mapModel: Model)
	local trapContainer = mapModel:FindFirstChild("TrapContainer")
	if not trapContainer or not trapContainer:IsA("Folder") then
		return
	end
	for _, child in ipairs(trapContainer:GetChildren()) do
		if child:GetAttribute("SpawnedByServer") == true then
			child:Destroy()
		end
	end
end

function MapService:SpawnTrap(count: number?)
	local arena = self:GetArenaModel()
	if not arena then
		return
	end

	local template = getTrapTemplate()
	if not template then
		return false
	end

	local trapFolder = ensureFolder(arena, "Traps")
	for _, child in ipairs(trapFolder:GetChildren()) do
		if child:GetAttribute("SpawnedByServer") == true then
			child:Destroy()
		end
	end

	for i = 1, (count or 4) do
		local clone = template:Clone()
		clone.Name = `Trap_{i}`
		clone:SetAttribute("SpawnedByServer", true)
		clone.Parent = trapFolder
		local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if root then
			clone.PrimaryPart = root
			root.Anchored = true
			root.CanCollide = true
			clone:PivotTo(CFrame.new(self:GetRandomArenaPoint()))
		end
	end
end

function MapService:ClearMapFood(mapModel: Model)
	for instance, info in pairs(self._foodSpawnByInstance) do
		if info.MapModel == mapModel then
			self._foodSpawnByInstance[instance] = nil
		end
	end

	for centerKey, state in pairs(self._foodSpawnStateByCenter) do
		if state.MapModel == mapModel then
			self._foodSpawnStateByCenter[centerKey] = nil
		end
	end

	local foodContainer = mapModel:FindFirstChild("FoodContainer")
	if not foodContainer or not foodContainer:IsA("Folder") then
		-- CREATE MANUALLY IN STUDIO: Workspace.Maps.[MapName].FoodContainer
		return
	end
	for _, child in ipairs(foodContainer:GetChildren()) do
		if child:GetAttribute("SpawnedByServer") == true then
			child:Destroy()
		end
	end
end

function MapService:SpawnFoodForMap(mapModel: Model, _count: number?)
	local foodContainer = mapModel:FindFirstChild("FoodContainer")
	if not foodContainer or not foodContainer:IsA("Folder") then
		warn(string.format("[FoodService] Missing food container: %s.FoodContainer", mapModel:GetFullName()))
		-- CREATE MANUALLY IN STUDIO: Workspace.Maps.[MapName].FoodContainer
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
		-- CREATE MANUALLY IN STUDIO: ReplicatedStorage.Assets.Food.BasicFood
		return
	end

	self:_spawnFoodForCenters(mapModel, foodContainer, templatesByName, fallbackTemplate)
end

function MapService:SpawnTrapForMap(mapModel: Model, count: number)
	local trapContainer = mapModel:FindFirstChild("TrapContainer")
	if not trapContainer or not trapContainer:IsA("Folder") then
		warn(string.format("[FoodService] Missing trap container: %s.TrapContainer", mapModel:GetFullName()))
		return
	end
	local trapTemplate = getTrapTemplate()
	if not trapTemplate then
		-- CREATE MANUALLY IN STUDIO: ReplicatedStorage.Assets.Trap.BasicTrap
		return
	end
	local spawnAnchors = listSpawnAnchors(mapModel:FindFirstChild("TrapSpawns"), "TrapSpawn")

	for i = 1, count do
		local trap = trapTemplate:Clone()
		trap:SetAttribute("SpawnedByServer", true)
		trap.Name = `Trap_{i}`
		trap.Parent = trapContainer
		print(string.format("[FoodService] Cloned trap: %s -> %s", trap.Name, trapContainer:GetFullName()))
		local root = trap.PrimaryPart or trap:FindFirstChildWhichIsA("BasePart")
		if root then
			trap.PrimaryPart = root
			root.Anchored = true
			root.CanCollide = true
			if #spawnAnchors > 0 then
				local anchor = spawnAnchors[((i - 1) % #spawnAnchors) + 1]
				trap:PivotTo(anchor.CFrame)
			else
				local px = math.random(-45, 45)
				local pz = math.random(-45, 45)
				trap:PivotTo(mapModel:GetPivot() * CFrame.new(px, 3, pz))
			end
		end
	end
end

function MapService:_onFoodTouched(food: Model, hit: BasePart)
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
	food:Destroy()

	local foodType = food:GetAttribute("FoodType")
	local stats = FOOD_TYPE_STATS[foodType] or { Exp = BalanceConfig.FoodExp, HP = BalanceConfig.FoodHealth }

	if spawnInfo then
		local centerState = self._foodSpawnStateByCenter[spawnInfo.CenterKey]
		if centerState then
			centerState.ActiveCount = math.max(0, centerState.ActiveCount - 1)
			task.delay(getFoodRespawnDelay(), function()
				if not centerState.MapModel.Parent then
					return
				end
				if not centerState.FoodContainer.Parent then
					return
				end
				self:_spawnMissingFoodsForCenter(centerState)
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

function MapService:_ensureArenaObstacles()
	local mapsRoot = getStudioMapsRoot()
	if not mapsRoot then
		return
	end
	for _, map in ipairs(mapsRoot:GetChildren()) do
		if map:IsA("Model") then
			local walls = map:FindFirstChild("WallContainer")
			if walls and walls:IsA("Folder") then
				for _, wall in ipairs(walls:GetDescendants()) do
					if wall:IsA("BasePart") then
						wall.Anchored = true
						wall.CanCollide = true
					end
				end
			end
		end
	end
end

function MapService:RequestTeleport(player: Player, mapName: string, spawnName: string)
	if not RemoteContracts.Validate(RemoteContracts.Names.TeleportRequest, mapName, spawnName) then
		return
	end
	local roundState = self._context.Services.RoundService:GetState()
	if roundState == "ActiveRound" or roundState == "Countdown" then
		return
	end
	local mapsRoot = getStudioMapsRoot()
	if not mapsRoot then
		warn("[INSTANCE_MISSING] Workspace.Maps is missing. Create Workspace.Maps.[MapName].SpawnPoints.[SpawnName] manually in Studio.")
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		warn(string.format("[INSTANCE_MISSING] Workspace.Maps.%s (Model) is missing.", mapName))
		return
	end
	local spawnPoints = mapModel:FindFirstChild("SpawnPoints")
	if not spawnPoints then
		warn(string.format("[INSTANCE_MISSING] Workspace.Maps.%s.SpawnPoints (Folder) is missing.", mapName))
		return
	end
	local spawnPart = spawnPoints:FindFirstChild(spawnName)
	if not spawnPart or not spawnPart:IsA("BasePart") then
		warn(string.format("[INSTANCE_MISSING] Workspace.Maps.%s.SpawnPoints.%s (BasePart) is missing.", mapName, spawnName))
		return
	end
	if not self:CanPlayerUseCorridors(player) then
		warn(string.format("[MAP_RULE] %s cannot enter corridor while size exceeds limit %.2f", player.Name, BalanceConfig.CorridorSizeLimit))
		return
	end
	local pawn = self._context.Services.PlayerService:GetPawn(player)
	if not pawn then
		pawn = self._context.Services.PlayerService:SpawnPawn(player, nil, self._activeMap)
	end
	if not pawn then
		return
	end
	self._context.Services.PlayerStateService:SetTeleporting(player, true)
	task.wait(0.1)
	pawn:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	self._context.Services.PlayerStateService:SetMapName(player, mapName)
	self._context.Services.PlayerStateService:SetArenaStatus(player, `Teleported:{mapName}`)
	self._context.Services.PlayerStateService:SetTeleporting(player, false)
end

function MapService:DebugSpawnFood(_player: Player, mapName: string)
	local mapsRoot = getStudioMapsRoot()
	if not mapsRoot then
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if mapModel and mapModel:IsA("Model") then
		self:SpawnFoodForMap(mapModel)
	end
end

return MapService
