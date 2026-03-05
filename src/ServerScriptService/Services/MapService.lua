--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local DEFAULT_MAP_DURATION = 120

local MapService = {}
MapService.__index = MapService

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
	self._lobbyTouchedDebounce = {}
	self._foodTouchedDebounce = {}
	self._customTrapDebounce = {}
	self._teleportRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.TeleportRequest) :: RemoteEvent
	self._debugSpawnFoodRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.DebugSpawnFood) :: RemoteEvent
	return self
end

local function getStudioMapsRoot(): Folder?
	local maps = Workspace:FindFirstChild("Maps")
	if maps and maps:IsA("Folder") then
		return maps
	end
	return nil
end

local function getFoodTemplate(): Model?
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	if prefabs then
		local prefabFood = prefabs:FindFirstChild("Food")
		if prefabFood and prefabFood:IsA("Model") then
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
		return basicFood
	end
	return nil
end

local function getTrapTemplate(): Model?
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	if prefabs then
		local prefabTrap = prefabs:FindFirstChild("Trap")
		if prefabTrap and prefabTrap:IsA("Model") then
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
		return basicTrap
	end
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
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		return arena
	end

	if self._mapRoot then
		local arenaMap = self._mapRoot:FindFirstChild("ArenaMap")
		if arenaMap then
			return arenaMap
		end
	end

	local mapsRoot = getStudioMapsRoot()
	if mapsRoot then
		local map = mapsRoot:FindFirstChild("ArenaMap")
		if map then
			return map
		end
	end

	return nil
end

