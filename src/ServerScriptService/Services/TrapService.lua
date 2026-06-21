--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

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

local function getTrapType(trap: BasePart): (string?, any?, BasePart?)
	local current: Instance? = trap
	while current do
		for trapType, config in pairs(TrapConfig.Types or {}) do
			if config.Enabled ~= false and nameMatchesTrapConfig(current.Name, trapType, config) then
				return trapType, config, trap
			end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function getSourceId(source: Instance, trapType: string): string
	local model = source:FindFirstAncestor(trapType)
	local sourceRoot = model or source
	return `Trap:{trapType}:{sourceRoot:GetDebugId(0)}`
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
	self._activeContacts = {}
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
		if trap:IsA("BasePart") then
			table.insert(parts, trap)
		end
		for _, trapPart in ipairs(trap:GetDescendants()) do
			if trapPart:IsA("BasePart") and getTrapType(trapPart) then
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
			self:_beginTrapContact(player, trapPart)
		end
	end))
	table.insert(self._trapTouchedConnections, trapPart.TouchEnded:Connect(function(hit)
		local player = self:_getPlayerFromHit(hit)
		if player then
			self:_endTrapContact(player, trapPart)
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

function TrapService:_getCooldownKey(player: Player, trapType: string, sourcePart: BasePart): string
	return `{player.UserId}:{trapType}:{getSourceId(sourcePart, trapType)}`
end

function TrapService:_emitPopup(player: Player, trapConfig: any)
	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") and trapConfig.PopupText then
		popup:FireClient(player, { Type = "Trap", Text = trapConfig.PopupText })
	end
end

function TrapService:_applySpikeTrap(player: Player, trap: BasePart, trapType: string, trapConfig: any)
	local now = os.clock()
	local cooldown = math.max(0, tonumber(trapConfig.TriggerCooldown or TrapConfig.SpikeTriggerCooldown or TrapConfig.TriggerCooldown) or 0)
	local cooldownKey = self:_getCooldownKey(player, trapType, trap)
	local last = self._lastTriggeredAt[cooldownKey] or 0
	if now - last < cooldown then
		return
	end
	self._lastTriggeredAt[cooldownKey] = now
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)

	local damagePipeline = self._context.Services.DamagePipelineService
	if trapConfig.ImpactDamage and damagePipeline then
		damagePipeline:ApplyHitDamage(player, trapConfig.ImpactDamage, nil, nil, { SuppressKnockback = true })
	end

	local playerService = self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	local knockback = math.max(0, tonumber(trapConfig.Knockback) or 0)
	local upwardBoost = math.max(0, tonumber(trapConfig.UpwardBoost) or 0)
	if root and (knockback > 0 or upwardBoost > 0) then
		local away = (root.Position - trap.Position)
		if away.Magnitude < 0.01 then
			away = Vector3.new(1, 0, 0)
		end
		root.AssemblyLinearVelocity += away.Unit * knockback + Vector3.new(0, upwardBoost, 0)
	end
	self:_emitPopup(player, trapConfig)
end

function TrapService:_applyLavaTrapTick(player: Player, trap: BasePart, trapType: string, trapConfig: any)
	local flagName = trapConfig.Flag
	local flagDefaults = GameConfig.FlagConfig[flagName] or {}
	local stateService = self._context.Services.PlayerStateService
	local damagePipeline = self._context.Services.DamagePipelineService
	if not (flagName and stateService and damagePipeline) then
		return
	end
	local state = stateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end

	-- Lava is a contact-based DOT: each tick refreshes the short burn/slow flags
	-- and applies damage from GameConfig, while TouchEnded stops future ticks.
	local sourceId = getSourceId(trap, trapType)
	stateService:ApplyFlag(player, flagName, flagDefaults.Duration, trap, {
		SourceId = sourceId,
		Stackable = flagDefaults.Stackable,
		MaxStack = flagDefaults.MaxStack,
	})
	local slowAmount = math.max(0, tonumber(flagDefaults.SlowAmount) or 0)
	if slowAmount > 0 then
		stateService:ApplyFlag(player, "Slow", flagDefaults.SlowDuration, trap, {
			SourceId = `{sourceId}:Slow`,
			SlowAmount = slowAmount,
		})
	end
	local amount = resolveDotAmount(state, flagDefaults.DamagePerTick)
	if amount > 0 then
		damagePipeline:ApplyDoTDamage(player, amount, trap, flagName)
	end
	self._context.EventBus:Fire("TrapCollision", player, TrapConfig.ExpPenalty)
	self:_emitPopup(player, trapConfig)
end

function TrapService:_beginTrapContact(player: Player, trap: BasePart)
	local trapType, trapConfig, sourcePart = getTrapType(trap)
	if not (trapType and trapConfig and sourcePart) then
		return
	end
	if trapConfig.UsesDot then
		local contactKey = self:_getCooldownKey(player, trapType, sourcePart)
		if self._activeContacts[contactKey] then
			return
		end
		self._activeContacts[contactKey] = true
		task.spawn(function()
			while self._activeContacts[contactKey] do
				self:_applyLavaTrapTick(player, sourcePart, trapType, trapConfig)
				task.wait(math.max(0.05, tonumber((GameConfig.FlagConfig[trapConfig.Flag] or {}).TickInterval) or 0.5))
			end
		end)
	else
		local contactKey = self:_getCooldownKey(player, trapType, sourcePart)
		if self._activeContacts[contactKey] then
			return
		end
		self._activeContacts[contactKey] = true
		task.spawn(function()
			while self._activeContacts[contactKey] do
				self:_applySpikeTrap(player, sourcePart, trapType, trapConfig)
				task.wait(math.max(0.05, tonumber(trapConfig.TriggerCooldown or TrapConfig.SpikeTriggerCooldown or TrapConfig.TriggerCooldown) or 1.5))
			end
		end)
	end
end

function TrapService:_endTrapContact(player: Player, trap: BasePart)
	local trapType, _, sourcePart = getTrapType(trap)
	if trapType and sourcePart then
		self._activeContacts[self:_getCooldownKey(player, trapType, sourcePart)] = nil
	end
end

function TrapService:OnTrapCollision(player: Player, trap: BasePart)
	-- Client-reported trap hits are treated as contact starts. Spike traps use
	-- per-instance cooldowns; lava DOT is continuously driven by server touches.
	self:_beginTrapContact(player, trap)
end

return TrapService
