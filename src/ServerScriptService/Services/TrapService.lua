--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)
local TrapService = {}
TrapService.__index = TrapService

local function getArenaMapModel(): Model?
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if mapsRoot and mapsRoot:IsA("Folder") then
		local nestedArena = mapsRoot:FindFirstChild("ArenaMap")
		if nestedArena and nestedArena:IsA("Model") then
			return nestedArena
		end
	end

	local directArena = Workspace:FindFirstChild("ArenaMap")
	if directArena and directArena:IsA("Model") then
		return directArena
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

local function nameMatchesTrapConfig(instanceName: string, trapType: string, config: any): boolean
	if instanceName == trapType or instanceName == config.PartName then
		return true
	end
	for _, partName in ipairs(config.PartNames or {}) do
		if instanceName == partName then
			return true
		end
	end
	return false
end

local function findTrapRoot(instance: Instance, trapType: string): Instance
	local current: Instance? = instance
	local bestMatch: Instance? = nil
	while current do
		if current.Name == trapType then
			bestMatch = current
		end
		if current.Name == "Traps" then
			break
		end
		current = current.Parent
	end
	return bestMatch or instance
end

local function getTrapInfo(trapPart: BasePart): (string?, any?, Instance?)
	local current: Instance? = trapPart
	while current do
		for trapType, config in pairs(TrapConfig.Types or {}) do
			if config.Enabled ~= false and nameMatchesTrapConfig(current.Name, trapType, config) then
				return trapType, config, findTrapRoot(current, trapType)
			end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function getTrapSourceId(sourceRoot: Instance, trapType: string): string
	return `Trap:{trapType}:{sourceRoot:GetDebugId(0)}`
end

local function resolveDamageAmount(playerState: any, damageConfig: any): number
	if type(damageConfig) == "table" and damageConfig.Mode == "MaxHPPercent" then
		local maxHp = tonumber(playerState.MaxHP) or 0
		if maxHp > 0 then
			return maxHp * math.max(0, tonumber(damageConfig.Percent) or 0)
		end
		return math.max(0, tonumber(damageConfig.Fallback) or 0)
	end
	return math.max(0, tonumber(damageConfig) or 0)
end

function TrapService.new(context)
	local self = setmetatable({}, TrapService)
	self._context = context
	self._lastTriggeredAt = {} :: { [string]: number }
	self._trapTouchedConnections = {}
	self._activeContacts = {} :: { [string]: boolean }
	self._contactHits = {} :: { [string]: { [Instance]: boolean } }
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
	if not trapFolder then
		return parts
	end
	for _, trap in ipairs(trapFolder:GetChildren()) do
		if trap:IsA("BasePart") and getTrapInfo(trap) then
			table.insert(parts, trap)
		end
		for _, trapPart in ipairs(trap:GetDescendants()) do
			if trapPart:IsA("BasePart") and getTrapInfo(trapPart) then
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
	table.clear(self._activeContacts)
	table.clear(self._contactHits)
end

function TrapService:_getPlayerFromHit(hit: Instance): Player?
	local pawn = hit:FindFirstAncestorOfClass("Model")
	if not pawn then
		return nil
	end
	local playerService = self._context.Services.PlayerService
	return playerService and playerService:GetPlayerFromPawn(pawn) or nil
end

function TrapService:_bindTrapTouched(trapPart: BasePart)
	table.insert(self._trapTouchedConnections, trapPart.Touched:Connect(function(hit)
		local player = self:_getPlayerFromHit(hit)
		if player then
			self:_beginTrapContact(player, trapPart, hit)
		end
	end))
	table.insert(self._trapTouchedConnections, trapPart.TouchEnded:Connect(function(hit)
		local player = self:_getPlayerFromHit(hit)
		if player then
			self:_endTrapContact(player, trapPart, hit)
		end
	end))
end

function TrapService:LoadMapResources(mapName: string)
	if mapName ~= "ArenaMap" then
		return
	end
	local arenaMap = getArenaMapModel()
	local trapFolder = getTrapFolderFromArena(arenaMap)
	if not trapFolder then
		warn("[TrapService] Missing Workspace.Maps.ArenaMap.Traps folder. Create traps manually in Studio.")
		return
	end
	self:_disconnectTrapTouched()
	for _, trapPart in ipairs(self:GetActiveTrapParts()) do
		self:_bindTrapTouched(trapPart)
	end
end

function TrapService:SpawnTrapForActiveMap(_count: number)
	self:LoadMapResources("ArenaMap")
end

function TrapService:_getContactKey(player: Player, trapType: string, sourceRoot: Instance): string
	return `{player.UserId}:{getTrapSourceId(sourceRoot, trapType)}`
end

function TrapService:_emitPopup(player: Player, trapConfig: any)
	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") and trapConfig.PopupText then
		popup:FireClient(player, { Type = "Trap", Text = trapConfig.PopupText })
	end
end