function MapService:GetArenaSpawn(): BasePart?
	local arena = self:GetArenaModel()
	if not arena then
		return nil
	end

	local points = {}
	for _, descendant in ipairs(arena:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "SpawnPoint" then
			table.insert(points, descendant)
		end
	end

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

	return nil
end

function MapService:_getArenaSpawnPosition(): Vector3
	local spawn = self:GetArenaSpawn()
	if spawn then
		return spawn.Position + Vector3.new(0, 4, 0)
	end
	return Vector3.new(0, 8, 0)
end

function MapService:_getArenaSpawnCFrame(): CFrame
	local spawn = self:GetArenaSpawn()
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
	self._mapRoot = Workspace:FindFirstChild("MapDefinitions")
	if not self._mapRoot then
		warn("Workspace.MapDefinitions folder is missing")
		return
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
	if not self._mapRoot then return end
	for _, child in ipairs(self._mapRoot:GetChildren()) do
		if child:IsA("Model") then
			local enabled = child.Name == mapName
			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Transparency = enabled and (descendant:GetAttribute("DefaultTransparency") or descendant.Transparency) or 1
					descendant.CanCollide = enabled
					descendant.CanTouch = enabled
				end
			end
		end
	end
	self._activeMap = mapName
	self:Generate()
	self:_spawnMapFoodAndTraps(mapName)
	self:_ensureArenaObstacles()
end

function MapService:Generate()
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
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

local function listSpawnPoints(mapModel: Model): { BasePart }
	local points = {}
	for _, descendant in ipairs(mapModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "SpawnPoint" then
			table.insert(points, descendant)
		end
	end
	return points
end

function MapService:_getSpawnPointsForMap(mapName: string): { BasePart }
	if not self._mapRoot then
		return {}
	end
	local mapModel = self._mapRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
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

function MapService:GetMapDuration(): number
	return self._mapDuration
end

function MapService:GetActiveMap(): string?
	return self._activeMap
end

function MapService:GetSpawnPoint(index: number, mapName: string?): Vector3
	if mapName == "ArenaMap" then
		return self:_getArenaSpawnPosition()
	end
	local points = self._spawnPoints
	if mapName and mapName ~= self._activeMap then
		points = self:_getSpawnPointsForMap(mapName)
	end
	if #points == 0 then
		return Vector3.new(0, 8, 0)
	end
	local clampedIndex = ((index - 1) % #points) + 1
	return points[clampedIndex].Position + Vector3.new(0, 4, 0)
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
	if mapName == "ArenaMap" then
		self:SpawnFood(8)
		self:SpawnTrap(4)
	end

	local mapsRoot = getStudioMapsRoot()
	if not mapsRoot then
		-- CREATE MANUALLY IN STUDIO: Workspace.Maps
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		return
	end
	self:ClearMapFood(mapModel)
	self:SpawnFoodForMap(mapModel, 8)
	self:SpawnTrapForMap(mapModel, 4)
end

function MapService:SpawnFood(count: number?)
	local arena = self:GetArenaModel()
	if not arena then
		return
	end

	local template = getFoodTemplate()
	if not template then
		return
	end

	local foodFolder = ensureFolder(arena, "Food")
	for _, child in ipairs(foodFolder:GetChildren()) do
		if child:GetAttribute("SpawnedByServer") == true then
			child:Destroy()
		end
	end

	for i = 1, (count or 8) do
		local clone = template:Clone()
		clone.Name = `Food_{i}`
		clone:SetAttribute("SpawnedByServer", true)
		clone.Parent = foodFolder
		local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if root then
			clone.PrimaryPart = root
			clone:PivotTo(CFrame.new(self:GetRandomArenaPoint()))
			root.Touched:Connect(function(hit)
				self:_onFoodTouched(clone, hit)
			end)
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
		return
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

function MapService:SpawnFoodForMap(mapModel: Model, count: number)
	local foodContainer = mapModel:FindFirstChild("FoodContainer")
	if not foodContainer or not foodContainer:IsA("Folder") then
		-- CREATE MANUALLY IN STUDIO: Workspace.Maps.[MapName].FoodContainer
		return
	end
	local foodTemplate = getFoodTemplate()
	if not foodTemplate then
		-- CREATE MANUALLY IN STUDIO: ReplicatedStorage.Assets.Food.BasicFood
		return
	end

	for i = 1, count do
		local clone = foodTemplate:Clone()
		clone:SetAttribute("SpawnedByServer", true)
		clone.Name = `Food_{i}`
		clone.Parent = foodContainer
		local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if root then
			clone.PrimaryPart = root
			local px = math.random(-50, 50)
			local pz = math.random(-50, 50)
			clone:PivotTo(mapModel:GetPivot() * CFrame.new(px, 4, pz))
			root.Touched:Connect(function(hit)
				self:_onFoodTouched(clone, hit)
			end)
		end
	end
end

function MapService:SpawnTrapForMap(mapModel: Model, count: number)
	local trapContainer = mapModel:FindFirstChild("TrapContainer")
	if not trapContainer or not trapContainer:IsA("Folder") then
		return
	end
	local trapTemplate = getTrapTemplate()
	if not trapTemplate then
		-- CREATE MANUALLY IN STUDIO: ReplicatedStorage.Assets.Trap.BasicTrap
		return
	end
	for i = 1, count do
		local trap = trapTemplate:Clone()
		trap:SetAttribute("SpawnedByServer", true)
		trap.Name = `Trap_{i}`
		trap.Parent = trapContainer
		local root = trap.PrimaryPart or trap:FindFirstChildWhichIsA("BasePart")
		if root then
			trap.PrimaryPart = root
			root.Anchored = true
			root.CanCollide = true
			local px = math.random(-45, 45)
			local pz = math.random(-45, 45)
			trap:PivotTo(mapModel:GetPivot() * CFrame.new(px, 3, pz))
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
	food:Destroy()
	self._context.EventBus:Fire("CollisionDetected", "Food", player, food, {})
	self._context.EventBus:Fire("FoodConsumed", player, BalanceConfig.FoodExp)
	self._context.Services.PlayerStateService:Heal(player, BalanceConfig.FoodHealth)
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
		-- CREATE MANUALLY IN STUDIO: Workspace.Maps.ForestArena.SpawnPoints.Spawn1
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		return
	end
	local spawnPoints = mapModel:FindFirstChild("SpawnPoints")
	if not spawnPoints then
		return
	end
	local spawnPart = spawnPoints:FindFirstChild(spawnName)
	if not spawnPart or not spawnPart:IsA("BasePart") then
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
		self:SpawnFoodForMap(mapModel, 4)
	end
end

return MapService
