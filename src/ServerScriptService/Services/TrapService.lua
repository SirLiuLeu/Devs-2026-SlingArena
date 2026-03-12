--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)

local TrapService = {}
TrapService.__index = TrapService

local function isArenaMapName(mapName: string?): boolean
	return type(mapName) == "string" and mapName ~= "LobbyMap" and mapName ~= "Lobby" and string.find(mapName, "Arena", 1, true) ~= nil
end

local function getTrapTemplate(): Model?
	local templates = ServerStorage:FindFirstChild("TrapTemplates")
	if templates and templates:IsA("Folder") then
		for _, child in ipairs(templates:GetChildren()) do
			if child:IsA("Model") then
				return child
			end
		end
	end
	return nil
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

function TrapService.new(context)
	local self = setmetatable({}, TrapService)
	self._context = context
	self._lastTriggeredAt = {}
	return self
end

function TrapService:Init()
	self._context.EventBus:On("TrapCollisionCandidate", function(player: Player, trap: BasePart)
		self:OnTrapCollision(player, trap)
	end)
end

function TrapService:GetActiveTrapParts(): { BasePart }
	local parts = {}
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not mapsRoot then
		return parts
	end
	for _, map in ipairs(mapsRoot:GetChildren()) do
		if map:IsA("Model") then
			local trapContainer = map:FindFirstChild("TrapContainer")
			if trapContainer and trapContainer:IsA("Folder") then
				for _, trapPart in ipairs(trapContainer:GetDescendants()) do
					if trapPart:IsA("BasePart") then
						table.insert(parts, trapPart)
					end
				end
			end
		end
	end
	return parts
end

function TrapService:ClearMapTraps(mapModel: Model)
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

function TrapService:SpawnTrapForMap(mapModel: Model, count: number)
	local trapContainer = mapModel:FindFirstChild("TrapContainer")
	if not trapContainer or not trapContainer:IsA("Folder") then
		warn(string.format("[TrapService] Missing trap container: %s.TrapContainer", mapModel:GetFullName()))
		return
	end
	local template = getTrapTemplate()
	if not template then
		return
	end
	local anchors = listSpawnAnchors(mapModel:FindFirstChild("TrapSpawns"), "TrapSpawn")
	for i = 1, count do
		local trap = template:Clone()
		trap.Name = `Trap_{i}`
		trap:SetAttribute("SpawnedByServer", true)
		trap.Parent = trapContainer
		local root = trap.PrimaryPart or trap:FindFirstChildWhichIsA("BasePart")
		if root then
			trap.PrimaryPart = root
			root.Anchored = true
			root.CanCollide = true
			if #anchors > 0 then
				trap:PivotTo(anchors[((i - 1) % #anchors) + 1].CFrame)
			else
				trap:PivotTo(mapModel:GetPivot() * CFrame.new(math.random(-45, 45), 3, math.random(-45, 45)))
			end
		end
	end
end

function TrapService:LoadMapResources(mapName: string)
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not mapsRoot then
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if not mapModel or not mapModel:IsA("Model") then
		return
	end
	self:ClearMapTraps(mapModel)
	if isArenaMapName(mapName) then
		self:SpawnTrapForMap(mapModel, 4)
	end
end

function TrapService:SpawnTrapForActiveMap(count: number)
	local arena = self._context.Services.MapService:GetArenaModel()
	if arena then
		self:SpawnTrapForMap(arena, count)
	end
end

function TrapService:OnTrapCollision(player: Player, trap: BasePart)
	local now = os.clock()
	local last = self._lastTriggeredAt[player] or 0
	if now - last < TrapConfig.TriggerCooldown then
		return
	end
	self._lastTriggeredAt[player] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)

	local root = self._context.Services.PlayerService:GetRoot(player)
	if root and trap then
		local away = (root.Position - trap.Position)
		if away.Magnitude < 0.01 then
			away = Vector3.new(1, 0, 0)
		end
		root.AssemblyLinearVelocity += away.Unit * 55 + Vector3.new(0, 10, 0)
	end
	self._context.Services.DamagePipelineService:ApplyDamage(player, 15, nil, nil)

	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") then
		popup:FireClient(player, { Type = "Trap", Text = "Trap hit! -15 HP" })
	end
end

return TrapService
