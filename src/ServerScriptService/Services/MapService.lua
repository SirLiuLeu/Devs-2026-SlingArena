--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Config)

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
	self._foodFolder = nil
	self._foodTemplate = nil
	self._foodTouchedDebounce = {}
	return self
end

function MapService:Init()
	self._mapRoot = Workspace:FindFirstChild("MapDefinitions")
	if not self._mapRoot then
		warn("Workspace.MapDefinitions folder is missing")
		return
	end
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local foodTemplate = assets:WaitForChild("FoodBlock")
	if foodTemplate and foodTemplate:IsA("Model") then
		self._foodTemplate = foodTemplate
	end
	self._foodFolder = Workspace:FindFirstChild("ArenaFood")
	if not self._foodFolder then
		self._foodFolder = Instance.new("Folder")
		self._foodFolder.Name = "ArenaFood"
		self._foodFolder.Parent = Workspace
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
	if mapName == "ArenaMap" then
		self:SpawnArenaFood(Config.FoodCount)
	else
		self:ClearArenaFood()
	end
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

function MapService:_randomArenaPosition(): Vector3
	local radius = Config.MaxArenaRadius - 20
	return Vector3.new(math.random(-radius, radius), 4, math.random(-radius, radius))
end

function MapService:ClearArenaFood()
	self._foodTouchedDebounce = {}
	if not self._foodFolder then
		return
	end
	for _, child in ipairs(self._foodFolder:GetChildren()) do
		child:Destroy()
	end
end

function MapService:_spawnSingleFood()
	if not self._foodTemplate or not self._foodFolder then
		return
	end
	local food = self._foodTemplate:Clone()
	food.Parent = self._foodFolder
	local root = food.PrimaryPart
	if not root then
		root = food:FindFirstChildWhichIsA("BasePart")
		if root then
			food.PrimaryPart = root
		end
	end
	if root then
		food:PivotTo(CFrame.new(self:_randomArenaPosition()))
		root.CanCollide = false
		root.Anchored = true
		root.Touched:Connect(function(hit)
			self:_onFoodTouched(food, hit)
		end)
	end
end

function MapService:SpawnArenaFood(count: number)
	if not self._foodTemplate or not self._foodFolder then
		return
	end
	self:ClearArenaFood()
	for _ = 1, count do
		self:_spawnSingleFood()
	end
end

function MapService:_onFoodTouched(food: Model, hit: BasePart)
	if self._activeMap ~= "ArenaMap" then
		return
	end
	if not food.Parent then
		return
	end
	if food:GetAttribute("Consumed") then
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
	self._context.Services.PlayerService:GrowPawn(player, 0.03)
	self._context.Services.PlayerStateService:AddGrowth(player, 0.03)
	food:Destroy()
	task.delay(0.05, function()
		self._foodTouchedDebounce[player] = nil
	end)
	task.delay(0.2, function()
		if self._activeMap == "ArenaMap" then
			self:_spawnSingleFood()
		end
	end)
end

return MapService
