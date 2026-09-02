--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local StatusEffectVfx = require(ReplicatedStorage.Shared.Utils.StatusEffectVfx)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local MOVEMENT_STATE = GameStates.PlayerState

local FlagService = {}
FlagService.__index = FlagService

type ActiveFlag = {
	Name: string,
	ExpiresAt: number,
	Stacks: number,
	Source: any?,
	SourceId: string?,
	SourceUserId: number?,
	LastTickAt: number?,
	LastHealTickAt: number?,
	LastDamageTickAt: number?,
	Data: any?,
}

type FlagVisual = {
	EffectName: string?,
	AttachmentName: string?,
	Materials: { [BasePart]: Enum.Material },
}


local function getFlagDefaults(flagName: string): any
	return GameConfig.FlagConfig[flagName] or {}
end

local function isStatusEffectName(effectName: any?): boolean
	return StatusEffectVfx.IsStatusEffectName(effectName)
end

local function setStatusEffectEnabled(root: BasePart, effectName: string, enabled: boolean, attachmentName: string?)
	StatusEffectVfx.SetStatusEffectEnabled(root, effectName, enabled, attachmentName)
end

local function setAllStatusEffectsEnabled(root: BasePart, enabled: boolean)
	StatusEffectVfx.SetAllStatusEffectsEnabled(root, enabled)
end

local function mergeVisualConfig(flagName: string, data: any?): any
	local visualConfig = GameConfig.FlagVisualConfig and GameConfig.FlagVisualConfig[flagName] or {}
	local merged = {}
	for key, value in pairs(visualConfig) do
		merged[key] = value
	end
	if typeof(data) == "table" then
		for key, value in pairs(data) do
			if value ~= nil then
				merged[key] = value
			end
		end
	end
	return merged
end

local function getConfiguredEffect(flagName: string, data: any?): (string?, string?)
	local visualConfig = mergeVisualConfig(flagName, data)
	local effectName = visualConfig.Effect
	local attachmentName = visualConfig.Attachment
	if not isStatusEffectName(effectName) then
		return nil, nil
	end
	return effectName, if typeof(attachmentName) == "string" then attachmentName else StatusEffectVfx.GetDefaultAttachmentName(effectName)
end

local function collectLauncherVisualParts(pawn: Model): { BasePart }
	local equipped = pawn:FindFirstChild("EquippedLauncherModel") or pawn:FindFirstChild("EquipedLauncherModel")
	if not (equipped and equipped:IsA("Model")) then
		return {}
	end
	local parts = {}
	for _, descendant in equipped:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "RootPart" then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 and equipped.PrimaryPart then
		table.insert(parts, equipped.PrimaryPart)
	end
	return parts
end

local function collectMaterialTargets(pawn: Model, materialTarget: string?): { BasePart }
	if materialTarget == "DefaultMesh" then
		return collectLauncherVisualParts(pawn)
	end

	local targets = {}
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(targets, descendant)
		end
	end
	return targets
end

local function isSourceScopedFlag(flagName: string, defaults: any?): boolean
	return flagName == "Burn"
		or flagName == "Poison"
		or flagName == "Slow"
		or flagName == "PoisonTrap"
		or flagName == "LavaTrap"
		or (defaults and defaults.SourceScoped == true)
end

local function getSourceUserId(source: any?): number?
	return if typeof(source) == "Instance" and source:IsA("Player") then source.UserId else nil
end

local function getSourceId(source: any?, data: any?): string?
	if typeof(data) == "table" and typeof(data.SourceId) == "string" then
		return data.SourceId
	end
	if typeof(source) == "Instance" then
		if source:IsA("Player") then
			return `Player:{source.UserId}`
		end
		return `{source.ClassName}:{source:GetDebugId(0)}`
	end
	if type(source) == "string" then
		return source
	end
	return nil
end

local function getFlagKey(flagName: string, source: any?, data: any?, defaults: any?): string
	if isSourceScopedFlag(flagName, defaults) then
		local sourceId = getSourceId(source, data)
		if sourceId then
			return `{flagName}:{sourceId}`
		end
	end
	return flagName
