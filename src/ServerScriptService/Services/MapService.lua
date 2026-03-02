--!strict

local MapLoader = require(script.Parent.MapLoader)

local DEFAULT_MAP_DURATION = 120

local MapService = {}
MapService.__index = MapService

function MapService.new(context)
	local self = setmetatable({}, MapService)
	self._context = context
	self._loader = MapLoader.new()
	self._mapRoot = nil
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
	self._mapDuration = DEFAULT_MAP_DURATION
	return self
end

function MapService:Init()
	self:Generate()
end

function MapService:Generate()
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	self._exitZones = {}
	self._mapRoot = self._loader:GetMapRoot()
	self._mapDuration = self._loader:GetMapDuration(DEFAULT_MAP_DURATION)

	if not self._mapRoot then
		warn("Workspace.MapDefinitions folder is missing")
		return
	end

	for _, descendant in ipairs(self._mapRoot:GetDescendants()) do
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
end

function MapService:GetMapDuration(): number
	return self._mapDuration
end

function MapService:IsGateBlocking(gate, playerSize)
	local maxSize = gate:GetAttribute("MaxSize")
	if typeof(maxSize) ~= "number" then
		return false
	end
	return playerSize > maxSize
end

function MapService:GetSpawnPoint(index: number): Vector3
	if #self._spawnPoints == 0 then
		return Vector3.new(0, 8, 0)
	end
	local clampedIndex = ((index - 1) % #self._spawnPoints) + 1
	return self._spawnPoints[clampedIndex].Position + Vector3.new(0, 6, 0)
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

return MapService
