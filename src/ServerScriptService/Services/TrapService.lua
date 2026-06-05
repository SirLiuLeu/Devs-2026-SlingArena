--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)

local TrapService = {}
TrapService.__index = TrapService

local function getArenaMapModel(): Model?
	local directArena = Workspace:FindFirstChild("ArenaMap")
	if directArena and directArena:IsA("Model") then
		return directArena
	end

	local mapsRoot = Workspace:FindFirstChild("Maps")
	if mapsRoot and mapsRoot:IsA("Folder") then
		local nestedArena = mapsRoot:FindFirstChild("ArenaMap")
		if nestedArena and nestedArena:IsA("Model") then
			return nestedArena
		end
	end

	return nil
end

local function getTrapFolderFromArena(arenaMap: Instance?): Folder?
	if not arenaMap or not arenaMap:IsA("Model") then
		return nil
	end
	local trapFolder = arenaMap:FindFirstChild("Traps")
	if trapFolder and trapFolder:IsA("Folder") then
		return trapFolder
	end
	return nil
end

local function resolveTrapType(trap: Instance?): string?
	local current = trap
	while current do
		if current.Name == "SpikeTrap" then
			return "SpikeTrap"
		elseif current.Name == "LavaBase" then
			return "LavaBase"
		end
		current = current.Parent
	end
	return nil
end

local function getTrapRule(trap: Instance?): any?
	local trapType = resolveTrapType(trap)
	return trapType and TrapConfig.Types and TrapConfig.Types[trapType] or nil
end

function TrapService.new(context)
	local self = setmetatable({}, TrapService)
	self._context = context
	self._lastTriggeredAt = {}
	self._trapTouchedConnections = {}
	return self
end

function TrapService:Init()
	self._context.EventBus:On("TrapCollisionCandidate", function(player: Player, trap: BasePart)
		self:OnTrapCollision(player, trap)
	end)
end

function TrapService:GetActiveTrapParts(): { BasePart }
	local parts = {}
	local arenaMap = getArenaMapModel()
	local trapFolder = getTrapFolderFromArena(arenaMap)
	if trapFolder then
		for _, trap in ipairs(trapFolder:GetChildren()) do
			if trap:IsA("BasePart") and getTrapRule(trap) then
				table.insert(parts, trap)
			end
			for _, trapPart in ipairs(trap:GetDescendants()) do
				if trapPart:IsA("BasePart") and getTrapRule(trapPart) then
					table.insert(parts, trapPart)
				end
			end
		end
	end
	if arenaMap then
		local lavaBase = arenaMap:FindFirstChild("LavaBase")
		if lavaBase and lavaBase:IsA("BasePart") then
			table.insert(parts, lavaBase)
		end
	end
	return parts
end


function TrapService:_disconnectTrapTouched()
	for _, connection in ipairs(self._trapTouchedConnections) do
		connection:Disconnect()
	end
	table.clear(self._trapTouchedConnections)
end

function TrapService:_bindTrapTouched(trapPart: BasePart)
	table.insert(self._trapTouchedConnections, trapPart.Touched:Connect(function(hit)
		local pawn = hit:FindFirstAncestorOfClass("Model")
		if not pawn then
			return
		end
		local playerService = self._context.Services.PlayerService
		if not playerService then
			return
		end
		local player = playerService:GetPlayerFromPawn(pawn)
		if not player then
			return
		end
		self:OnTrapCollision(player, trapPart)
	end))
end

function TrapService:LoadMapResources(mapName: string)
	if mapName ~= "ArenaMap" then
		return
	end
	local arenaMap = getArenaMapModel()
	local trapFolder = getTrapFolderFromArena(arenaMap)
	self:_disconnectTrapTouched()
	if not trapFolder then
		warn("[TrapService] Missing Workspace.ArenaMap.Traps folder. Spike traps must be created manually in Studio.")
	end
	for _, trapPart in ipairs(self:GetActiveTrapParts()) do
		self:_bindTrapTouched(trapPart)
	end
end

function TrapService:SpawnTrapForActiveMap(_count: number)
	self:LoadMapResources("ArenaMap")
end

function TrapService:OnTrapCollision(player: Player, trap: BasePart)
	local rule = getTrapRule(trap)
	if not rule then
		return
	end
	local now = os.clock()
	local key = `{player.UserId}:{trap:GetDebugId(0)}`
	local last = self._lastTriggeredAt[key] or 0
	if now - last < TrapConfig.TriggerCooldown then
		return
	end
	self._lastTriggeredAt[key] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)

	local root = self._context.Services.PlayerService:GetRoot(player)
	if root and trap and resolveTrapType(trap) == "SpikeTrap" then
		local away = (root.Position - trap.Position)
		if away.Magnitude < 0.01 then
			away = Vector3.new(1, 0, 0)
		end
		root.AssemblyLinearVelocity += away.Unit * 55 + Vector3.new(0, 10, 0)
	end

	local stateService = self._context.Services.PlayerStateService
	if stateService and rule.Flag then
		stateService:ApplyFlag(player, rule.Flag, rule.Duration, trap, {
			Duration = rule.Duration,
			Stackable = true,
			RefreshOnly = true,
			MaxStack = rule.MaxStack,
			TickInterval = rule.TickInterval,
			DamagePerTick = rule.DamagePerTick,
			ImmediateTick = rule.ImmediateTick == true,
		})
	end

	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") then
		local text = if resolveTrapType(trap) == "LavaBase" then "Lava!" else "Trap hit!"
		popup:FireClient(player, { Type = "Trap", Text = text })
	end
end


return TrapService
