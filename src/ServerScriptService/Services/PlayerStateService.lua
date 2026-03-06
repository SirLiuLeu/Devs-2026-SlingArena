--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)

type PlayerState = PlayerStateTypes.PlayerState

local MOVEMENT_STATE = {
	Idle = "Idle",
	Moving = "Moving",
	Charging = "Charging",
	Launched = "Launched",
	Recovering = "Recovering",
}

type BuffState = {
	DamageBoost: number,
	HpBoost: number,
	ExpBoost: number,
	ChargeBoost: number,
	Active: boolean,
}

type Context = {
	EventBus: any,
	Remotes: Folder,
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
	self._stateUpdateRemote = context.Remotes:FindFirstChild("StateUpdate") :: RemoteEvent
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
		MapName = "LobbyMap",
		ArenaStatus = "Lobby",
		Level = LevelConfig.StartingLevel,
		Exp = LevelConfig.StartingExp,
		Size = sling.Size,
		MaxHP = sling.MaxHP,
		CurrentHP = sling.MaxHP,
		BaseDamage = sling.BaseDamage,
		DamageMultiplier = 1,
		KnockbackResistance = 0,
		SlingshotType = "Default",
		ChargeValue = 0,
		CurrentVelocity = Vector3.zero,
		InvulnerableUntil = 0,
		InvulCooldownUntil = 0,
		Diamonds = LevelConfig.StartingDiamonds,
		RespawnCountThisMatch = 0,
		AttributePoints = LevelConfig.StartingAttributePoints,
		DamageDealt = 0,
		IsTeleporting = false,
		Attributes = {
			Damage = 0,
			MaxHP = 0,
			Regen = 0,
			Range = 0,
			Reflect = 0,
		},
		IsAlive = true,
		IsCharging = false,
		MovementState = MOVEMENT_STATE.Idle,
		ScaleMultiplier = 1,
		BonusMaxHP = 0,
		BonusDamageMultiplier = 0,
		LevelDamageBonus = 0,
	}
	return state
end

function PlayerStateService:Init()
	Players.PlayerAdded:Connect(function(player)
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self._damageDealt[player] = 0
		self:RecalculateDerivedStats(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
		self._buffs[player] = nil
		self._lastAttacker[player] = nil
		self._damageDealt[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self._damageDealt[player] = 0
		self:RecalculateDerivedStats(player, true)
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
	local baseSizeFromLevel = BalanceConfig.BaseSize * (1 + (math.sqrt(math.max(state.Level, 1)) * BalanceConfig.SizeSqrtMultiplier))
	if state.Level > 30 then
		local extraFromPost30 = baseSizeFromLevel - (BalanceConfig.BaseSize * (1 + (math.sqrt(30) * BalanceConfig.SizeSqrtMultiplier)))
		baseSizeFromLevel = (BalanceConfig.BaseSize * (1 + (math.sqrt(30) * BalanceConfig.SizeSqrtMultiplier))) + (extraFromPost30 * BalanceConfig.PostLevel30SizeScalar)
	end
	state.Size = (baseSizeFromLevel + (state.Attributes.Range * 0.02)) * state.ScaleMultiplier
	state.BaseDamage = sling.BaseDamage + state.LevelDamageBonus + (state.Attributes.Damage * 3)
	local hp = sling.MaxHP + (state.Attributes.MaxHP * 20) + state.BonusMaxHP
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
		Damage = state.BaseDamage,
		HP = state.MaxHP,
		Regen = sling.RegenPerSecond + state.Attributes.Regen,
		Range = sling.MaxShootRange + (state.Attributes.Range * 10),
		Reflect = sling.ReflectDamagePercent + (state.Attributes.Reflect * 0.01),
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

function PlayerStateService:SetMapName(player: Player, mapName: string)
	local state = self._states[player]
	if not state then return end
	state.MapName = mapName
	self:PublishState(player)
end

function PlayerStateService:SetArenaStatus(player: Player, arenaStatus: string)
	local state = self._states[player]
	if not state then return end
	state.ArenaStatus = arenaStatus
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
	if not state or not state.IsAlive then return false end
	state.CurrentHP = math.max(0, state.CurrentHP - math.max(0, amount))
	self:PublishState(player)
	return true
end

function PlayerStateService:Heal(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	state.CurrentHP = math.min(state.MaxHP, state.CurrentHP + math.max(0, amount))
	self:PublishState(player)
end

function PlayerStateService:MarkInvulnerable(player: Player, duration: number)
	local state = self._states[player]
	if not state then return end
	state.InvulnerableUntil = os.clock() + duration
end

function PlayerStateService:IsInvulnerable(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and state.InvulnerableUntil > os.clock()
end

function PlayerStateService:GrantExp(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	state.Exp += math.max(0, amount)
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
	self._damageDealt[player] = 0
	state.DamageDealt = 0
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
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:PublishState(player: Player)
	local state = self._states[player]
	if self._stateUpdateRemote and state then
		self._stateUpdateRemote:FireClient(player, state)
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

function PlayerStateService:ApplyLevelGrowth(player: Player)
	local state = self._states[player]
	if not state then return end
	state.ScaleMultiplier += 0.01
	state.BonusMaxHP += 10
	local perLevelDamage = math.random(BalanceConfig.DamageLevelBonusMin, BalanceConfig.DamageLevelBonusMax)
	state.LevelDamageBonus = math.clamp((state.LevelDamageBonus or 0) + perLevelDamage, 0, BalanceConfig.DamageLevelBonusCap)
	state.BonusDamageMultiplier += 0.01
	state.DamageMultiplier = 1 + state.BonusDamageMultiplier
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:GetBuff(player: Player): BuffState?
	return self._buffs[player]
end

function PlayerStateService:TrySpendAttribute(player: Player, attributeName: string): boolean
	local state = self._states[player]
	if not state or state.AttributePoints <= 0 then return false end
	if state.Attributes[attributeName] == nil then return false end
	state.AttributePoints -= 1
	state.Attributes[attributeName] += 1
	self:RecalculateDerivedStats(player, false)
	return true
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
	local state = self._states[player]
	if not state then return end
	state.BonusDamageMultiplier += BalanceConfig.MatchBuffMaxBoost
	state.BonusMaxHP += math.floor((SlingshotConfig.SlingConfig.MaxHP or BalanceConfig.BaseHP) * BalanceConfig.MatchBuffMaxBoost)
	self:RecalculateDerivedStats(player, false)
end

function PlayerStateService:PrestigeReset(player: Player)
	local state = self._states[player]
	if not state then return end
	local reward = math.floor(math.max(state.Level, 0) / BalanceConfig.DiamondsPerPrestigeLevelDivisor)
	state.Diamonds += reward
	state.Level = 1
	state.Exp = 0
	state.AttributePoints = 0
	state.ScaleMultiplier = 1
	state.BonusMaxHP = 0
	state.BonusDamageMultiplier = 0
	state.LevelDamageBonus = 0
	state.Attributes = {
		Damage = 0,
		MaxHP = 0,
		Regen = 0,
		Range = 0,
		Reflect = 0,
	}
	self:RecalculateDerivedStats(player, true)
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

return PlayerStateService