end

local function copySnapshotData(target: any, data: any?)
	if type(data) ~= "table" then
		return
	end
	for key, value in pairs(data) do
		if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
			target[key] = value
		end
	end
end

local function buildFlagSnapshot(flags: { [string]: ActiveFlag }?): any
	local snapshot = {}
	if not flags then
		return snapshot
	end
	for _, flag in pairs(flags) do
		local flagName = flag.Name
		local existing = snapshot[flagName]
		if existing then
			existing.ExpiresAt = math.max(existing.ExpiresAt or 0, flag.ExpiresAt)
			existing.Stacks = (existing.Stacks or 0) + (flag.Stacks or 1)
			copySnapshotData(existing, flag.Data)
			if flag.Data and flag.Data.SlowAmount then
				existing.SlowAmount = math.max(existing.SlowAmount or 0, flag.Data.SlowAmount)
			end
			if flag.SourceId then
				existing.Sources = existing.Sources or {}
				existing.Sources[flag.SourceId] = {
					ExpiresAt = flag.ExpiresAt,
					Stacks = flag.Stacks,
				}
			end
		else
			snapshot[flagName] = {
				ExpiresAt = flag.ExpiresAt,
				Stacks = flag.Stacks,
			}
			copySnapshotData(snapshot[flagName], flag.Data)
			if flag.Data and flag.Data.SlowAmount then
				snapshot[flagName].SlowAmount = flag.Data.SlowAmount
			end
			if flag.SourceId then
				snapshot[flagName].Sources = {
					[flag.SourceId] = {
						ExpiresAt = flag.ExpiresAt,
						Stacks = flag.Stacks,
					},
				}
			end
		end
	end
	return snapshot
end

function FlagService.new(context)
	local self = setmetatable({}, FlagService)
	self._context = context
	self._activeFlags = {} :: { [Player]: { [string]: ActiveFlag } }
	self._flagVisuals = {} :: { [Player]: { [string]: FlagVisual } }
	return self
end

function FlagService:EnsurePlayer(player: Player)
	self._activeFlags[player] = self._activeFlags[player] or {}
	self._flagVisuals[player] = self._flagVisuals[player] or {}
	self:DisablePlayerStatusEffects(player)
end

function FlagService:ClearPlayer(player: Player)
	self:_clearFlagVisuals(player)
	self:DisablePlayerStatusEffects(player)
	self._activeFlags[player] = nil
	self._flagVisuals[player] = nil
end

function FlagService:ResetPlayer(player: Player): any
	self:_clearFlagVisuals(player)
	self._activeFlags[player] = {}
	self._flagVisuals[player] = {}
	self:DisablePlayerStatusEffects(player)
	return buildFlagSnapshot(self._activeFlags[player])
end

function FlagService:DisablePlayerStatusEffects(player: Player)
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local root = playerService and playerService:GetRoot(player)
	if root then
		setAllStatusEffectsEnabled(root, false)
	end
end

function FlagService:BuildSnapshot(player: Player): any
	return buildFlagSnapshot(self._activeFlags[player])
end

function FlagService:GetDefaults(flagName: string): any
	return getFlagDefaults(flagName)
end

function FlagService:_hasActiveEffect(player: Player, effectName: string, exceptFlagName: string?): boolean
	local flags = self._activeFlags[player]
	if not flags then
		return false
	end
	local now = os.clock()
	for _, flag in pairs(flags) do
		if flag.Name ~= exceptFlagName and flag.ExpiresAt > now then
			local activeEffectName = getConfiguredEffect(flag.Name, flag.Data)
			if activeEffectName == effectName then
				return true
			end
		end
	end
	return false
end

