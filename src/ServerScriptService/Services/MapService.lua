--!strict

local Workspace = game:GetService("Workspace")

local FOOD_ZONE_TYPES = {
	Edge = { "Food5", "Food6", "Food7" },
	Middle = { "Food2", "Food3", "Food4", "Food5", "Food6", "Food7" },
	Center = { "Food1", "Food2", "Food3", "Food4" },
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

local function getStudioMapsRoot(): Folder?
	local maps = Workspace:FindFirstChild("Maps")
	if maps and maps:IsA("Folder") then
		return maps
	end
	return nil
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
			table.insert(positions, boundsCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ)))
		end
	end
	return positions
end

function MapService.new(context)
	local self = setmetatable({}, MapService)
	self._context = context
	self._mapRoot = nil
	self._activeMap = nil
	self._activeArenaMapName = nil
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
	self._antiGiantZones = {}
	self._safeSpawnZones = {}
	self._sizeRestrictedCorridors = {}
	self._lobbyTouchedDebounce = {}
	return self
end

function MapService:GetFoodTypePoolForZone(zoneName: string): { string }
	return table.clone(FOOD_ZONE_TYPES[zoneName] or FOOD_ZONE_TYPES.Middle)
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

function MapService:GetArenaModel(): Model?
	local directArenaMap = Workspace:FindFirstChild("ArenaMap")
	if directArenaMap and directArenaMap:IsA("Model") then
		return directArenaMap
	end

	local root = self._mapRoot or getStudioMapsRoot()
	if root then
		if self._activeArenaMapName then
			local activeArena = root:FindFirstChild(self._activeArenaMapName)
			if activeArena and activeArena:IsA("Model") then
				return activeArena
			end
		end
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Model") and isArenaMapName(child.Name) then
				return child
			end
		end
	end
	local arena = Workspace:FindFirstChild("Arena")
	if arena and arena:IsA("Model") then
		return arena
	end
	return nil
end

