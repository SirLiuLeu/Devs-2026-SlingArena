--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)

type PlayerState = PlayerStateTypes.PlayerState

local MOVEMENT_STATE = GameStates.Movement

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


local function syncHumanoidHealth(player: Player, currentHp: number, maxHp: number)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = math.max(maxHp, 1)
	humanoid.Health = math.clamp(currentHp, 0, humanoid.MaxHealth)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
end

local function buildDefaultState(player: Player): PlayerState
	local sling = SlingshotConfig.SlingConfig
	local state: PlayerState = {
		UserId = player.UserId,
		MapName = "LobbyMap",
		ArenaStatus = GameStates.ArenaStatus.Lobby,
		TeamId = "TeamRed",
		Level = LevelConfig.StartingLevel,
		Exp = LevelConfig.StartingExp,
		Size = sling.Size,
		MaxHP = sling.MaxHP,
		CurrentHP = sling.MaxHP,
		BaseDamage = sling.BaseDamage,
		RegenRate = sling.RegenPerSecond,
		ReflectDamage = sling.ReflectDamagePercent,
		LaunchSpeed = SlingshotConfig.BaseLaunchForce,
		LaunchRange = sling.MaxShootRange,
		ChargeSpeed = 1,
		MoveSpeed = BalanceConfig.DefaultWalkSpeed,
		DamageMultiplier = 1,
		HPBonus = 0,
		LaunchSpeedBonus = 0,
		RegenBonus = 0,
		KnockbackResistance = 0,
		SlingshotType = "Default",
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

function PlayerStateService:IsStunned(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and (state.StunnedUntil or 0) > os.clock()
end

function PlayerStateService:ApplyStun(player: Player, duration: number)
	local state = self._states[player]
	if not state then
		return
	end
	local stunUntil = os.clock() + math.max(0, duration)
	state.StunnedUntil = math.max(state.StunnedUntil or 0, stunUntil)
	state.IsCharging = false
	state.ChargeValue = 0
	state.MovementState = MOVEMENT_STATE.Idle
	self:PublishState(player)
end

function PlayerStateService:SetVisibility(player: Player, visible: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	state.IsVisible = visible
	self:PublishState(player)
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
	local levelMultiplier = 1 + (math.max(state.Level - 1, 0) * 0.03)
	state.HPBonus = 0
	state.RegenBonus = 0
	state.LaunchSpeedBonus = 0

	state.Size = (BalanceConfig.BaseSize * levelMultiplier) * state.ScaleMultiplier
	state.BaseDamage = sling.BaseDamage * levelMultiplier
	state.DamageMultiplier = 1
	state.RegenRate = sling.RegenPerSecond * levelMultiplier
	state.ReflectDamage = sling.ReflectDamagePercent
	state.LaunchSpeed = SlingshotConfig.BaseLaunchForce * levelMultiplier
	state.LaunchRange = sling.MaxShootRange * levelMultiplier
	state.ChargeSpeed = 1
	state.MoveSpeed = BalanceConfig.DefaultWalkSpeed * levelMultiplier

	local hp = sling.MaxHP * levelMultiplier
	state.MaxHP = hp
	if refillHealth then
		state.CurrentHP = hp
	else
		state.CurrentHP = math.clamp(state.CurrentHP, 0, hp)
	end
	syncHumanoidHealth(player, state.CurrentHP, state.MaxHP)
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
		Regen = state.RegenRate,
		Range = state.LaunchRange,
		Reflect = state.ReflectDamage,
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
	syncHumanoidHealth(player, state.CurrentHP, state.MaxHP)
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
	if not state or not state.IsAlive then return false end
	state.CurrentHP = math.max(0, state.CurrentHP - math.max(0, amount))
	state.LastDamageTime = os.clock()
	syncHumanoidHealth(player, state.CurrentHP, state.MaxHP)
	self:PublishState(player)
	return true
end

function PlayerStateService:Heal(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	state.CurrentHP = math.min(state.MaxHP, state.CurrentHP + math.max(0, amount))
	syncHumanoidHealth(player, state.CurrentHP, state.MaxHP)
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
	return state ~= nil and state.InvulnerableUntil > os.clock()
end

function PlayerStateService:GrantExp(player: Player, amount: number)
	local state = self._states[player]
	if not state then return end
	local expBonus = 1
	if state.TeamId == "TeamRed" or state.TeamId == "TeamBlue" then
		expBonus = 1 + 0
	end
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

return PlayerStateService