function TrapService:_applySpikeTrap(player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Instance)
	local now = os.clock()
	local cooldown = math.max(0, tonumber(trapConfig.Cooldown) or 0)
	local cooldownKey = self:_getContactKey(player, trapType, sourceRoot)
	local last = self._lastTriggeredAt[cooldownKey] or 0
	if now - last < cooldown then
		return
	end
	self._lastTriggeredAt[cooldownKey] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)

	local damagePipeline = self._context.Services.DamagePipelineService
	if trapConfig.Damage and damagePipeline then
		damagePipeline:ApplyHitDamage(player, trapConfig.Damage, nil, nil, { SuppressKnockback = true })
	end

	local playerService = self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	local knockback = math.max(0, tonumber(trapConfig.Knockback) or 0)
	local upwardBoost = math.max(0, tonumber(trapConfig.UpwardBoost) or 0)
	if root and (knockback > 0 or upwardBoost > 0) then
		local away = root.Position - trapPart.Position
		if away.Magnitude < 0.01 then
			away = Vector3.new(1, 0, 0)
		end
		root.AssemblyLinearVelocity += away.Unit * knockback + Vector3.new(0, upwardBoost, 0)
	end
	self:_emitPopup(player, trapConfig)
end

function TrapService:_applyLavaTrapTick(player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Instance)
	local flagName = trapConfig.Flag
	local stateService = self._context.Services.PlayerStateService
	local damagePipeline = self._context.Services.DamagePipelineService
	if not (flagName and stateService and damagePipeline) then
		return
	end
	local state = stateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end

	local sourceId = getTrapSourceId(sourceRoot, trapType)
	local duration = math.max((tonumber(trapConfig.TickInterval) or 0.5) + 0.25, tonumber(trapConfig.EffectDuration) or 0)
	stateService:ApplyFlag(player, flagName, duration, sourceRoot, {
		SourceId = sourceId,
		Stackable = false,
		MaxStack = 1,
	})
	local slowAmount = math.max(0, tonumber(trapConfig.Slow) or 0)
	if slowAmount > 0 then
		stateService:ApplyFlag(player, "Slow", duration, sourceRoot, {
			SourceId = `{sourceId}:Slow`,
			SlowAmount = slowAmount,
		})
	end
	local amount = resolveDamageAmount(state, trapConfig.DamagePerTick)
	if amount > 0 then
		damagePipeline:ApplyDoTDamage(player, amount, trapPart, flagName)
	end
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)
	self:_emitPopup(player, trapConfig)
end

function TrapService:_stopLavaEffects(player: Player, trapType: string, trapConfig: any, sourceRoot: Instance)
	local stateService = self._context.Services.PlayerStateService
	if not stateService then
		return
	end
	local sourceId = getTrapSourceId(sourceRoot, trapType)
	if trapConfig.Flag then
		stateService:RemoveFlag(player, trapConfig.Flag, sourceRoot, { SourceId = sourceId })
	end
	stateService:RemoveFlag(player, "Slow", sourceRoot, { SourceId = `{sourceId}:Slow` })
end

function TrapService:_beginTrapContact(player: Player, trapPart: BasePart, hit: Instance?)
	local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
	if not (trapType and trapConfig and sourceRoot) then
		return
	end

	local contactKey = self:_getContactKey(player, trapType, sourceRoot)
	if hit then
		local hits = self._contactHits[contactKey]
		if not hits then
			hits = {}
			self._contactHits[contactKey] = hits
		end
		hits[hit] = true
	end

	if trapConfig.Behavior == "ContactDot" then
		if self._activeContacts[contactKey] then
			return
		end
		self._activeContacts[contactKey] = true
		task.spawn(function()
			while self._activeContacts[contactKey] do
				self:_applyLavaTrapTick(player, trapPart, trapType, trapConfig, sourceRoot)
				task.wait(math.max(0.05, tonumber(trapConfig.TickInterval) or 0.5))
			end
		end)
		return
	end

	self:_applySpikeTrap(player, trapPart, trapType, trapConfig, sourceRoot)
end

function TrapService:_endTrapContact(player: Player, trapPart: BasePart, hit: Instance?)
	local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
	if not (trapType and trapConfig and sourceRoot) then
		return
	end
	local contactKey = self:_getContactKey(player, trapType, sourceRoot)
	local hits = self._contactHits[contactKey]
	if hits and hit then
		hits[hit] = nil
		if next(hits) ~= nil then
			return
		end
	end
	self._contactHits[contactKey] = nil
	self._activeContacts[contactKey] = nil
	if trapConfig.Behavior == "ContactDot" then
		self:_stopLavaEffects(player, trapType, trapConfig, sourceRoot)
	end
end

function TrapService:OnTrapCollision(player: Player, trap: BasePart)
	-- Client-reported trap hits are edge-triggered fallback signals. Server touch
	-- events own contact end tracking for lava, while spike uses its cooldown key.
	self:_beginTrapContact(player, trap, nil)
end

return TrapService