function FlagService:_removeFlagVisual(player: Player, flagName: string)
	local playerVisuals = self._flagVisuals[player]
	local visual = playerVisuals and playerVisuals[flagName]
	if not visual then
		return
	end

	if visual.EffectName and not self:_hasActiveEffect(player, visual.EffectName, flagName) then
		local playerService = ServiceResolver.Get(self._context, "PlayerService")
		local root = playerService and playerService:GetRoot(player)
		if root then
			setStatusEffectEnabled(root, visual.EffectName, false, visual.AttachmentName)
		end
	end
	for part, material in pairs(visual.Materials) do
		if part and part.Parent then
			part.Material = material
		end
	end
	playerVisuals[flagName] = nil
end

function FlagService:_clearFlagVisuals(player: Player)
	local playerVisuals = self._flagVisuals[player]
	if not playerVisuals then
		return
	end
	for flagName in pairs(playerVisuals) do
		self:_removeFlagVisual(player, flagName)
	end
end

function FlagService:_applyFlagVisual(player: Player, flagName: string, data: any?)
	local visualConfig = mergeVisualConfig(flagName, data)
	local effectName = visualConfig.Effect
	local attachmentName = visualConfig.Attachment
	local material = visualConfig.Material
	local materialTarget = visualConfig.MaterialTarget
	if not (effectName or material) then
		return
	end

	self:_removeFlagVisual(player, flagName)

	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local pawn = playerService and playerService:GetPawn(player)
	local root = playerService and playerService:GetRoot(player)
	if not (pawn and root) then
		return
	end

	local visual: FlagVisual = {
		EffectName = nil,
		AttachmentName = nil,
		Materials = {},
	}
	if isStatusEffectName(effectName) then
		local resolvedAttachmentName = if typeof(attachmentName) == "string" then attachmentName else StatusEffectVfx.GetDefaultAttachmentName(effectName)
		setStatusEffectEnabled(root, effectName, true, resolvedAttachmentName)
		visual.EffectName = effectName
		visual.AttachmentName = resolvedAttachmentName
	end
	if typeof(material) == "EnumItem" then
		for _, part in collectMaterialTargets(pawn, materialTarget) do
			visual.Materials[part] = part.Material
			part.Material = material
		end
	end
	if visual.EffectName or next(visual.Materials) ~= nil then
		local playerVisuals = self._flagVisuals[player]
		if not playerVisuals then
			playerVisuals = {}
			self._flagVisuals[player] = playerVisuals
		end
		playerVisuals[flagName] = visual
	end
end

function FlagService:HasFlag(player: Player, flagName: string): boolean
	local flags = self._activeFlags[player]
	if not flags then
		return false
	end
	for _, flag in pairs(flags) do
		if flag.Name == flagName and flag.ExpiresAt > os.clock() then
			return true
		end
	end
	return false
end

function FlagService:GetFlag(player: Player, flagName: string, source: any?, data: any?): ActiveFlag?
	local flags = self._activeFlags[player]
	if not flags then
		return nil
	end
	local newest: ActiveFlag? = nil
	local defaults = getFlagDefaults(flagName)
	local requestedKey = if source ~= nil then getFlagKey(flagName, source, data, defaults) else nil
	for flagKey, flag in pairs(flags) do
		if (not requestedKey or flagKey == requestedKey) and flag.Name == flagName and flag.ExpiresAt > os.clock() then
			if not newest or flag.ExpiresAt > newest.ExpiresAt then
				newest = flag
			end
		end
	end
	return newest
end

