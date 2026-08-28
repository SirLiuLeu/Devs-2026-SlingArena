--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherStatResolver = require(ReplicatedStorage.Shared.Utils.LauncherStatResolver)
local EquipmentStatResolver = require(ReplicatedStorage.Shared.Utils.EquipmentStatResolver)
local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type PlayerState = PlayerStateTypes.PlayerState

-- Public dependency contract. Consumers should depend on this interface rather than
-- assuming a concrete PlayerStateService table is present at runtime.
export type IPlayerStateService = {
	IsLauncher: (self: IPlayerStateService, player: Player) -> boolean,
	IsHuman: (self: IPlayerStateService, player: Player) -> boolean,
	GetState: (self: IPlayerStateService, player: Player) -> PlayerState?,
	RecalculateDerivedStats: (self: IPlayerStateService, player: Player, forcePublish: boolean?) -> (),
	Heal: (self: IPlayerStateService, player: Player, amount: number) -> (),
	PublishState: (self: IPlayerStateService, player: Player) -> (),
}

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

local function playerName(player: Player?): string
	return player and player.Name or "nil"
end

local function applyDamageLog(_message: string)
end

function PlayerStateService.new(context: Context)
	local self = setmetatable({}, PlayerStateService)
	self._context = context
	self._states = {} :: { [Player]: PlayerState }
	self._buffs = {} :: { [Player]: BuffState }
	self._lastAttacker = {} :: { [Player]: Player }
	self._damageDealt = {} :: { [Player]: number }
	self._launcherRuntime = {} :: { [Player]: any }
	self._lastPublishedStates = {} :: { [Player]: any }
	self._stateUpdateRemote = context.Remotes:FindFirstChild("StateUpdate") :: RemoteEvent
	self._consumeHpPotionRemote = context.Remotes:FindFirstChild("ConsumeHpPotion") :: RemoteEvent?
	self._attributeUpgradeRemote = context.Remotes:FindFirstChild("AttributeUpgrade") :: RemoteEvent?
	self._setPlayerModeRemote = context.Remotes:FindFirstChild("SetPlayerMode") :: RemoteEvent?
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
		OwnedEquipment = {},
		EquippedEquipment = { [1] = nil, [2] = nil, [3] = nil },
		ChargeValue = 0,
		CurrentVelocity = Vector3.zero,
		InvulnerableUntil = 0,
		LastDamageTime = 0,
		InvulCooldownUntil = 0,
		Diamonds = 0,
		HpPotions = BalanceConfig.DefaultHpPotions,
		NextHpPotionUseTime = 0,
		RespawnCountThisMatch = 0,
		DeathCountThisMatch = 0,
		SelectedPlayerMode = GameStates.PlayerMode.Human,
		ActivePlayerMode = GameStates.PlayerMode.Human,
		ForcedHuman = false,
		FinalPhaseDeathConverted = false,
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
		KnockbackStartTime = 0,
		KnockbackStopEvidenceFrames = 0,
		KnockbackImpactNormal = nil,
		KnockbackHitTimestamp = 0,
		KnockbackStunEndsAt = 0,
		KnockbackInitialSpeed = 0,
		KnockbackMaxEndsAt = 0,
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
		TotalPoints = 0,
		WeeklyPoints = 0,
	}

	return state
end

