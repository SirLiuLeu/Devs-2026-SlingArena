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
	Source: Player?,
	SourceUserId: number?,
	LastTickAt: number?,
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
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local emittersFolder = assetsFolder and assetsFolder:FindFirstChild("ParticleEmitters")
	local emitter = emittersFolder and emittersFolder:FindFirstChild(effectName)
	if emitter and emitter:IsA("ParticleEmitter") then
		return emitter
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

local function isSourceScopedDot(flagName: string): boolean
	return flagName == "Burn" or flagName == "Poison"
end

local function getSourceUserId(source: Player?): number?
	return source and source.UserId or nil
end

local function getFlagKey(flagName: string, source: Player?): string
	if isSourceScopedDot(flagName) then
		local sourceUserId = getSourceUserId(source)
		if sourceUserId then
			return string.format("%s:%d", flagName, sourceUserId)
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
		if existing then
			existing.ExpiresAt = math.max(existing.ExpiresAt or 0, flag.ExpiresAt)
			existing.Stacks = (existing.Stacks or 0) + (flag.Stacks or 1)
			if flag.SourceUserId then
				existing.Sources = existing.Sources or {}
				existing.Sources[tostring(flag.SourceUserId)] = {
					ExpiresAt = flag.ExpiresAt,
					Stacks = flag.Stacks,
				}
			end
		else
			snapshot[flagName] = {
				ExpiresAt = flag.ExpiresAt,
				Stacks = flag.Stacks,
			}
			if flag.SourceUserId then
				snapshot[flagName].Sources = {
					[tostring(flag.SourceUserId)] = {
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

function FlagService:ApplyFlag(player: Player, flagName: string, duration: number?, source: Player?, data: any?): boolean
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
	local stacks = 1
	if existing and existing.ExpiresAt > now and stackable and not isSourceScopedDot(flagName) then
		stacks = math.clamp((existing.Stacks or 1) + 1, 1, maxStack)
	elseif existing and existing.ExpiresAt > now then
		stacks = existing.Stacks or 1
	end
	local expiresAt = if isSourceScopedDot(flagName)
		then now + resolvedDuration
		else math.max(existing and existing.ExpiresAt or 0, now + resolvedDuration)
	flags[flagKey] = {
		Name = flagName,
		ExpiresAt = expiresAt,
		Stacks = stacks,
		Source = source,
		SourceUserId = getSourceUserId(source),
		LastTickAt = existing and existing.LastTickAt or now,
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
			if flag.ExpiresAt <= now then
				flags[flagKey] = nil
				if not self:HasFlag(player, flagName) then
					self:_removeFlagVisual(player, flagName)
				end
				changed = true
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
					local amount = damagePerTick * math.max(1, flag.Stacks or 1)
					if damagePipeline and typeof(damagePipeline.ApplyDamage) == "function" then
						damagePipeline:ApplyDamage(player, amount, flag.Source, nil, { SuppressKnockback = true })
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