function FlagService:ApplyFlag(player: Player, flagName: string, duration: number?, source: any?, data: any?): boolean
	if flagName == "Burn" or flagName == "Poison" or flagName == "Stun" or flagName == "Petrify" then print(`[EQUIPMENT_ATTACK_TRACE][FlagService] ApplyFlag entered target={player.Name} flag={flagName} duration={tostring(duration)} source={getSourceId(source, data)}`) end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state then
		if flagName == "Burn" or flagName == "Poison" or flagName == "Stun" or flagName == "Petrify" then print(`[EQUIPMENT_ATTACK_TRACE][FlagService] ApplyFlag aborted target={player.Name} flag={flagName}: state missing`) end
		return false
	end
	if flagName == "Petrify" then
		local stunFlag = self:GetFlag(player, "Stun")
		if stunFlag then
			self:RemoveFlag(player, "Stun")
		end
	elseif flagName == "Stun" and self:HasFlag(player, "Petrify") then
		print(`[EQUIPMENT_ATTACK_TRACE][FlagService] ApplyFlag aborted target={player.Name} flag=Stun: Petrify already active`)
		return false
	end
	local defaults = getFlagDefaults(flagName)
	local resolvedDuration = math.max(0, duration or defaults.Duration or 0)
	if resolvedDuration <= 0 then
		if flagName == "Burn" or flagName == "Poison" or flagName == "Stun" or flagName == "Petrify" then print(`[EQUIPMENT_ATTACK_TRACE][FlagService] ApplyFlag aborted target={player.Name} flag={flagName}: resolvedDuration={resolvedDuration}`) end
		return false
	end
	local flags = self._activeFlags[player]
	if not flags then
		flags = {}
		self._activeFlags[player] = flags
	end
	local now = os.clock()
	local flagKey = getFlagKey(flagName, source, data, defaults)
	local existing = flags[flagKey]
	local maxStack = math.max(1, tonumber((data and data.MaxStack) or defaults.MaxStack) or 1)
	local stackable = (data and data.Stackable) == true or defaults.Stackable == true
	local sourceScoped = isSourceScopedFlag(flagName, defaults)
	local stacks = 1
	if existing and existing.ExpiresAt > now and stackable and not sourceScoped then
		stacks = math.clamp((existing.Stacks or 1) + 1, 1, maxStack)
	elseif existing and existing.ExpiresAt > now then
		stacks = existing.Stacks or 1
	end
	local expiresAt = if sourceScoped
		then now + resolvedDuration
		else math.max(existing and existing.ExpiresAt or 0, now + resolvedDuration)
	local sourceId = getSourceId(source, data)
	local initialHealTickAt = now
	local tickInterval = (data and data.TickInterval) or defaults.TickInterval
	if flagName == "HPRecovering" and tickInterval then
		initialHealTickAt = now - math.max(0, tonumber(tickInterval) or 0)
	end
	flags[flagKey] = {
		Name = flagName,
		ExpiresAt = expiresAt,
		Stacks = stacks,
		Source = source,
		SourceId = sourceId,
		SourceUserId = getSourceUserId(source),
		LastTickAt = now,
		LastHealTickAt = initialHealTickAt,
		LastDamageTickAt = now,
		Data = data,
	}
	self:_applyFlagVisual(player, flagName, data)
	if defaults.InterruptCharge or flagName == "Petrify" or flagName == "Stun" then
		state.IsCharging = false
		state.ChargeValue = 0
		state.StunnedUntil = math.max(state.StunnedUntil or 0, flags[flagKey].ExpiresAt)
		if state.MovementState ~= MOVEMENT_STATE.Knockback then
			state.MovementState = MOVEMENT_STATE.Idle
		end
	end
	if flagName == "Invisible" or flagName == "Ghost" then
		state.IsVisible = false
	end
	state.ActiveFlags = buildFlagSnapshot(flags)
	if flagName == "HPBoosted" then stateService:RecalculateDerivedStats(player, false) end
	stateService:PublishState(player)
	if flagName == "Burn" or flagName == "Poison" or flagName == "Stun" or flagName == "Petrify" then print(`[EQUIPMENT_ATTACK_TRACE][FlagService] ApplyFlag success target={player.Name} flag={flagName} stacks={stacks} expiresAt={expiresAt}`) end
	return true
end

function FlagService:RemoveFlag(player: Player, flagName: string, source: any?, data: any?)
	local flags = self._activeFlags[player]
	if flags then
		local defaults = getFlagDefaults(flagName)
		local requestedKey = if source ~= nil then getFlagKey(flagName, source, data, defaults) else nil
		for flagKey, flag in pairs(flags) do
			if flag.Name == flagName and (not requestedKey or flagKey == requestedKey) then
				flags[flagKey] = nil
			end
		end
	end
	self:_removeFlagVisual(player, flagName)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if state then
		if flagName == "Invisible" or flagName == "Ghost" then
			state.IsVisible = not self:HasFlag(player, "Invisible") and not self:HasFlag(player, "Ghost")
		end
		state.ActiveFlags = buildFlagSnapshot(flags)
		if flagName == "HPBoosted" then stateService:RecalculateDerivedStats(player, false) end
		stateService:PublishState(player)
	end