local function getFlagService(context: Context)
	return ServiceResolver.Get(context, "FlagService")
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
	if self._setPlayerModeRemote then
		self._setPlayerModeRemote.OnServerEvent:Connect(function(player: Player, modeName: string)
			local playerService = ServiceResolver.Get(self._context, "PlayerService")
			if playerService and typeof(playerService.SwitchPlayerModeInLobby) == "function" then
				playerService:SwitchPlayerModeInLobby(player, modeName)
			else
				self:SetSelectedPlayerMode(player, modeName)
			end
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
		self:_syncProgressPoints(player)
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
		self._lastPublishedStates[player] = nil
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
		self:_syncProgressPoints(player)
		self:RecalculateDerivedStats(player, true)
	end
end

function PlayerStateService:_syncProgressPoints(player: Player)
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local state = self._states[player]
	if not state or not playerDataService or typeof(playerDataService.GetProgressPoints) ~= "function" then
		return
	end
	local totalPoints, weeklyPoints = playerDataService:GetProgressPoints(player)
	state.RankPoints = totalPoints
	state.TotalPoints = totalPoints
	state.WeeklyPoints = weeklyPoints
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

function PlayerStateService:GetActivePlayerMode(player: Player): string
	local state = self._states[player]
	return (state and state.ActivePlayerMode) or GameStates.PlayerMode.Human
end

function PlayerStateService:IsHuman(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and state.ActivePlayerMode == GameStates.PlayerMode.Human
end

function PlayerStateService:IsLauncher(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and state.ActivePlayerMode == GameStates.PlayerMode.Launcher
end

function PlayerStateService:IsCombatParticipant(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and state.IsAlive == true and state.LocationState ~= GameStates.SessionState.Lobby and state.ActivePlayerMode == GameStates.PlayerMode.Launcher
end

function PlayerStateService:SetSelectedPlayerMode(player: Player, modeName: string): boolean
	if modeName ~= GameStates.PlayerMode.Launcher and modeName ~= GameStates.PlayerMode.Human then
		return false
	end
	local state = self._states[player]
	if not state then
		return false
	end
	-- Lobby selection is client-driven UI, but server-authoritative and only accepted in Lobby.
	if state.LocationState ~= GameStates.SessionState.Lobby then
		self:PublishState(player)
		return false
	end
	state.SelectedPlayerMode = modeName
	self:PublishState(player)
	applyDamageLog(`PlayerStateService:ApplyDamage return true player={playerName(player)} amount={amount} beforeHP={before} afterHP={state.CurrentHP}`)
	return true
end

function PlayerStateService:_syncEquipmentLifecycleForMode(player: Player, modeName: string)
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local effectService = ServiceResolver.Get(self._context, "EquipmentEffectService")
	if modeName == GameStates.PlayerMode.Launcher then
		if playerService and typeof(playerService.RefreshEquipmentModels) == "function" then
			playerService:RefreshEquipmentModels(player)
		end
		if effectService and typeof(effectService.ActivateEquippedEquipment) == "function" then
			effectService:ActivateEquippedEquipment(player)
		end
	else
		if effectService and typeof(effectService.DeactivateAllEquipment) == "function" then
			effectService:DeactivateAllEquipment(player)
		end
		if playerService and typeof(playerService.UnequipEquipmentModel) == "function" then
			for slot = 1, 3 do
				playerService:UnequipEquipmentModel(player, slot)
			end
		end
	end
end

function PlayerStateService:SetActivePlayerMode(player: Player, modeName: string, forced: boolean?, publishNow: boolean?): boolean
	if modeName ~= GameStates.PlayerMode.Launcher and modeName ~= GameStates.PlayerMode.Human then
		return false
	end
	local state = self._states[player]
	if not state then
		return false
	end
	local previousMode = state.ActivePlayerMode
	state.ActivePlayerMode = modeName
	state.MovementState = if modeName == GameStates.PlayerMode.Human then GameStates.PlayerState.Human else GameStates.PlayerState.Idle
	state.IsCharging = false
	state.ChargeValue = 0
	state.CurrentVelocity = Vector3.zero
	state.CooldownEndTime = 0
	state.KnockbackStartTime = 0
	state.KnockbackStopEvidenceFrames = 0
	state.KnockbackImpactNormal = nil
	state.KnockbackHitTimestamp = 0
	state.KnockbackStunEndsAt = 0
	state.KnockbackInitialSpeed = 0
	state.KnockbackMaxEndsAt = 0
	if forced == true and modeName == GameStates.PlayerMode.Human then
		state.ForcedHuman = true
	end
	if previousMode ~= modeName then
		self:_syncEquipmentLifecycleForMode(player, modeName)
	end
	if publishNow ~= false then
		self:PublishState(player)
	end
	return true
end

function PlayerStateService:ShouldForceHuman(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and (state.ForcedHuman == true or state.FinalPhaseDeathConverted == true)
end

function PlayerStateService:ResolveArenaSpawnMode(player: Player): string
	local state = self._states[player]
	if state and self:ShouldForceHuman(player) then
		return GameStates.PlayerMode.Human
	end
	return GameStates.PlayerMode.Launcher
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

function PlayerStateService:_ensureDefaultLauncher(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	state.OwnedLaunchers = state.OwnedLaunchers or {}
	local equippedInstanceId = state.EquippedLauncherInstanceId
	local equippedInstance = equippedInstanceId and state.OwnedLaunchers[equippedInstanceId] or nil
	if equippedInstance and LauncherConfig.GetById(equippedInstance.definitionId) then
		return
	end
	local defaultInstanceId = "default_normal_launcher"
	state.OwnedLaunchers[defaultInstanceId] = state.OwnedLaunchers[defaultInstanceId] or {
		definitionId = LauncherConfig.DefaultLauncherId,
		star = 1,
		level = 1,
		acquiredAt = os.time(),
	}
	state.EquippedLauncherInstanceId = defaultInstanceId
	state.LaunchershotType = LauncherConfig.DefaultLauncherId
end

function PlayerStateService:RecalculateDerivedStats(player: Player, refillHealth: boolean?)
	local state = self._states[player]
	if not state then
		return
	end
	self:_ensureDefaultLauncher(player)

	local ownedLaunchers = state.OwnedLaunchers or {}
	local equippedInstanceId = state.EquippedLauncherInstanceId
	local equippedInstance = if equippedInstanceId then ownedLaunchers[equippedInstanceId] else nil
	local definitionId = (equippedInstance and equippedInstance.definitionId) or state.LaunchershotType or LauncherConfig.DefaultLauncherId
	local star = (equippedInstance and equippedInstance.star) or 1
	local launcherLevel = (equippedInstance and equippedInstance.level) or math.max(state.Level, 1)
	local resolved = LauncherStatResolver.Resolve(definitionId, star, launcherLevel)
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if dataService and typeof(dataService.GetData) == "function" then
		local data = dataService:GetData(player)
		resolved = EquipmentStatResolver.Resolve(resolved :: any, data.OwnedEquipment, data.EquippedEquipment) :: any
		state.OwnedEquipment = data.OwnedEquipment or {}
		state.EquippedEquipment = data.EquippedEquipment or {}
		state.Diamonds = dataService:GetDiamonds(player)
	end

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

function PlayerStateService:ClearHumanQualification(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	state.DeathCountThisMatch = 0
	state.RespawnCountThisMatch = 0
	state.ForcedHuman = false
	state.FinalPhaseDeathConverted = false
	self:PublishState(player)
end

function PlayerStateService:RecordDeath(player: Player, roundState: string?): boolean
	local state = self._states[player]
	if not state then
		return false
	end
	local diedAsLauncher = state.ActivePlayerMode == GameStates.PlayerMode.Launcher
	state.DeathCountThisMatch = (state.DeathCountThisMatch or 0) + 1
	state.RespawnCountThisMatch = state.DeathCountThisMatch
	local shouldConvert = diedAsLauncher
	if roundState == GameStates.MapRoundState.FinalPhase then
		state.FinalPhaseDeathConverted = true
		shouldConvert = true
	end
	if shouldConvert then
		state.ForcedHuman = true
		state.ActivePlayerMode = GameStates.PlayerMode.Human
		state.MovementState = MOVEMENT_STATE.Human
	end
	self:PublishState(player)
	return shouldConvert
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
	applyDamageLog(`PlayerStateService:ApplyDamage enter player={playerName(player)} amount={amount}`)
	local state = self._states[player]
	if not state or not state.IsAlive or self:IsHuman(player) or self:IsInvulnerable(player) or self:HasFlag(player, "Ghost") then
		applyDamageLog(`PlayerStateService:ApplyDamage return false player={playerName(player)} amount={amount} hasState={state ~= nil} isAlive={state and state.IsAlive or false} isHuman={self:IsHuman(player)} invulnerable={self:IsInvulnerable(player)} ghost={self:HasFlag(player, "Ghost")}`)
		return false
	end
	local before = state.CurrentHP
	state.CurrentHP = math.max(0, state.CurrentHP - math.max(0, amount))
	applyDamageLog(`PlayerStateService:ApplyDamage applied player={playerName(player)} amount={amount} beforeHP={before} afterHP={state.CurrentHP}`)
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local root = playerService and playerService:GetRoot(player)
	if root and state.CurrentHP ~= before then
		playerService:ShowFloatingHpChange(root, state.CurrentHP - before)
	end
	state.LastDamageTime = os.clock()
	self:PublishState(player)
	applyDamageLog(`PlayerStateService:ApplyDamage return true player={playerName(player)} amount={amount} beforeHP={before} afterHP={state.CurrentHP}`)
	return true
end

function PlayerStateService:Heal(player: Player, amount: number, showOnHpBar: boolean?)
	local state = self._states[player]
	if not state then return 0 end
	local before = state.CurrentHP
	state.CurrentHP = math.min(state.MaxHP, state.CurrentHP + math.max(0, amount))
	local restored = state.CurrentHP - before
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
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
		self:_sendPotionFeedback(player, "NoPotion")
		return false, "NoPotion"
	end
	if now < (state.NextHpPotionUseTime or 0) then
		self:_sendPotionFeedback(player, "Cooldown", { RetryAt = state.NextHpPotionUseTime })
		return false, "Cooldown"
	end
	local item = ItemConfig.GetById("hp_potion")
	local effect = item and item.effect
	local params = effect and effect.flagParams or nil
	local flagName = effect and effect.flagName or "HPRecovering"
	local duration = params and params.Duration or nil
	local cooldown = (item and item.useCooldown) or BalanceConfig.HpPotionCooldown

	local applied = self:ApplyFlag(player, flagName, duration, player, params)
	if not applied then
		self:_sendPotionFeedback(player, "Rejected")
		self:PublishState(player)
		return false, "Rejected"
	end

	state.HpPotions = math.max(0, (state.HpPotions or 0) - 1)
	state.NextHpPotionUseTime = now + cooldown
	self:PublishState(player)
	self:_sendPotionFeedback(player, "Consumed", { Count = state.HpPotions, CooldownEndTime = state.NextHpPotionUseTime })
	return true, nil
end

function PlayerStateService:_sendPotionFeedback(player: Player, result: string, payload: any?)
	local feedbackRemote = self._context.Remotes:FindFirstChild("GameplayFeedback") :: RemoteEvent?
	if feedbackRemote then
		local message = payload or {}
		message.Result = result
		feedbackRemote:FireClient(player, {
			EventType = "HpPotionUseResult",
			Payload = message,
		})
	end
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
	state.ActivePlayerMode = GameStates.PlayerMode.Launcher
	state.MovementState = MOVEMENT_STATE.Idle
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	state.CooldownEndTime = 0
	state.LastReleaseDuration = 0
	state.KnockbackStartTime = 0
	state.KnockbackStopEvidenceFrames = 0
	state.KnockbackImpactNormal = nil
	state.KnockbackHitTimestamp = 0
	state.KnockbackStunEndsAt = 0
	state.KnockbackInitialSpeed = 0
	state.KnockbackMaxEndsAt = 0
	state.DeathCountThisMatch = 0
	state.RespawnCountThisMatch = 0
	state.ForcedHuman = false
	state.FinalPhaseDeathConverted = false
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
	state.MovementState = if state.ActivePlayerMode == GameStates.PlayerMode.Human then MOVEMENT_STATE.Human else MOVEMENT_STATE.Idle
	state.CurrentVelocity = Vector3.zero
	state.ChargeValue = 0
	state.CooldownEndTime = 0
	state.LastReleaseDuration = 0
	state.KnockbackStartTime = 0
	state.KnockbackStopEvidenceFrames = 0
	state.KnockbackImpactNormal = nil
	state.KnockbackHitTimestamp = 0
	state.KnockbackStunEndsAt = 0
	state.KnockbackInitialSpeed = 0
	state.KnockbackMaxEndsAt = 0
	local flagService = getFlagService(self._context)
	state.ActiveFlags = if flagService then flagService:ResetPlayer(player) else {}
	self._launcherRuntime[player] = {}
	self:RecalculateDerivedStats(player, true)
end

local function cloneStateValue(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local clone = {}
	seen[value] = clone
	for key, childValue in pairs(value) do
		clone[cloneStateValue(key, seen)] = cloneStateValue(childValue, seen)
	end
	return clone
end

local function stateValuesEqual(left: any, right: any, seen: { [any]: { [any]: boolean } }?): boolean
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	seen = seen or {}
	seen[left] = seen[left] or {}
	if seen[left][right] then
		return true
	end
	seen[left][right] = true
	for key, leftValue in pairs(left) do
		if not stateValuesEqual(leftValue, right[key], seen) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

function PlayerStateService:PublishState(player: Player)
	local state = self._states[player]
	if not state then
		return
	end

	local lastPublishedState = self._lastPublishedStates[player]
	if lastPublishedState and stateValuesEqual(state, lastPublishedState) then
		return
	end

	self._lastPublishedStates[player] = cloneStateValue(state)
	if self._stateUpdateRemote then
		self._stateUpdateRemote:FireClient(player, state)
	end
	self._context.EventBus:Fire("PlayerStateUpdated", player, state)
end

function PlayerStateService:SetCharging(player: Player, isCharging: boolean, chargeValue: number)
	local state = self._states[player]
	if not state then return end
	state.IsCharging = isCharging
	state.ChargeValue = math.clamp(chargeValue, 0, 1)
	self:PublishState(player)
end


function PlayerStateService:_applyMovementState(player: Player, state: PlayerState, movementState: string)
	local previousState = state.MovementState
	state.MovementState = movementState
	if movementState == MOVEMENT_STATE.Knockback and previousState ~= MOVEMENT_STATE.Knockback then
		local now = os.clock()
		state.KnockbackStartTime = now
		state.KnockbackStunEndsAt = now + PhysicsConfig.Knockback.InitialStunSeconds
		state.KnockbackStopEvidenceFrames = 0
	elseif previousState == MOVEMENT_STATE.Knockback and movementState ~= MOVEMENT_STATE.Knockback then
		state.KnockbackStartTime = 0
		state.KnockbackStunEndsAt = 0
		state.KnockbackStopEvidenceFrames = 0
		state.KnockbackImpactNormal = nil
		state.KnockbackHitTimestamp = 0
		state.KnockbackInitialSpeed = 0
		state.KnockbackMaxEndsAt = 0
	end
	self:PublishState(player)
end

function PlayerStateService:CanTransitionMovementState(player: Player, movementState: string): (boolean, string?)
	local state = self._states[player]
	if not state then
		return false, "missing_state"
	end
	local previousState = state.MovementState
	if previousState == movementState then
		return true, nil
	end
	local transitions = GameStates.MovementStateTransitions[previousState]
	if not transitions or transitions[movementState] ~= true then
		return false, string.format("invalid_movement_transition:%s->%s", tostring(previousState), tostring(movementState))
	end
	return true, nil
end

function PlayerStateService:TrySetMovementState(player: Player, movementState: string): boolean
	local state = self._states[player]
	local allowed, reason = self:CanTransitionMovementState(player, movementState)
	if not allowed or not state then
		warn(string.format("[PlayerStateService] Rejected movement transition for %s: %s", playerName(player), reason or "unknown"))
		return false
	end
	self:_applyMovementState(player, state, movementState)
	return true
end

function PlayerStateService:ForceSetMovementState(player: Player, movementState: string)
	local state = self._states[player]
	if not state then return end
	self:_applyMovementState(player, state, movementState)
end

function PlayerStateService:SetMovementState(player: Player, movementState: string)
	warn(string.format("[PlayerStateService] SetMovementState is deprecated; use TrySetMovementState or ForceSetMovementState for %s", playerName(player)))
	return self:TrySetMovementState(player, movementState)
end

function PlayerStateService:RecordKnockbackImpact(player: Player, impactNormal: Vector3, hitTimestamp: number?, initialSpeed: number?)
	local state = self._states[player]
	if not state then return end
	local now = os.clock()
	local planarNormal = Vector3.new(impactNormal.X, 0, impactNormal.Z)
	local speed = math.max(if typeof(initialSpeed) == "number" then initialSpeed else 0, 0)
	local durationAlpha = math.clamp(speed / math.max(PhysicsConfig.Knockback.MaxDurationSpeedScale, 0.001), 0, 1)
	local maxDuration = PhysicsConfig.Knockback.MaxDurationMin
		+ ((PhysicsConfig.Knockback.MaxDurationMax - PhysicsConfig.Knockback.MaxDurationMin) * durationAlpha)
	state.KnockbackStartTime = now
	state.KnockbackStunEndsAt = now + PhysicsConfig.Knockback.InitialStunSeconds
	state.KnockbackStopEvidenceFrames = 0
	state.KnockbackImpactNormal = if planarNormal.Magnitude > PhysicsConfig.Movement.AimDeadzone then planarNormal.Unit else nil
	state.KnockbackHitTimestamp = hitTimestamp or now
	state.KnockbackInitialSpeed = speed
	state.KnockbackMaxEndsAt = now + maxDuration
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
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService or typeof(dataService.SpendDiamonds) ~= "function" then
		return false
	end
	local spent = dataService:SpendDiamonds(player, amount, "PlayerStateService")
	if spent then
		local state = self._states[player]
		if state then
			state.Diamonds = dataService:GetDiamonds(player)
			self:PublishState(player)
		end
	end
	return spent
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


function PlayerStateService:SyncEquipmentFromData(player: Player)
	local state = self._states[player]
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not (state and dataService and typeof(dataService.GetData) == "function") then return end
	local data = dataService:GetData(player)
	state.OwnedEquipment = data.OwnedEquipment or {}
	state.EquippedEquipment = data.EquippedEquipment or {}
	self:PublishState(player)
end

function PlayerStateService:GetOwnedEquipment(player: Player): { [string]: any }
	self:SyncEquipmentFromData(player)
	local state = self._states[player]
	return (state and state.OwnedEquipment) or {}
end

function PlayerStateService:GetEquippedEquipment(player: Player): { [any]: string }
	self:SyncEquipmentFromData(player)
	local state = self._states[player]
	return (state and state.EquippedEquipment) or {}
end

function PlayerStateService:GetEquipmentBySlot(player: Player, slot: any): string?
	local equipped = self:GetEquippedEquipment(player)
	return equipped[tonumber(slot) or slot]
end

function PlayerStateService:HasEquipment(player: Player, equipmentId: string): boolean
	local owned = self:GetOwnedEquipment(player)
	for _, instanceId in pairs(self:GetEquippedEquipment(player)) do
		local instance = owned[instanceId]
		if instance and instance.definitionId == equipmentId then return true end
	end
	return false
end

function PlayerStateService:EquipEquipment(player: Player, instanceId: string, slot: any?): (boolean, string?)
	local equipmentService = ServiceResolver.Get(self._context, "EquipmentService")
	if equipmentService and typeof(equipmentService.Equip) == "function" then return equipmentService:Equip(player, instanceId, slot) end
	return false, "MissingEquipmentService"
end

function PlayerStateService:UnequipEquipment(player: Player, slot: any): (boolean, string?)
	local equipmentService = ServiceResolver.Get(self._context, "EquipmentService")
	if equipmentService and typeof(equipmentService.Unequip) == "function" then return equipmentService:Unequip(player, slot) end
	return false, "MissingEquipmentService"
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
