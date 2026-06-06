--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

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

local function getTrapType(trap: BasePart): (string?, any?, BasePart?)
	local current: Instance? = trap
	while current do
		for trapType, config in pairs(TrapConfig.Types or {}) do
			if current.Name == config.PartName or current.Name == trapType then
				return trapType, config, if current:IsA("BasePart") then current else trap
			end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function getSourceId(source: Instance, trapType: string): string
	return `Trap:{trapType}:{source:GetDebugId(0)}`
end

local function resolveDotAmount(playerState: any, damagePerTick: any): number
	if type(damagePerTick) == "table" and damagePerTick.Mode == "MaxHPPercent" then
		return math.max(tonumber(damagePerTick.Fallback) or 0, (playerState.MaxHP or 0) * math.max(0, tonumber(damagePerTick.Percent) or 0))
	end
	return math.max(0, tonumber(damagePerTick) or 0)
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
	self:_disconnectTrapTouched()
	if not trapFolder then
		return parts
	end
	for _, trap in ipairs(trapFolder:GetChildren()) do
		if trap:IsA("BasePart") then
			table.insert(parts, trap)
		end
		for _, trapPart in ipairs(trap:GetDescendants()) do
			if trapPart:IsA("BasePart") then
				table.insert(parts, trapPart)
			end
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
		warn("[TrapService] Missing Workspace.ArenaMap.Traps folder. Create traps manually in Studio.")
		return
	end
	for _, trapPart in ipairs(self:GetActiveTrapParts()) do
		self:_bindTrapTouched(trapPart)
	end
end

function TrapService:SpawnTrapForActiveMap(_count: number)
	self:LoadMapResources("ArenaMap")
end

function TrapService:OnTrapCollision(player: Player, trap: BasePart)
	local trapType, trapConfig, sourcePart = getTrapType(trap)
	if not (trapType and trapConfig and sourcePart) then
		return
	end
	local now = os.clock()
	local cooldownKey = `{player.UserId}:{trapType}:{sourcePart:GetDebugId(0)}`
	local last = self._lastTriggeredAt[cooldownKey] or 0
	if now - last < TrapConfig.TriggerCooldown then
		return
	end
	self._lastTriggeredAt[cooldownKey] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)

	local flagName = trapConfig.Flag
	local flagDefaults = GameConfig.FlagConfig[flagName] or {}
	local sourceId = getSourceId(sourcePart, trapType)
	local stateService = self._context.Services.PlayerStateService
	local damagePipeline = self._context.Services.DamagePipelineService

	if stateService and flagName then
		stateService:ApplyFlag(player, flagName, flagDefaults.Duration, sourcePart, {
			SourceId = sourceId,
			TickInterval = flagDefaults.TickInterval,
			DamagePerTick = flagDefaults.DamagePerTick,
			Stackable = flagDefaults.Stackable,
			MaxStack = flagDefaults.MaxStack,
		})
	end

	if trapConfig.ImpactDamage and damagePipeline then
		damagePipeline:ApplyHitDamage(player, trapConfig.ImpactDamage, nil, nil, { SuppressKnockback = true })
	end

	if trapConfig.ImmediateTick and damagePipeline and stateService then
		local state = stateService:GetState(player)
		if state then
			local amount = resolveDotAmount(state, flagDefaults.DamagePerTick)
			damagePipeline:ApplyDoTDamage(player, amount, sourcePart, flagName)
		end
	end

	local root = self._context.Services.PlayerService:GetRoot(player)
	local knockback = math.max(0, tonumber(trapConfig.Knockback) or 0)
	local upwardBoost = math.max(0, tonumber(trapConfig.UpwardBoost) or 0)
	if root and trap and (knockback > 0 or upwardBoost > 0) then
		local away = (root.Position - trap.Position)
		if away.Magnitude < 0.01 then
			away = Vector3.new(1, 0, 0)
		end
		root.AssemblyLinearVelocity += away.Unit * knockback + Vector3.new(0, upwardBoost, 0)
	end

	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") and trapConfig.PopupText then
		popup:FireClient(player, { Type = "Trap", Text = trapConfig.PopupText })
	end
end

return TrapService