end

function FlagService:TickFlags(dt: number)
	local now = os.clock()
	-- RCA Fix D: inject a service-level round-state gate so DoT cannot bypass active-round rules.
	local roundService = ServiceResolver.Get(self._context, "RoundService")
	local roundState = roundService and roundService:GetState()
	local dotAllowed = roundState == GameStates.MapRoundState.EarlyGame or roundState == GameStates.MapRoundState.FinalPhase

	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	for player, flags in pairs(self._activeFlags) do
		if not flags or next(flags) == nil then
			continue
		end
		local state = stateService and stateService:GetState(player)
		if not state then
			continue
		end
		local changed = false
		for flagKey, flag in pairs(flags) do
			local flagName = flag.Name
			if flag.ExpiresAt <= now then
				flags[flagKey] = nil
				if not self:HasFlag(player, flagName) then
					self:_removeFlagVisual(player, flagName)
				end
				if flagName == "HPBoosted" and stateService then stateService:RecalculateDerivedStats(player, false) end
				changed = true
				continue
			end
			local defaults = getFlagDefaults(flagName)
			local tailDuration = (flag.Data and flag.Data.KnockbackTailDuration) or defaults.KnockbackTailDuration
			if tailDuration and state.MovementState == MOVEMENT_STATE.Knockback then
				local extendedExpiresAt = math.max(flag.ExpiresAt, now + math.max(0, tailDuration))
				if extendedExpiresAt > flag.ExpiresAt then
					local shouldPublishExtension = extendedExpiresAt - flag.ExpiresAt >= 0.25
					flag.ExpiresAt = extendedExpiresAt
					changed = changed or shouldPublishExtension
				end
			end
			local tickInterval = (flag.Data and flag.Data.TickInterval) or defaults.TickInterval
			local healPerTick = (flag.Data and flag.Data.HealPerTick) or defaults.HealPerTick
			if tickInterval and healPerTick then
				local lastHealTickAt = flag.LastHealTickAt or flag.LastTickAt or now
				if now - lastHealTickAt >= tickInterval then
					flag.LastHealTickAt = now
					if stateService then
						stateService:Heal(player, (tonumber(healPerTick) or 0) * math.max(1, flag.Stacks or 1), true)
					end
				end
			end
			local damagePerTick = (flag.Data and flag.Data.DamagePerTick) or defaults.DamagePerTick
			if tickInterval and damagePerTick and not self:HasFlag(player, "Invulnerable") and dotAllowed then
				local lastDamageTickAt = flag.LastDamageTickAt or flag.LastTickAt or now
				if now - lastDamageTickAt >= tickInterval then
					flag.LastDamageTickAt = now
					local damagePipeline = ServiceResolver.Get(self._context, "DamagePipelineService")
					local amount = 0
					if type(damagePerTick) == "table" and damagePerTick.Mode == "MaxHPPercent" then
						amount = math.max(tonumber(damagePerTick.Fallback) or 0, (state.MaxHP or 0) * math.max(0, tonumber(damagePerTick.Percent) or 0))
					else
						amount = (tonumber(damagePerTick) or 0) * math.max(1, flag.Stacks or 1)
					end
					if damagePipeline and typeof(damagePipeline.ApplyDoTDamage) == "function" then
						damagePipeline:ApplyDoTDamage(player, amount, flag.Source, flagName)
					elseif stateService then
						stateService:ApplyDamage(player, amount)
					end
				end
			end
		end
		state.IsVisible = not flags.Invisible and not flags.Ghost
		state.ActiveFlags = buildFlagSnapshot(flags)
		if changed then
			stateService:PublishState(player)
		end
	end
	local _ = dt
end

return FlagService
