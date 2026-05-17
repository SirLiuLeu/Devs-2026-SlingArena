--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)
local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)

type PlayerState = PlayerStateTypes.PlayerState

local MOVEMENT_STATE = GameStates.PlayerState

type BuffState = {
	DamageBoost: number,
	HpBoost: number,
	ExpBoost: number,
	ChargeBoost: number,
	Active: boolean,
}

type ActiveFlag = {
	Name: string,
	ExpiresAt: number,
	Stacks: number,
	Source: Player?,
	LastTickAt: number?,
	Data: any?,
}

type FlagVisual = {
	Emitter: ParticleEmitter?,
	Materials: { [BasePart]: Enum.Material },
}

type Context = {
	EventBus: any,
	Remotes: Folder,
	Services: any?,
}

local PlayerStateService = {}
PlayerStateService.__index = PlayerStateService

function PlayerStateService.new(context: Context)
	local self = setmetatable({}, PlayerStateService)
	self._context = context
	self._states = {} :: { [Player]: PlayerState }
	self._buffs = {} :: { [Player]: BuffState }
	self._lastAttacker = {} :: { [Player]: Player }
	self._damageDealt = {} :: { [Player]: number }
	self._activeFlags = {} :: { [Player]: { [string]: ActiveFlag } }
	self._flagVisuals = {} :: { [Player]: { [string]: FlagVisual } }
	self._slingRuntime = {} :: { [Player]: any }
	self._stateUpdateRemote = context.Remotes:FindFirstChild("StateUpdate") :: RemoteEvent
	self._consumeHpPotionRemote = context.Remotes:FindFirstChild("ConsumeHpPotion") :: RemoteEvent?
	self._attributeUpgradeRemote = context.Remotes:FindFirstChild("AttributeUpgrade") :: RemoteEvent?
	return self
end

function PlayerStateService:ComputeSize(level: number): number
	return BalanceConfig.BaseSize + (math.max(level, 1) * BalanceConfig.LevelGrowthMultiplier)
end

function PlayerStateService:GetRequiredExp(level: number): number
	return LevelConfig.RequiredExp(level)
end

local function buildDefaultState(player: Player): PlayerState
	local sling = SlingshotConfig.SlingConfig
	local state: PlayerState = {
		UserId = player.UserId,
		CurrentMap = nil,
		LocationState = GameStates.SessionState.Lobby,
		TeamId = "TeamRed",
		Level = LevelConfig.StartingLevel,
		Exp = LevelConfig.StartingExp,
		Size = sling.Size,
		MaxHP = sling.MaxHP,
		CurrentHP = sling.MaxHP,
		BaseDamage = sling.BaseDamage,
		RegenRate = sling.RegenPerSecond,
		ReflectDamage = sling.ReflectDamagePercent,
		LaunchSpeed = PhysicsConfig.Launch.SpeedMax,
		LaunchRange = sling.MaxShootRange,
		ChargeSpeed = 1,
		MoveSpeed = PhysicsConfig.Movement.MoveSpeed,
		DamageMultiplier = 1,
		HPBonus = 0,
		LaunchSpeedBonus = 0,
		RegenBonus = 0,
		KnockbackResistance = 0,
		SlingshotType = "NormalSling",
		ChargeValue = 0,
		CurrentVelocity = Vector3.zero,
		InvulnerableUntil = 0,
		LastDamageTime = 0,
		InvulCooldownUntil = 0,
		Diamonds = LevelConfig.StartingDiamonds,
		HpPotions = BalanceConfig.DefaultHpPotions,
		NextHpPotionUseTime = 0,
		RespawnCountThisMatch = 0,
		AttributePoints = LevelConfig.StartingAttributePoints,
		DamageDealt = 0,
		IsTeleporting = false,
		CooldownEndTime = 0,
		LastReleaseDuration = 0,
		Attributes = {
			Damage = 0,
			MaxHP = 0,
			Regen = 0,
			Range = 0,
			Reflect = 0,
			LaunchSpeed = 0,
			ChargeSpeed = 0,
			MoveSpeed = 0,
		},
		IsAlive = true,
		IsCharging = false,
		MovementState = MOVEMENT_STATE.Idle,
		IsVisible = true,
		StunnedUntil = 0,
		ScaleMultiplier = 1,
		BonusMaxHP = 0,
		BonusDamageMultiplier = 0,
		LevelDamageBonus = 0,
		ActiveFlags = {},
		Armor = 0,
		ExpBonus = 0,
	}

	return state
end

