--!strict

local Workspace = game:GetService("Workspace")

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
	return self
end

function MapService:Init()
	self._mapRoot = Workspace:FindFirstChild("MapDefinitions")
	if not self._mapRoot then
		warn("Workspace.MapDefinitions folder is missing")
		return
	end
	self:ActivateMap("LobbyMap")
	self:_hookLobbyGates()
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

function MapService:GetSpawnPoint(index: number): Vector3
	if #self._spawnPoints == 0 then
		return Vector3.new(0, 8, 0)
	end
	local clampedIndex = ((index - 1) % #self._spawnPoints) + 1
	return self._spawnPoints[clampedIndex].Position + Vector3.new(0, 4, 0)
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
