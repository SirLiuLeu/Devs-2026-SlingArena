--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)

type PlayerState = require(ReplicatedStorage.Shared.Types.PlayerState).PlayerState

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
	self._buffs = {} :: { [Player]: { DamageBoost: number, HpBoost: number, ExpBoost: number, ChargeBoost: number, Active: boolean } }
	self._stateUpdateRemote = context.Remotes:FindFirstChild("StateUpdate") :: RemoteEvent
	return self
end

local function computeSize(level: number): number
	local base = BalanceConfig.BaseSize * (1 + math.sqrt(math.max(level, 1)) * BalanceConfig.SizeSqrtMultiplier)
	if level > 30 then
		return BalanceConfig.BaseSize + (base - BalanceConfig.BaseSize) * BalanceConfig.PostLevel30SizeScalar
	end
	return base
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
	state.Size = computeSize(state.Level)
	state.MaxHP = computeMaxHp(state, 0)
	state.CurrentHP = state.MaxHP
	return state
end

function PlayerStateService:Init()
	Players.PlayerAdded:Connect(function(player)
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self:PublishState(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
		self._buffs[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self:PublishState(player)
	end

	self._context.EventBus:On("CharacterSpawned", function(player: Player, character: Model)
		self:ApplyCharacterScale(player, character)
	end)
end

function PlayerStateService:GetState(player: Player): PlayerState?
	return self._states[player]
end

function PlayerStateService:GetAllStates(): { [Player]: PlayerState }
	return self._states
end

function PlayerStateService:UpdateVelocity(player: Player, velocity: Vector3)
	local state = self._states[player]
	if not state then
		return
	end
	local clamped = velocity
	if velocity.Magnitude > BalanceConfig.MaxVelocity then
		clamped = velocity.Unit * BalanceConfig.MaxVelocity
	end
	state.CurrentVelocity = clamped
end

function PlayerStateService:SetCharging(player: Player, isCharging: boolean, chargeValue: number?)
	local state = self._states[player]
	if not state then
		return
	end
	state.IsCharging = isCharging
	if chargeValue then
		state.ChargeValue = math.clamp(chargeValue, 0, 1)
	end
	self:PublishState(player)
end

function PlayerStateService:ApplyDamage(player: Player, amount: number): boolean
	local state = self._states[player]
	if not state or not state.IsAlive then
		return false
	end
	state.CurrentHP = math.max(0, state.CurrentHP - math.max(0, amount))
	if state.CurrentHP <= 0 then
		state.IsAlive = false
		self._context.EventBus:Fire("PlayerDied", player)
	end
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

function PlayerStateService:AddDiamonds(player: Player, amount: number)
	local state = self._states[player]
	if not state then
		return
	end
	state.Diamonds = math.max(0, state.Diamonds + amount)
	self:PublishState(player)
end

function PlayerStateService:SpendDiamonds(player: Player, amount: number): boolean
	local state = self._states[player]
	if not state or amount < 0 then
		return false
	end
	if state.Diamonds < amount then
		return false
	end
	state.Diamonds -= amount
	self:PublishState(player)
	return true
end

function PlayerStateService:GrantExp(player: Player, amount: number)
	local state = self._states[player]
	if not state then
		return
	end
	local buff = self._buffs[player]
	local adjusted = amount
	if buff then
		adjusted = adjusted * (1 + buff.ExpBoost)
	end
	state.Exp += math.max(0, adjusted)
	local leveled = false
	while state.Level < LevelConfig.MaxLevel do
		local requiredExp = BalanceConfig.BaseExp * (state.Level ^ BalanceConfig.ExpExponent)
		if state.Exp < requiredExp then
			break
		end
		state.Exp -= requiredExp
		state.Level += 1
		state.AttributePoints += 1
		leveled = true
	end

	if leveled then
		state.Size = computeSize(state.Level)
		local hpBuff = buff and buff.HpBoost or 0
		state.MaxHP = computeMaxHp(state, hpBuff)
		state.CurrentHP = math.min(state.CurrentHP + 20, state.MaxHP)
		self._context.EventBus:Fire("LevelUp", player, state.Level)
		local character = player.Character
		if character then
			self:ApplyCharacterScale(player, character)
		end
	end
	self:PublishState(player)
end

function PlayerStateService:ApplyCharacterScale(player: Player, character: Model)
	local state = self._states[player]
	if not state then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = BalanceConfig.DefaultWalkSpeed * (1 + math.min(state.Attributes.Speed * 0.01, 0.2))
	if humanoid:FindFirstChild("BodyHeightScale") then
		(humanoid.BodyHeightScale :: NumberValue).Value = state.Size
	end
	if humanoid:FindFirstChild("BodyWidthScale") then
		(humanoid.BodyWidthScale :: NumberValue).Value = state.Size
	end
	if humanoid:FindFirstChild("BodyDepthScale") then
		(humanoid.BodyDepthScale :: NumberValue).Value = state.Size
	end
	if humanoid:FindFirstChild("HeadScale") then
		(humanoid.HeadScale :: NumberValue).Value = state.Size
	end
end

function PlayerStateService:ResetForRespawn(player: Player, paid: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	state.RespawnCountThisMatch += 1
	if paid then
		state.Size *= BalanceConfig.RespawnRetainSizePaid
	else
		state.Level = math.max(1, math.floor(state.Level * BalanceConfig.RespawnRetainLevelFree))
		state.Size = computeSize(state.Level)
	end
	state.IsAlive = true
	state.IsCharging = false
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	self:ClearMatchBuff(player)
	state.MaxHP = computeMaxHp(state, 0)
	state.CurrentHP = state.MaxHP
	state.InvulnerableUntil = os.clock() + BalanceConfig.DefaultInvulnerableSeconds
	self:PublishState(player)
end

function PlayerStateService:PrestigeReset(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	local diamondGain = math.floor(state.Level / BalanceConfig.DiamondsPerPrestigeLevelDivisor)
	state.Diamonds += diamondGain
	state.Level = 1
	state.Exp = 0
	state.AttributePoints = 0
	state.Attributes.Speed = 0
	state.Attributes.HPBonus = 0
	state.Attributes.LaunchPower = 0
	state.Attributes.ChargeSpeed = 0
	state.Attributes.ReflectDamage = 0
	state.Size = computeSize(state.Level)
	state.MaxHP = computeMaxHp(state, 0)
	state.CurrentHP = state.MaxHP
	self:PublishState(player)
end

function PlayerStateService:TrySpendAttribute(player: Player, attributeName: string): boolean
	local state = self._states[player]
	if not state then
		return false
	end
	if state.AttributePoints <= 0 then
		return false
	end
	local current = state.Attributes[attributeName]
	if current == nil then
		return false
	end
	if current >= BalanceConfig.AttributeCapPerStat then
		return false
	end

	if attributeName == "ReflectDamage" then
		local reflectNext = math.min((current + 1) * 0.0075, BalanceConfig.ReflectDamageCap)
		if reflectNext > BalanceConfig.ReflectDamageCap then
			return false
		end
	end

	state.Attributes[attributeName] = current + 1
	state.AttributePoints -= 1
	local buff = self._buffs[player]
	local hpBuff = buff and buff.HpBoost or 0
	state.MaxHP = computeMaxHp(state, hpBuff)
	state.CurrentHP = math.min(state.CurrentHP, state.MaxHP)
	self:PublishState(player)
	return true
end

function PlayerStateService:ApplyMatchBuff(player: Player): boolean
	local state = self._states[player]
	local buff = self._buffs[player]
	if not state or not buff or buff.Active then
		return false
	end
	buff.Active = true
	buff.DamageBoost = BalanceConfig.MatchBuffMaxBoost
	buff.HpBoost = BalanceConfig.MatchBuffMaxBoost
	buff.ExpBoost = BalanceConfig.MatchBuffMaxBoost
	buff.ChargeBoost = BalanceConfig.MatchBuffMaxBoost
	state.MaxHP = computeMaxHp(state, buff.HpBoost)
	state.CurrentHP = math.min(state.CurrentHP + 25, state.MaxHP)
	self:PublishState(player)
	return true
end

function PlayerStateService:GetBuff(player: Player)
	return self._buffs[player]
end

function PlayerStateService:ClearMatchBuff(player: Player)
	local buff = self._buffs[player]
	local state = self._states[player]
	if not buff or not state then
		return
	end
	buff.Active = false
	buff.DamageBoost = 0
	buff.HpBoost = 0
	buff.ExpBoost = 0
	buff.ChargeBoost = 0
	state.MaxHP = computeMaxHp(state, 0)
	state.CurrentHP = math.min(state.CurrentHP, state.MaxHP)
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