function PlayerStateService:Init()
	if self._consumeHpPotionRemote then
		self._consumeHpPotionRemote.OnServerEvent:Connect(function(player: Player)
			self:TryConsumeHpPotion(player)
		end)
	end
	if self._attributeUpgradeRemote then
		self._attributeUpgradeRemote.OnServerEvent:Connect(function(player: Player, attributeName: string)
			self:TrySpendAttribute(player, attributeName)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self._damageDealt[player] = 0
		self._activeFlags[player] = {}
		self._flagVisuals[player] = {}
		self._slingRuntime[player] = {}
		self:RecalculateDerivedStats(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
		self._buffs[player] = nil
		self._lastAttacker[player] = nil
		self._damageDealt[player] = nil
		self:_clearFlagVisuals(player)
		self._activeFlags[player] = nil
		self._flagVisuals[player] = nil
		self._slingRuntime[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self._damageDealt[player] = 0
		self._activeFlags[player] = {}
		self._flagVisuals[player] = {}
		self._slingRuntime[player] = {}
		self:RecalculateDerivedStats(player, true)
	end
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

local function buildFlagSnapshot(flags: { [string]: ActiveFlag }?): any
	local snapshot = {}
	if not flags then
		return snapshot
	end
	for flagName, flag in pairs(flags) do
		snapshot[flagName] = {
			ExpiresAt = flag.ExpiresAt,
			Stacks = flag.Stacks,
		}
	end
	return snapshot
end

function PlayerStateService:_removeFlagVisual(player: Player, flagName: string)
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

function PlayerStateService:_clearFlagVisuals(player: Player)
	local playerVisuals = self._flagVisuals[player]
	if not playerVisuals then
		return
	end
	for flagName in pairs(playerVisuals) do
		self:_removeFlagVisual(player, flagName)
	end
end

function PlayerStateService:_applyFlagVisual(player: Player, flagName: string, data: any?)
	local effectName = data and data.Effect
	local material = data and data.Material
	if not (effectName or material) then
		return
	end

	self:_removeFlagVisual(player, flagName)

	local playerService = self._context.Services and self._context.Services.PlayerService
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

function PlayerStateService:HasFlag(player: Player, flagName: string): boolean
	local flags = self._activeFlags[player]
	local flag = flags and flags[flagName]
	if not flag then
		return false
	end
	return flag.ExpiresAt > os.clock()
end

function PlayerStateService:GetFlag(player: Player, flagName: string): ActiveFlag?
	local flags = self._activeFlags[player]
	local flag = flags and flags[flagName]
	if flag and flag.ExpiresAt > os.clock() then
		return flag
	end
	return nil
end

function PlayerStateService:ApplyFlag(player: Player, flagName: string, duration: number?, source: Player?, data: any?): boolean
	local state = self._states[player]
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
	local existing = flags[flagName]
	local maxStack = math.max(1, tonumber((data and data.MaxStack) or defaults.MaxStack) or 1)
	local stackable = (data and data.Stackable) == true or defaults.Stackable == true
	local stacks = 1
	if existing and existing.ExpiresAt > os.clock() and stackable then
		stacks = math.clamp((existing.Stacks or 1) + 1, 1, maxStack)
	elseif existing and existing.ExpiresAt > os.clock() then
		stacks = existing.Stacks or 1
	end
	flags[flagName] = {
		Name = flagName,
		ExpiresAt = math.max(existing and existing.ExpiresAt or 0, os.clock() + resolvedDuration),
		Stacks = stacks,
		Source = source,
		LastTickAt = existing and existing.LastTickAt or os.clock(),
		Data = data,
	}
	self:_applyFlagVisual(player, flagName, data)
	if defaults.InterruptCharge or flagName == "Petrify" or flagName == "Stun" then
		state.IsCharging = false
		state.ChargeValue = 0
		state.StunnedUntil = math.max(state.StunnedUntil or 0, flags[flagName].ExpiresAt)
		state.MovementState = MOVEMENT_STATE.Idle
	end
	if flagName == "Invisible" or flagName == "Ghost" then
		state.IsVisible = false
	end
	state.ActiveFlags = buildFlagSnapshot(flags)
	self:PublishState(player)
	return true
end

function PlayerStateService:RemoveFlag(player: Player, flagName: string)
	local flags = self._activeFlags[player]
	if flags then
		flags[flagName] = nil
	end
	self:_removeFlagVisual(player, flagName)
	local state = self._states[player]
	if state then
		if flagName == "Invisible" or flagName == "Ghost" then
			state.IsVisible = not self:HasFlag(player, "Invisible") and not self:HasFlag(player, "Ghost")
		end
		state.ActiveFlags = buildFlagSnapshot(flags) or {}
		self:PublishState(player)
	end
end

function PlayerStateService:IsStunned(player: Player): boolean
	local state = self._states[player]
	return (state ~= nil and (state.StunnedUntil or 0) > os.clock()) or self:HasFlag(player, "Stun") or self:HasFlag(player, "Petrify")
end

function PlayerStateService:IsFrozen(player: Player): boolean
	return self:HasFlag(player, "Petrify")
end

function PlayerStateService:IsGhost(player: Player): boolean
	return self:HasFlag(player, "Ghost")
end

function PlayerStateService:ApplyStun(player: Player, duration: number)
	self:ApplyFlag(player, "Stun", duration)
end

function PlayerStateService:SetVisibility(player: Player, visible: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	if visible then
		self:RemoveFlag(player, "Invisible")
	else
		self:ApplyFlag(player, "Invisible", getFlagDefaults("Invisible").Duration or 1)
	end
end

function PlayerStateService:GetState(player: Player): PlayerState?
	return self._states[player]
end

function PlayerStateService:GetAllStates(): { [Player]: PlayerState }
	return self._states
end

function PlayerStateService:RecalculateDerivedStats(player: Player, refillHealth: boolean?)
	local state = self._states[player]
	if not state then
		return
	end
	local sling = SlingshotConfig.SlingConfig
	local equippedSling = SlingConfig.GetById(state.SlingshotType or "")
	local abilityConfig = equippedSling and AbilityConfig.GetById(equippedSling.abilityType or equippedSling.id) or nil
	local levelMultiplier = 1 + (math.max(state.Level - 1, 0) * 0.03)
	local slingStats = equippedSling and equippedSling.stats or {}
	state.HPBonus = 0
	state.RegenBonus = 0
	state.LaunchSpeedBonus = 0

	state.Size = (BalanceConfig.BaseSize * levelMultiplier) * state.ScaleMultiplier
	state.BaseDamage = (slingStats.baseDamage or sling.BaseDamage) * levelMultiplier
	state.DamageMultiplier = abilityConfig and abilityConfig.damageMultiplier or 1
	state.RegenRate = sling.RegenPerSecond * (slingStats.regen or 1) * (abilityConfig and abilityConfig.regenMultiplier or 1) * levelMultiplier
	state.ReflectDamage = math.max(sling.ReflectDamagePercent, abilityConfig and abilityConfig.reflectDamage or 0)
	state.LaunchSpeed = PhysicsConfig.Launch.SpeedMax * (slingStats.launchPower or 1) * levelMultiplier
	state.LaunchRange = sling.MaxShootRange * (slingStats.control or 1) * levelMultiplier
	state.ChargeSpeed = 1
	state.MoveSpeed = PhysicsConfig.Movement.MoveSpeed * (abilityConfig and abilityConfig.moveSpeedMultiplier or 1) * levelMultiplier
	state.Armor = math.clamp((slingStats.armor or 0) + (abilityConfig and abilityConfig.armor or 0), 0, 0.8)
	state.ExpBonus = abilityConfig and abilityConfig.expBonus or 0

	local hp = (slingStats.maxHP or sling.MaxHP) * (abilityConfig and abilityConfig.maxHpMultiplier or 1) * levelMultiplier
	state.MaxHP = hp
	if refillHealth then
		state.CurrentHP = hp
	else
		state.CurrentHP = math.clamp(state.CurrentHP, 0, hp)
	end
	self:PublishState(player)
end

function PlayerStateService:GetFinalStats(player: Player)
	local state = self._states[player]
	if not state then
		return nil
	end
	local sling = SlingshotConfig.SlingConfig
	return {
		Damage = state.BaseDamage * (state.DamageMultiplier or 1),
		HP = state.MaxHP,
		Regen = state.RegenRate,
		Range = state.LaunchRange,
		Reflect = state.ReflectDamage,
		Armor = state.Armor or 0,
		ExpBonus = state.ExpBonus or 0,
	}
end

function PlayerStateService:AddDamageDealt(player: Player, amount: number)
	self._damageDealt[player] = (self._damageDealt[player] or 0) + math.max(amount, 0)
	local state = self._states[player]
	if state then
		state.DamageDealt = self._damageDealt[player]
		self:PublishState(player)
	end
end

function PlayerStateService:GetDamageDealt(player: Player): number
	return self._damageDealt[player] or 0
end

function PlayerStateService:SetAlive(player: Player, alive: boolean)
	local state = self._states[player]
	if not state then return end
	state.IsAlive = alive
	self:PublishState(player)
end

function PlayerStateService:SetCurrentMap(player: Player, mapName: string)
	local state = self._states[player]
	if not state then return end
	state.CurrentMap = mapName
	self:PublishState(player)
end

function PlayerStateService:SetLocationState(player: Player, arenaStatus: string)
	local state = self._states[player]
	if not state then return end
	state.LocationState = arenaStatus
	self:PublishState(player)
end

function PlayerStateService:SetTeamId(player: Player, teamId: string)
	local state = self._states[player]
	if not state then
		return
	end
	state.TeamId = teamId
	self:PublishState(player)
end

function PlayerStateService:SetTeleporting(player: Player, isTeleporting: boolean)
	local state = self._states[player]
	if not state then return end
	state.IsTeleporting = isTeleporting
	self:PublishState(player)
end

function PlayerStateService:ApplyDamage(player: Player, amount: number): boolean
	local state = self._states[player]
	if not state or not state.IsAlive or self:IsInvulnerable(player) or self:HasFlag(player, "Ghost") then return false end
	local before = state.CurrentHP
	state.CurrentHP = math.max(0, state.CurrentHP - math.max(0, amount))
	local playerService = self._context.Services and self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	if root and state.CurrentHP ~= before then
		playerService:ShowFloatingHpChange(root, state.CurrentHP - before)
	end
	state.LastDamageTime = os.clock()
	self:PublishState(player)
	return true
end

function PlayerStateService:Heal(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	local before = state.CurrentHP
	state.CurrentHP = math.min(state.MaxHP, state.CurrentHP + math.max(0, amount))
	local playerService = self._context.Services and self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	if root and state.CurrentHP ~= before then
		playerService:ShowFloatingHpChange(root, state.CurrentHP - before)
	end
	self:PublishState(player)
end

function PlayerStateService:TryConsumeHpPotion(player: Player): (boolean, string?)
	local state = self._states[player]
	if not state then
		return false, "MissingState"
	end

	local now = os.clock()
	if (state.HpPotions or 0) <= 0 then
		return false, "NoPotion"
	end
	if now < (state.NextHpPotionUseTime or 0) then
		return false, "Cooldown"
	end
	if (state.CurrentHP or 0) >= (state.MaxHP or 0) then
		return false, "AlreadyFull"
	end

	state.HpPotions = math.max(0, (state.HpPotions or 0) - 1)
	state.NextHpPotionUseTime = now + BalanceConfig.HpPotionCooldown
	self:Heal(player, BalanceConfig.HpPotionHealAmount)
	return true, nil
end

function PlayerStateService:MarkInvulnerable(player: Player, duration: number)
	local state = self._states[player]
	if not state then return end
	state.InvulnerableUntil = os.clock() + duration
end

function PlayerStateService:IsInvulnerable(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and (state.InvulnerableUntil > os.clock() or self:HasFlag(player, "Invulnerable"))
end

function PlayerStateService:GrantExp(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	local expBonus = 1 + math.max(0, state.ExpBonus or 0)
	state.Exp += math.max(0, amount) * expBonus
	while state.Level < LevelConfig.MaxLevel do
		local requiredExp = self:GetRequiredExp(state.Level)
		if state.Exp < requiredExp then break end
		state.Exp -= requiredExp
		state.Level += 1
		state.AttributePoints += 1
		self._context.EventBus:Fire("LevelUp", player, state.Level)
	end
	self:PublishState(player)
end

function PlayerStateService:AddGrowth(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	state.Size = math.max(0.5, state.Size + math.max(0, amount))
	self:PublishState(player)
end

function PlayerStateService:TryApplyExpPenalty(player: Player, penalty: number): boolean
	local state = self._states[player]
	if not state then return false end
	state.Exp = math.max(0, state.Exp - math.max(0, penalty))
	self:PublishState(player)
	return true
end

function PlayerStateService:ResetForNewRound(player: Player)
	local state = self._states[player]
	if not state then return end
	state.IsAlive = true
	state.IsCharging = false
	state.MovementState = MOVEMENT_STATE.Idle
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	state.CooldownEndTime = 0
	state.LastReleaseDuration = 0
	self._damageDealt[player] = 0
	state.DamageDealt = 0
	self:_clearFlagVisuals(player)
	self._activeFlags[player] = {}
	self._slingRuntime[player] = {}
	state.ActiveFlags = buildFlagSnapshot(self._activeFlags[player])
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:ResetForRespawn(player: Player)
	local state = self._states[player]
	if not state then return end
	state.IsAlive = true
	state.IsCharging = false
	state.MovementState = MOVEMENT_STATE.Idle
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	state.CooldownEndTime = 0
	state.LastReleaseDuration = 0
	self:_clearFlagVisuals(player)
	self._activeFlags[player] = {}
	self._slingRuntime[player] = {}
	state.ActiveFlags = buildFlagSnapshot(self._activeFlags[player])
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:PublishState(player: Player)
	local state = self._states[player]
	if self._stateUpdateRemote and state then
		self._stateUpdateRemote:FireClient(player, state)
	end
	if state then
		self._context.EventBus:Fire("PlayerStateUpdated", player, state)
	end
end

function PlayerStateService:SetCharging(player: Player, isCharging: boolean, chargeValue: number)
	local state = self._states[player]
	if not state then return end
	state.IsCharging = isCharging
	state.ChargeValue = math.clamp(chargeValue, 0, 1)
	self:PublishState(player)
end


function PlayerStateService:SetMovementState(player: Player, movementState: string)
	local state = self._states[player]
	if not state then return end
	state.MovementState = movementState
	self:PublishState(player)
end

function PlayerStateService:SetCooldownEndTime(player: Player, cooldownEndTime: number)
	local state = self._states[player]
	if not state then return end
	state.CooldownEndTime = math.max(cooldownEndTime, 0)
	self:PublishState(player)
end

function PlayerStateService:SetLastReleaseDuration(player: Player, duration: number)
	local state = self._states[player]
	if not state then return end
	state.LastReleaseDuration = math.max(duration, 0)
	self:PublishState(player)
end

function PlayerStateService:ApplyLevelGrowth(player: Player)
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:GetBuff(player: Player): BuffState?
	return self._buffs[player]
end

function PlayerStateService:TrySpendAttribute(player: Player, attributeName: string): boolean
	local _ = attributeName
	local state = self._states[player]
	if not state then
		return false
	end
	return false
end

function PlayerStateService:SpendDiamonds(player: Player, amount: number): boolean
	local state = self._states[player]
	if not state then return false end
	local cost = math.max(0, amount)
	if state.Diamonds < cost then return false end
	state.Diamonds -= cost
	self:PublishState(player)
	return true
end

function PlayerStateService:ApplyMatchBuff(player: Player)
	self:PublishState(player)
end

function PlayerStateService:PrestigeReset(player: Player)
	self:PublishState(player)
end

function PlayerStateService:SetLastAttacker(victim: Player, attacker: Player)
	self._lastAttacker[victim] = attacker
end
function PlayerStateService:GetLastAttacker(victim: Player): Player?
	return self._lastAttacker[victim]
end
function PlayerStateService:ClearLastAttacker(victim: Player)
	self._lastAttacker[victim] = nil
end

function PlayerStateService:SetSlingType(player: Player, slingId: string): boolean
	local state = self._states[player]
	if not state or not SlingConfig.GetById(slingId) then
		return false
	end
	state.SlingshotType = slingId
	self._slingRuntime[player] = {}
	self:RecalculateDerivedStats(player, true)
	return true
end

function PlayerStateService:GetSlingAbilityType(player: Player): string
	local state = self._states[player]
	local sling = state and SlingConfig.GetById(state.SlingshotType or "")
	return (sling and (sling.abilityType or sling.id)) or "NormalSling"
end

function PlayerStateService:GetSlingRuntime(player: Player): any
	local runtime = self._slingRuntime[player]
	if not runtime then
		runtime = {}
		self._slingRuntime[player] = runtime
	end
	return runtime
end

function PlayerStateService:TickFlags(dt: number)
	local now = os.clock()
	for player, flags in pairs(self._activeFlags) do
		local state = self._states[player]
		if not state then
			continue
		end
		local changed = false
		for flagName, flag in pairs(flags) do
			if flag.ExpiresAt <= now then
				flags[flagName] = nil
				self:_removeFlagVisual(player, flagName)
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
					local damagePipeline = self._context.Services and self._context.Services.DamagePipelineService
					local amount = damagePerTick * math.max(1, flag.Stacks or 1)
					if damagePipeline and typeof(damagePipeline.ApplyDamage) == "function" then
						damagePipeline:ApplyDamage(player, amount, flag.Source, nil, { SuppressKnockback = true })
					else
						self:ApplyDamage(player, amount)
					end
				end
			end
		end
		state.IsVisible = not flags.Invisible and not flags.Ghost
		state.ActiveFlags = buildFlagSnapshot(flags)
		if changed then
			self:PublishState(player)
		end
	end
	local _ = dt
end

return PlayerStateService
