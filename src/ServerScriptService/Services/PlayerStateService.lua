--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherStatResolver = require(ReplicatedStorage.Shared.Utils.LauncherStatResolver)
local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
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

type Context = {
	EventBus: any,
	Remotes: Folder,
	Services: any?,
	ServiceRegistry: any?,
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
	self._launcherRuntime = {} :: { [Player]: any }
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
	local launcher = LauncherConfig.BaseStats
	local state: PlayerState = {
		UserId = player.UserId,
		CurrentMap = nil,
		LocationState = GameStates.SessionState.Lobby,
		TeamId = nil,
		Level = LevelConfig.StartingLevel,
		Exp = LevelConfig.StartingExp,
		Size = launcher.size,
		MaxHP = launcher.maxHP,
		CurrentHP = launcher.maxHP,
		BaseDamage = launcher.baseDamage,
		RegenRate = launcher.regenPerSecond,
		ReflectDamage = launcher.reflectDamagePercent,
		LaunchSpeed = PhysicsConfig.Launch.SpeedMax,
		LaunchRange = launcher.maxShootRange,
		ChargeSpeed = 1,
		MoveSpeed = PhysicsConfig.Movement.MoveSpeed,
		DamageMultiplier = 1,
		HPBonus = 0,
		LaunchSpeedBonus = 0,
		RegenBonus = 0,
		KnockbackResistance = 0,
		LaunchershotType = "NormalLauncher",
		EquippedLauncherInstanceId = "default_normal_launcher",
		OwnedLaunchers = {
			default_normal_launcher = {
				definitionId = "NormalLauncher",
				star = 1,
				level = 1,
				acquiredAt = os.time(),
			},
		},
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
		RankPoints = 0,
	}

	return state
end

local function getFlagService(context: Context)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional("FlagService")
	end
	return context.Services and context.Services.FlagService
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
		local flagService = getFlagService(self._context)
		if flagService then
			flagService:EnsurePlayer(player)
		end
		self._launcherRuntime[player] = {}
		self:RecalculateDerivedStats(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
		self._buffs[player] = nil
		self._lastAttacker[player] = nil
		self._damageDealt[player] = nil
		local flagService = getFlagService(self._context)
		if flagService then
			flagService:ClearPlayer(player)
		end
		self._launcherRuntime[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self._states[player] = buildDefaultState(player)
		self._buffs[player] = { DamageBoost = 0, HpBoost = 0, ExpBoost = 0, ChargeBoost = 0, Active = false }
		self._damageDealt[player] = 0
		local flagService = getFlagService(self._context)
		if flagService then
			flagService:EnsurePlayer(player)
		end
		self._launcherRuntime[player] = {}
		self:RecalculateDerivedStats(player, true)
	end
end

function PlayerStateService:HasFlag(player: Player, flagName: string): boolean
	local flagService = getFlagService(self._context)
	return flagService ~= nil and flagService:HasFlag(player, flagName)
end

function PlayerStateService:GetFlag(player: Player, flagName: string): any?
	local flagService = getFlagService(self._context)
	return flagService and flagService:GetFlag(player, flagName) or nil
end

function PlayerStateService:ApplyFlag(player: Player, flagName: string, duration: number?, source: any?, data: any?): boolean
	local flagService = getFlagService(self._context)
	return flagService ~= nil and flagService:ApplyFlag(player, flagName, duration, source, data)
end

function PlayerStateService:RemoveFlag(player: Player, flagName: string, source: any?, data: any?)
	local flagService = getFlagService(self._context)
	if flagService then
		flagService:RemoveFlag(player, flagName, source, data)
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
		self:ApplyFlag(player, "Invisible", nil)
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

	local ownedLaunchers = state.OwnedLaunchers or {}
	local equippedInstanceId = state.EquippedLauncherInstanceId
	local equippedInstance = if equippedInstanceId then ownedLaunchers[equippedInstanceId] else nil
	local definitionId = (equippedInstance and equippedInstance.definitionId) or state.LaunchershotType or LauncherConfig.DefaultLauncherId
	local star = (equippedInstance and equippedInstance.star) or 1
	local launcherLevel = (equippedInstance and equippedInstance.level) or math.max(state.Level, 1)
	local resolved = LauncherStatResolver.Resolve(definitionId, star, launcherLevel)

	state.HPBonus = 0
	state.RegenBonus = 0
	state.LaunchSpeedBonus = 0
	state.Size = (BalanceConfig.BaseSize * (1 + (math.max(state.Level - 1, 0) * 0.03))) * state.ScaleMultiplier
	state.BaseDamage = resolved.baseDamage
	state.DamageMultiplier = resolved.damageMultiplier
	state.RegenRate = resolved.regen
	state.ReflectDamage = resolved.reflectDamage
	state.LaunchSpeed = resolved.launchSpeed
	state.LaunchRange = resolved.launchRange
	state.ChargeSpeed = 1
	state.MoveSpeed = resolved.moveSpeed
	state.Armor = resolved.armor
	state.ExpBonus = resolved.expBonus
	state.LaunchershotType = definitionId

	state.MaxHP = resolved.maxHP
	if refillHealth then
		state.CurrentHP = resolved.maxHP
	else
		state.CurrentHP = math.clamp(state.CurrentHP, 0, resolved.maxHP)
	end
	self:PublishState(player)
end

function PlayerStateService:GetFinalStats(player: Player)
	local state = self._states[player]
	if not state then
		return nil
	end
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

function PlayerStateService:SetTeamId(player: Player, teamId: string?)
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

function PlayerStateService:Heal(player: Player, amount: number, showOnHpBar: boolean?)
	local state = self._states[player]
	if not state then return 0 end
	local before = state.CurrentHP
	state.CurrentHP = math.min(state.MaxHP, state.CurrentHP + math.max(0, amount))
	local restored = state.CurrentHP - before
	local playerService = self._context.Services and self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	if root and restored ~= 0 then
		playerService:ShowFloatingHpChange(root, restored)
	end
	if showOnHpBar == true and restored > 0 and playerService and typeof(playerService.ShowHpBarRestore) == "function" then
		playerService:ShowHpBarRestore(player, restored)
	end
	self:PublishState(player)
	return restored
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
	local item = ItemConfig.GetById("hp_potion")
	local effect = item and item.effect
	local params = effect and effect.flagParams or nil
	local flagName = effect and effect.flagName or "HPRecovering"
	local duration = params and params.Duration or nil
	local cooldown = (item and item.useCooldown) or BalanceConfig.HpPotionCooldown

	state.HpPotions = math.max(0, (state.HpPotions or 0) - 1)
	state.NextHpPotionUseTime = now + cooldown
	self:ApplyFlag(player, flagName, duration, player, params)
	self:PublishState(player)
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
	local expFlag = self:GetFlag(player, "EXPBoosted")
	if expFlag and expFlag.Data and type(expFlag.Data.ExpBonusPercent) == "number" then
		expBonus += math.max(0, expFlag.Data.ExpBonusPercent) / 100
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
	local flagService = getFlagService(self._context)
	state.ActiveFlags = if flagService then flagService:ResetPlayer(player) else {}
	self._launcherRuntime[player] = {}
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
	local flagService = getFlagService(self._context)
	state.ActiveFlags = if flagService then flagService:ResetPlayer(player) else {}
	self._launcherRuntime[player] = {}
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
	self:RecalculateDerivedStats(player, false)
	local state = self._states[player]
	if not state then
		return
	end
	self:Heal(player, state.MaxHP * 0.2, true)
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

function PlayerStateService:SetLauncherType(player: Player, launcherId: string): boolean
	local state = self._states[player]
	if not state or not LauncherConfig.GetById(launcherId) then
		return false
	end
	state.LaunchershotType = launcherId
	state.EquippedLauncherInstanceId = nil
	self._launcherRuntime[player] = {}
	self:RecalculateDerivedStats(player, true)
	return true
end

function PlayerStateService:SetEquippedLauncherInstance(player: Player, instanceId: string): boolean
	local state = self._states[player]
	local ownedLaunchers = state and state.OwnedLaunchers or nil
	local launcherInstance = ownedLaunchers and ownedLaunchers[instanceId] or nil
	if not (state and launcherInstance and LauncherConfig.GetById(launcherInstance.definitionId)) then
		return false
	end
	state.EquippedLauncherInstanceId = instanceId
	state.LaunchershotType = launcherInstance.definitionId
	self._launcherRuntime[player] = {}
	self:RecalculateDerivedStats(player, true)
	return true
end

function PlayerStateService:GetLauncherAbilityType(player: Player): string
	local state = self._states[player]
	local launcher = state and LauncherConfig.GetById(state.LaunchershotType or "")
	return (launcher and (launcher.abilityType or launcher.id)) or "NormalLauncher"
end

function PlayerStateService:GetLauncherRuntime(player: Player): any
	local runtime = self._launcherRuntime[player]
	if not runtime then
		runtime = {}
		self._launcherRuntime[player] = runtime
	end
	return runtime
end

function PlayerStateService:TickFlags(dt: number)
	local flagService = getFlagService(self._context)
	if flagService then
		flagService:TickFlags(dt)
	end
end

return PlayerStateService
