--!strict

local MapLoader = require(script.Parent.MapLoader)

local MapService = {}
MapService.__index = MapService

function MapService.new(context)
	local self = setmetatable({}, MapService)
	self._context = context
	self._loader = MapLoader.new()
	self._mapRoot = MapLoader.EnsureWorkspaceMapFolder()
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}
	return self
end

function MapService:Init()
	self:Generate()
	self._loader:LoadUi()
end

function MapService:Generate()
	self._gates = {}
	self._traps = {}
	self._spawnPoints = {}

	local parts = self._loader:LoadMap(self._mapRoot)
	for _, part in ipairs(parts) do
		if part.Name == "Gate" then
			table.insert(self._gates, part)
		elseif part.Name == "Trap" then
			table.insert(self._traps, part)
		elseif part.Name == "SpawnPoint" then
			table.insert(self._spawnPoints, part)
		end
	end
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

return MapService
