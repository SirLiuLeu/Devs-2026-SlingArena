--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)

local MOVEMENT_STATE = GameStates.PlayerState

local FlagService = {}
FlagService.__index = FlagService

type ActiveFlag = {
	Name: string,
	ExpiresAt: number,
	Stacks: number,
	Source: any?,
	SourceKey: string?,
	SourceUserId: number?,
	LastTickAt: number?,
	ActiveAt: number?,
	PendingStateExit: string?,
	Data: any?,
}

type FlagVisual = {
	Emitter: ParticleEmitter?,
	Materials: { [BasePart]: Enum.Material },
}

local function getService(context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function getFlagDefaults(flagName: string): any
	return GameConfig.FlagConfig[flagName] or {}
end

local function getParticleEmitter(effectName: string): ParticleEmitter?
	local resolvedEffectName = if effectName == "Burn" then "Fire" else effectName
	for _, assetFolderName in ipairs({ "Assetts", "Assets" }) do
		local assetsFolder = ReplicatedStorage:FindFirstChild(assetFolderName)
		local emittersFolder = assetsFolder and assetsFolder:FindFirstChild("ParticleEmitters")
		local emitter = emittersFolder and emittersFolder:FindFirstChild(resolvedEffectName)
		if emitter and emitter:IsA("ParticleEmitter") then
			return emitter
		end
	end
	return nil
end

local function getEffectAttachment(root: BasePart, effectName: string): Attachment?
	local attachmentName = if effectName == "Stun" then "EffectHead" else "EffectOrigin"
	local attachment = root:FindFirstChild(attachmentName)
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	return nil
end

local function isSourceScopedEffect(flagName: string): boolean
	return flagName == "Burn" or flagName == "Poison" or flagName == "PoisonTrap" or flagName == "LavaTrap" or flagName == "Slow"
end

local function getSourceUserId(source: any?): number?
	return if typeof(source) == "Instance" and source:IsA("Player") then source.UserId else nil
end

local function getSourceKey(source: any?): string?
	local sourceUserId = getSourceUserId(source)
	if sourceUserId then
		return tostring(sourceUserId)
	end
	if typeof(source) == "Instance" then
		return source:GetDebugId(0)
	end
	if source ~= nil then
		return tostring(source)
	end
	return nil
end

local function getFlagKey(flagName: string, source: any?): string
	if isSourceScopedEffect(flagName) then
		local sourceKey = getSourceKey(source)
		if sourceKey then
			return string.format("%s:%s", flagName, sourceKey)
		end
	end
	return flagName
end

local function buildFlagSnapshot(flags: { [string]: ActiveFlag }?): any
	local snapshot = {}
	if not flags then
		return snapshot
	end
	for _, flag in pairs(flags) do
		local flagName = flag.Name
		local existing = snapshot[flagName]
		local slowAmount = flag.Data and flag.Data.SlowAmount
		if existing then
			existing.ExpiresAt = math.max(existing.ExpiresAt or 0, flag.ExpiresAt)
			existing.Stacks = (existing.Stacks or 0) + (flag.Stacks or 1)
			if slowAmount then
				existing.SlowAmount = math.max(existing.SlowAmount or 0, slowAmount)
			end
		else
			snapshot[flagName] = {
				ExpiresAt = flag.ExpiresAt,
				Stacks = flag.Stacks,
			}
			if slowAmount then
				snapshot[flagName].SlowAmount = slowAmount
			end
			existing = snapshot[flagName]
		end
		if flag.SourceKey then
			existing.Sources = existing.Sources or {}
			existing.Sources[flag.SourceKey] = {
				ExpiresAt = flag.ExpiresAt,
				Stacks = flag.Stacks,
			}
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
end

function FlagService:ClearPlayer(player: Player)
	self:_clearFlagVisuals(player)
	self._activeFlags[player] = nil
	self._flagVisuals[player] = nil
end

function FlagService:ResetPlayer(player: Player): any
	self:_clearFlagVisuals(player)
	self._activeFlags[player] = {}
	self._flagVisuals[player] = {}
	return buildFlagSnapshot(self._activeFlags[player])
end

function FlagService:BuildSnapshot(player: Player): any
	return buildFlagSnapshot(self._activeFlags[player])
end

function FlagService:GetDefaults(flagName: string): any
	return getFlagDefaults(flagName)
end

function FlagService:_removeFlagVisual(player: Player, flagName: string)
	local playerVisuals = self._flagVisuals[player]
	local visual = playerVisuals and playerVisuals[flagName]
	if not visual then
		return
	end
	if visual.Emitter then
		visual.Emitter:Destroy()
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
	local effectName = data and data.Effect
	local material = data and data.Material
	if not (effectName or material) then
		return
	end

	self:_removeFlagVisual(player, flagName)

	local playerService = getService(self._context, "PlayerService")
	local pawn = playerService and playerService:GetPawn(player)
	local root = playerService and playerService:GetRoot(player)
	if not (pawn and root) then
		return
	end

	local visual: FlagVisual = {
		Emitter = nil,
		Materials = {},
	}
	if typeof(effectName) == "string" then
		local emitterTemplate = getParticleEmitter(effectName)
		local attachment = getEffectAttachment(root, effectName)
		if emitterTemplate and attachment then
			local emitter = emitterTemplate:Clone()
			emitter.Name = flagName .. "Effect"
			emitter.Parent = attachment
			visual.Emitter = emitter
		end
	end
	if typeof(material) == "EnumItem" then
		for _, descendant in pawn:GetDescendants() do
			if descendant:IsA("BasePart") then
				visual.Materials[descendant] = descendant.Material
				descendant.Material = material
			end
		end
	end
	if visual.Emitter or next(visual.Materials) ~= nil then
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

function FlagService:GetFlag(player: Player, flagName: string): ActiveFlag?
	local flags = self._activeFlags[player]
	if not flags then
		return nil
	end
	local newest: ActiveFlag? = nil
	for _, flag in pairs(flags) do
		if flag.Name == flagName and flag.ExpiresAt > os.clock() then
			if not newest or flag.ExpiresAt > newest.ExpiresAt then
				newest = flag
			end
		end
	end
	return newest
end

function FlagService:ApplyFlag(player: Player, flagName: string, duration: number?, source: any?, data: any?): boolean
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state then
		return false
	end
	if flagName == "Petrify" then
		local stunFlag = self:GetFlag(player, "Stun")
		if stunFlag then
			self:RemoveFlag(player, "Stun")
		end
	elseif flagName == "Stun" and self:HasFlag(player, "Petrify") then
		return false
	end
	local defaults = getFlagDefaults(flagName)
	local resolvedDuration = math.max(0, duration or defaults.Duration or 0)
	if resolvedDuration <= 0 then
		return false
	end
	local flags = self._activeFlags[player]
	if not flags then
		flags = {}
		self._activeFlags[player] = flags
	end
	local now = os.clock()
	local flagKey = getFlagKey(flagName, source)
	local existing = flags[flagKey]
	local maxStack = math.max(1, tonumber((data and data.MaxStack) or defaults.MaxStack) or 1)
	local stackable = (data and data.Stackable) == true or defaults.Stackable == true
	local refreshOnly = (data and data.RefreshOnly) == true or defaults.RefreshOnly == true or isSourceScopedEffect(flagName)
	local stacks = 1
	if existing and existing.ExpiresAt > now and stackable and not refreshOnly then
		stacks = math.clamp((existing.Stacks or 1) + 1, 1, maxStack)
	elseif existing and existing.ExpiresAt > now then
		stacks = existing.Stacks or 1
	end
	local pendingStateExit = data and data.DelayUntilStateExit
	local isPending = typeof(pendingStateExit) == "string" and state.MovementState == pendingStateExit
	local activeAt = if isPending then nil else (existing and existing.ActiveAt) or now
	local expiresAt = now + resolvedDuration
	flags[flagKey] = {
		Name = flagName,
		ExpiresAt = expiresAt,
		Stacks = stacks,
		Source = source,
		SourceKey = getSourceKey(source),
		SourceUserId = getSourceUserId(source),
		LastTickAt = if data and data.ImmediateTick then now - math.max(0, (data and data.TickInterval) or defaults.TickInterval or 0) else now,
		ActiveAt = activeAt,
		PendingStateExit = if isPending then pendingStateExit else nil,
		Data = data,
	}
	self:_applyFlagVisual(player, flagName, data)
	if defaults.InterruptCharge or flagName == "Petrify" or flagName == "Stun" then
		state.IsCharging = false
		state.ChargeValue = 0
		state.StunnedUntil = math.max(state.StunnedUntil or 0, flags[flagKey].ExpiresAt)
		state.MovementState = MOVEMENT_STATE.Idle
	end
	if flagName == "Invisible" or flagName == "Ghost" then
		state.IsVisible = false
	end
	state.ActiveFlags = buildFlagSnapshot(flags)
	stateService:PublishState(player)
	return true
end

function FlagService:RemoveFlag(player: Player, flagName: string)
	local flags = self._activeFlags[player]
	if flags then
		for flagKey, flag in pairs(flags) do
			if flag.Name == flagName then
				flags[flagKey] = nil
			end
		end
	end
	self:_removeFlagVisual(player, flagName)
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if state then
		if flagName == "Invisible" or flagName == "Ghost" then
			state.IsVisible = not self:HasFlag(player, "Invisible") and not self:HasFlag(player, "Ghost")
		end
		state.ActiveFlags = buildFlagSnapshot(flags)
		stateService:PublishState(player)
	end
end

function FlagService:_resolveDamagePerTick(player: Player, damagePerTick: any): number
	if typeof(damagePerTick) == "number" then
		return math.max(0, damagePerTick)
	end
	if type(damagePerTick) == "table" and damagePerTick.Mode == "MaxHPPercent" then
		local stateService = getService(self._context, "PlayerStateService")
		local state = stateService and stateService:GetState(player)
		local maxHp = state and tonumber(state.MaxHP) or nil
		if maxHp and maxHp > 0 then
			return math.max(0, maxHp * math.max(0, tonumber(damagePerTick.Percent) or 0))
		end
		return math.max(0, tonumber(damagePerTick.Fallback) or 0)
	end
	return 0
end

function FlagService:TickFlags(dt: number)
	local now = os.clock()
	for player, flags in pairs(self._activeFlags) do
		local stateService = getService(self._context, "PlayerStateService")
		local state = stateService and stateService:GetState(player)
		if not state then
			continue
		end
		local changed = false
		for flagKey, flag in pairs(flags) do
			local flagName = flag.Name
			if flag.PendingStateExit and state.MovementState ~= flag.PendingStateExit then
				local defaults = getFlagDefaults(flagName)
				local duration = (flag.Data and flag.Data.Duration) or defaults.Duration or math.max(0, flag.ExpiresAt - now)
				flag.ActiveAt = now
				flag.ExpiresAt = now + duration
				flag.LastTickAt = now
				flag.PendingStateExit = nil
				changed = true
			end
			if flag.ActiveAt and flag.ExpiresAt <= now then
				flags[flagKey] = nil
				if not self:HasFlag(player, flagName) then
					self:_removeFlagVisual(player, flagName)
				end
				changed = true
				continue
			end
			if not flag.ActiveAt then
				continue
			end
			local defaults = getFlagDefaults(flagName)
			local tickInterval = (flag.Data and flag.Data.TickInterval) or defaults.TickInterval
			local damagePerTick = (flag.Data and flag.Data.DamagePerTick) or defaults.DamagePerTick
			if tickInterval and damagePerTick and not self:HasFlag(player, "Invulnerable") then
				local lastTickAt = flag.LastTickAt or now
				if now - lastTickAt >= tickInterval then
					flag.LastTickAt = now
					local damagePipeline = getService(self._context, "DamagePipelineService")
					local amount = self:_resolveDamagePerTick(player, damagePerTick) * math.max(1, flag.Stacks or 1)
					if damagePipeline and typeof(damagePipeline.ApplyDoTDamage) == "function" then
						damagePipeline:ApplyDoTDamage(player, amount, flag.Source, { SuppressKnockback = true })
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
