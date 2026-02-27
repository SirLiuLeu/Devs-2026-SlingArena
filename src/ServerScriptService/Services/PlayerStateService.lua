--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)

type PlayerState = PlayerStateTypes.PlayerState

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
	self._stateUpdateRemote = context.Remotes:FindFirstChild("StateUpdate") :: RemoteEvent
	return self
end

-- Domain ownership: all level/exp/size math is centralized in PlayerStateService.
function PlayerStateService:ComputeSize(level: number): number
	return BalanceConfig.BaseSize + (math.max(level, 1) * BalanceConfig.LevelGrowthMultiplier)
end

function PlayerStateService:GetRequiredExp(level: number): number
	return LevelConfig.RequiredExp(level)
end

local function computeMaxHp(state: PlayerState, hpBuff: number): number
	local hpFromAttr = math.min(state.Attributes.HPBonus * 0.015, BalanceConfig.MaxHpBonusFromAttributes)
	return BalanceConfig.BaseHP * state.Size * (1 + hpFromAttr + hpBuff)
end

local function buildDefaultState(player: Player): PlayerState
	local state: PlayerState = {
		UserId = player.UserId,
		Level = LevelConfig.StartingLevel,
		Exp = LevelConfig.StartingExp,
		Size = LevelConfig.StartingSize,
		MaxHP = BalanceConfig.BaseHP,
		CurrentHP = BalanceConfig.BaseHP,
		BaseDamage = BalanceConfig.BaseDamage,
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
		Attributes = {
			Speed = 0,
			HPBonus = 0,
			LaunchPower = 0,
			ChargeSpeed = 0,
			ReflectDamage = 0,
		},
		IsAlive = true,
		IsCharging = false,
	}
	return state
end

function PlayerStateService:Init()
	Players.PlayerAdded:Connect(function(player)
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self:RecalculateDerivedStats(player, true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
		self._buffs[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
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
	state.Size = self:ComputeSize(state.Level)
	local buff = self._buffs[player]
	local hpBuff = buff and buff.HpBoost or 0
	local newMax = computeMaxHp(state, hpBuff)
	state.MaxHP = newMax
	if refillHealth then
		state.CurrentHP = newMax
	else
		state.CurrentHP = math.clamp(state.CurrentHP, 0, newMax)
	end
	self:PublishState(player)
end

function PlayerStateService:SetAlive(player: Player, alive: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	state.IsAlive = alive
	if alive then
		state.CurrentHP = math.max(1, state.CurrentHP)
	end
	self:PublishState(player)
end

function PlayerStateService:ApplyDamage(player: Player, amount: number): boolean
	local state = self._states[player]
	if not state or not state.IsAlive then
		return false
	end
	state.CurrentHP = math.max(0, state.CurrentHP - math.max(0, amount))
	self:PublishState(player)
	return true
end

function PlayerStateService:Heal(player: Player, amount: number)
	local state = self._states[player]
	if not state then
		return
	end
	state.CurrentHP = math.min(state.MaxHP, state.CurrentHP + math.max(0, amount))
	self:PublishState(player)
end

function PlayerStateService:MarkInvulnerable(player: Player, duration: number)
	local state = self._states[player]
	if not state then
		return
	end
	state.InvulnerableUntil = os.clock() + duration
	self:PublishState(player)
end

function PlayerStateService:IsInvulnerable(player: Player): boolean
	local state = self._states[player]
	if not state then
		return false
	end
	return state.InvulnerableUntil > os.clock()
end

function PlayerStateService:GrantExp(player: Player, amount: number)
	local state = self._states[player]
	if not state then
		return
	end
	local buff = self._buffs[player]
	local adjusted = math.max(0, amount)
	if buff then
		adjusted *= (1 + buff.ExpBoost)
	end
	state.Exp += adjusted
	local leveled = false
	while state.Level < LevelConfig.MaxLevel do
		local requiredExp = self:GetRequiredExp(state.Level)
		if state.Exp < requiredExp then
			break
		end
		state.Exp -= requiredExp
		state.Level += 1
		state.AttributePoints += 1
		leveled = true
	end
	if leveled then
		self:RecalculateDerivedStats(player, false)
		self._context.EventBus:Fire("LevelUp", player, state.Level)
	else
		self:PublishState(player)
	end
end

function PlayerStateService:TryApplyExpPenalty(player: Player, penalty: number): boolean
	local state = self._states[player]
	if not state then
		return false
	end
	state.Exp -= math.max(0, penalty)
	local didLevelDown = false
	while state.Exp <= 0 do
		if state.Level <= 1 then
			state.Level = 1
			state.Exp = 0
			break
		end
		state.Level -= 1
		state.Exp = self:GetRequiredExp(state.Level)
		didLevelDown = true
	end
	if didLevelDown then
		self:RecalculateDerivedStats(player, false)
		self._context.EventBus:Fire("LevelDown", player, state.Level)
	else
		self:PublishState(player)
	end
	return didLevelDown
end

function PlayerStateService:ResetForNewRound(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	state.Level = LevelConfig.StartingLevel
	state.Exp = LevelConfig.StartingExp
	state.AttributePoints = LevelConfig.StartingAttributePoints
	state.Attributes = {
		Speed = 0,
		HPBonus = 0,
		LaunchPower = 0,
		ChargeSpeed = 0,
		ReflectDamage = 0,
	}
	state.RespawnCountThisMatch = 0
	state.IsAlive = true
	state.IsCharging = false
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	state.InvulnerableUntil = os.clock() + BalanceConfig.DefaultInvulnerableSeconds
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:UpdateVelocity(player: Player, velocity: Vector3)
	local state = self._states[player]
	if not state then
		return
	end
	if velocity.Magnitude > BalanceConfig.MaxVelocity then
		state.CurrentVelocity = velocity.Unit * BalanceConfig.MaxVelocity
	else
		state.CurrentVelocity = velocity
	end
end

function PlayerStateService:ResetForRespawn(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	state.RespawnCountThisMatch += 1
	state.IsAlive = true
	state.IsCharging = false
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	state.InvulnerableUntil = os.clock() + BalanceConfig.DefaultInvulnerableSeconds
	self:RecalculateDerivedStats(player, true)
end

function PlayerStateService:PublishState(player: Player)
	if self._stateUpdateRemote then
		local state = self._states[player]
		if state then
			self._stateUpdateRemote:FireClient(player, state)
		end
	end
end

return PlayerStateService
