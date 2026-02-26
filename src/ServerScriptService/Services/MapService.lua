--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)

local MapService = {}
MapService.__index = MapService

function MapService.new(context)
	local self = setmetatable({}, MapService)
	self._context = context
	self._arenaFolder = Workspace:FindFirstChild("Arena")
	if not self._arenaFolder then
		self._arenaFolder = Instance.new("Folder")
		self._arenaFolder.Name = "Arena"
		self._arenaFolder.Parent = Workspace
	end
	self._gates = {}
	self._traps = {}
	return self
end

local function makePart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = "Environment"
	part.Parent = parent
	return part
end

function MapService:Init()
	self:Generate(os.time())
end

function MapService:Generate(seed)
	self._arenaFolder:ClearAllChildren()
	self._gates = {}
	self._traps = {}

	local random = Random.new(seed)
	makePart("ArenaFloor", Vector3.new(Config.MaxArenaRadius * 2, 4, Config.MaxArenaRadius * 2), Vector3.new(0, -2, 0), Color3.fromRGB(50, 50, 55), self._arenaFolder)

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = self._arenaFolder

	local wallHeight = 24
	local radius = Config.MaxArenaRadius
	makePart("NorthWall", Vector3.new(radius * 2, wallHeight, 8), Vector3.new(0, wallHeight / 2, -radius), Color3.fromRGB(83, 84, 92), wallsFolder)
	makePart("SouthWall", Vector3.new(radius * 2, wallHeight, 8), Vector3.new(0, wallHeight / 2, radius), Color3.fromRGB(83, 84, 92), wallsFolder)
	makePart("EastWall", Vector3.new(8, wallHeight, radius * 2), Vector3.new(radius, wallHeight / 2, 0), Color3.fromRGB(83, 84, 92), wallsFolder)
	makePart("WestWall", Vector3.new(8, wallHeight, radius * 2), Vector3.new(-radius, wallHeight / 2, 0), Color3.fromRGB(83, 84, 92), wallsFolder)

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = self._arenaFolder
	for i = 1, 20 do
		local size = Vector3.new(random:NextNumber(10, 24), random:NextNumber(8, 20), random:NextNumber(10, 24))
		local pos = Vector3.new(random:NextNumber(-radius + 30, radius - 30), size.Y / 2, random:NextNumber(-radius + 30, radius - 30))
		makePart(`Obstacle{i}`, size, pos, Color3.fromRGB(108, 108, 118), obstacles)
	end

	local gatesFolder = Instance.new("Folder")
	gatesFolder.Name = "Gates"
	gatesFolder.Parent = self._arenaFolder

	local trapsFolder = Instance.new("Folder")
	trapsFolder.Name = "Traps"
	trapsFolder.Parent = self._arenaFolder
	for i = 1, TrapConfig.TrapCount do
		local trap = makePart(`Trap{i}`, Vector3.new(10, 6, 10), Vector3.new(random:NextNumber(-radius + 30, radius - 30), 3, random:NextNumber(-radius + 30, radius - 30)), TrapConfig.TrapColor, trapsFolder)
		trap.Material = Enum.Material.Neon
		table.insert(self._traps, trap)
	end

	for i = 1, 6 do
		local gate = makePart(`Gate{i}`, Vector3.new(20, 18, 4), Vector3.new(random:NextNumber(-radius + 40, radius - 40), 9, random:NextNumber(-radius + 40, radius - 40)), Color3.fromRGB(142, 94, 196), gatesFolder)
		gate:SetAttribute("MaxSize", random:NextNumber(1.5, 5))
		table.insert(self._gates, gate)
	end
end

function MapService:IsGateBlocking(gate, playerSize)
	local maxSize = gate:GetAttribute("MaxSize")
	if typeof(maxSize) ~= "number" then
		return false
	end
	return playerSize > maxSize
end

function MapService:GetGates()
	return self._gates
end

function MapService:GetTrapBlocks()
	return self._traps
end

return MapService