function MapService:GetArenaSpawn(mapName: string?): BasePart?
	local arena: Instance? = nil
	if mapName and self._mapRoot then
		arena = self._mapRoot:FindFirstChild(mapName)
	end
	if not arena then
		arena = self:GetArenaModel()
	end
	if not arena or not arena:IsA("Model") then
		return nil
	end
	local points = findSpawnPartsInMap(arena)
	if #points == 0 then
		return nil
	end
	return points[math.random(1, #points)]
end

function MapService:GetTeamArenaSpawn(teamId: string, mapName: string?): BasePart?
	local arena: Instance? = nil
	if mapName and self._mapRoot then
		arena = self._mapRoot:FindFirstChild(mapName)
	end
	if not arena then
		arena = self:GetArenaModel()
	end
	if not arena or not arena:IsA("Model") then
		return nil
	end
	local spawnName = teamId == "TeamRed" and "RedSpawn" or "BlueSpawn"
	local spawn = arena:FindFirstChild(spawnName, true)
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	return self:GetArenaSpawn(mapName)
end

function MapService:GetLobbySpawn(): BasePart?
	local mapsRoot = self._mapRoot or getStudioMapsRoot()
	if mapsRoot then
		local lobbyModel = mapsRoot:FindFirstChild("Lobby")
		if lobbyModel and lobbyModel:IsA("Model") then
			local spawnPoints = lobbyModel:FindFirstChild("SpawnPoints")
			local spawnPoint = spawnPoints and spawnPoints:FindFirstChild("SpawnPoint")
			if spawnPoint and spawnPoint:IsA("BasePart") then
				return spawnPoint
			end
		end

		local lobbyMap = mapsRoot:FindFirstChild("LobbyMap")
		if lobbyMap and lobbyMap:IsA("Model") then
			local spawnPoints = lobbyMap:FindFirstChild("SpawnPoints")
			if spawnPoints and spawnPoints:IsA("Folder") then
				local preferred = spawnPoints:FindFirstChild("SpawnPoint") or spawnPoints:FindFirstChild("LobbySpawn")
				if preferred and preferred:IsA("BasePart") then
					return preferred
				end
			end
			for _, descendant in ipairs(lobbyMap:GetDescendants()) do
				if descendant:IsA("BasePart") and (descendant.Name == "SpawnPoint" or descendant.Name == "LobbySpawn") then
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

function MapService:GetRandomArenaPoint(): Vector3
	local arena = self:GetArenaModel()
	if not arena then
		return Vector3.new(math.random(-50, 50), 6, math.random(-50, 50))
	end
	local bounds = arena.PrimaryPart
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
	self:ActivateMap("LobbyMap")
end

function MapService:_hookLobbyGates()
	local lobby = self._mapRoot and self._mapRoot:FindFirstChild("LobbyMap")
	if not lobby then
		return
	end
	for _, part in ipairs(lobby:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "Gate" then
			part.Touched:Connect(function(hit)
				local model = hit:FindFirstAncestorOfClass("Model")
				if not model then return end
				local playerService = self._context.Services.PlayerService
				if not playerService then return end
				local player = playerService:GetPlayerFromPawn(model)
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
	self._activeMap = mapName
	if isArenaMapName(mapName) then
		self._activeArenaMapName = mapName
	end
	self:Generate()
	if self._context.Services.FoodService then
		self._context.Services.FoodService:LoadMapResources(mapName)
	end
	if self._context.Services.TrapService then
		self._context.Services.TrapService:LoadMapResources(mapName)
	end
end

function MapService:Generate()
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
	self._antiGiantZones = {}
	self._safeSpawnZones = {}
	self._sizeRestrictedCorridors = {}
	if not self._mapRoot or not self._activeMap then
		return
	end
	local active = self._mapRoot:FindFirstChild(self._activeMap)
	if not active then
		return
	end
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

	if self._context.Services.TrapService then
		for _, trapPart in ipairs(self._context.Services.TrapService:GetActiveTrapParts()) do
			table.insert(self._traps, trapPart)
		end
	end
end

function MapService:IsGateBlocking(gate: BasePart, playerSize: number): boolean
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
	local _ = player
	return true
end

function MapService:GetMapDuration(): number
	return 0
end

function MapService:GetActiveMap(): string?
	return self._activeMap
end

function MapService:GetSpawnPoint(index: number, mapName: string?): Vector3
	return self:GetSpawnCFrame(index, mapName).Position
end

function MapService:GetSpawnCFrame(index: number, mapName: string?, teamId: string?): CFrame
	if isArenaMapName(mapName) then
		local spawn = teamId and self:GetTeamArenaSpawn(teamId, mapName) or self:GetArenaSpawn(mapName)
		return spawn and spawn.CFrame or CFrame.new(0, 8, 0)
	end
	if isLobbyMapName(mapName) then
		local lobbySpawn = self:GetLobbySpawn()
		if lobbySpawn then
			return lobbySpawn.CFrame
		end
	end
	local points = self._spawnPoints
	if #points == 0 then
		return CFrame.new(0, 8, 0)
	end
	local clampedIndex = ((index - 1) % #points) + 1
	return points[clampedIndex].CFrame
end

function MapService:GetGates(): { BasePart }
	return self._gates
end

function MapService:GetTrapBlocks(): { BasePart }
	return self._traps
end

function MapService:GetExitZones(): { BasePart }
	return self._exitZones
end

function MapService:SpawnFood(_count: number?)
	print("[MapService] SpawnFood called with count:", _count)
	if self._context.Services.FoodService then
		self._context.Services.FoodService:SpawnFoodForActiveMap()
	end
end

function MapService:SpawnTrap(_count: number?)
	if self._context.Services.TrapService then
		self._context.Services.TrapService:LoadMapResources("ArenaMap")
		self:Generate()
	end
end

function MapService:RequestTeleport(player: Player, mapName: string, spawnName: string)
	local _ = player
	local _mapName = mapName
	local _spawnName = spawnName
	return
end

function MapService:DebugSpawnFood(_player: Player, mapName: string)
	print("[MapService] DebugSpawnFood called for player:", _player.Name, "mapName:", mapName)
	local _ = mapName
end

return MapService
