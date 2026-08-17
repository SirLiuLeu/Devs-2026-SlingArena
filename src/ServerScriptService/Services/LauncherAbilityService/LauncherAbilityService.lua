--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local BaseAbility = require(script.Parent.Parent.Shared.BaseAbility)

local LauncherAbilityService = {}
LauncherAbilityService.__index = LauncherAbilityService

local function getService(context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

function LauncherAbilityService.new(context)
	local self = setmetatable({}, LauncherAbilityService)
	self._context = context
	self._abilityTriggerRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent?
	self._abilities = {} :: { [Player]: any }
	self._heartbeatConnection = nil
	return self
end

function LauncherAbilityService:Init()
	if self._abilityTriggerRemote then
		self._abilityTriggerRemote.OnServerEvent:Connect(function(player: Player, payload)
			self:_onAbilityTrigger(player, payload)
		end)
	end

	self._context.EventBus:On("ChargeStarted", function(player: Player)
		self:_handleChargeStarted(player)
	end)

	self._context.EventBus:On("LauncherLaunched", function(player: Player, chargeRatio: number, launchState: any)
		self:_handleLaunch(player, chargeRatio, launchState)
	end)

	-- Player collisions still notify launcher-specific ability callbacks; equipment status effects are handled by EquipmentEffectService.
	self._context.EventBus:On("CollisionPlayerHit", function(
		victim: Player,
		attacker: Player?,
		_rawDamage: number,
		_knockback: Vector3,
		collisionMeta: any
	)
		if attacker then
			self:_handleCollision(attacker, victim, collisionMeta)
		end
	end)

	self._context.EventBus:On("DamageDealt", function(attacker: Player)
		self:_revealIfStealth(attacker)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_destroyAbility(player)
	end)
end

function LauncherAbilityService:Start()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		local stateService = getService(self._context, "PlayerStateService")
		if stateService and typeof(stateService.TickFlags) == "function" then
			stateService:TickFlags(dt)
		end
		for _, player in Players:GetPlayers() do
			self:_ensureAbility(player):OnTick(dt)
		end
	end)
end

-- ── Ability helpers ──────────────────────────────────────────────────────────

function LauncherAbilityService:_onAbilityTrigger(player: Player, payload)
	if not RemoteContracts.Validate(RemoteContracts.Names.AbilityTrigger, payload) then
		return
	end
	local stateServiceForMode = getService(self._context, "PlayerStateService")
	if stateServiceForMode and stateServiceForMode:IsHuman(player) then
		return
	end
	-- AbilityTrigger is intentionally limited to ability activation. Launcher ownership/equip
	-- requests are handled by the dedicated EquipLauncher remote in PlayerService.
end
function LauncherAbilityService:_destroyAbility(player: Player)
	local ability = self._abilities[player]
	if ability then
		ability:OnDestroy()
		self._abilities[player] = nil
	end
end

function LauncherAbilityService:_ensureAbility(player: Player)
	local stateService = getService(self._context, "PlayerStateService")
	local abilityType = stateService and stateService:GetLauncherAbilityType(player) or "NormalLauncher"
	local config = AbilityConfig.GetById(abilityType) or AbilityConfig.GetById("NormalLauncher")
	local current = self._abilities[player]
	if current and current.Config == config then
		return current
	end
	self:_destroyAbility(player)
	local ability = BaseAbility.new(self._context, player, config)
	self._abilities[player] = ability
	ability:OnInit(nil)
	return ability
end

function LauncherAbilityService:_handleChargeStarted(player: Player)
	local ability = self:_ensureAbility(player)
	if ability.Config.invisibleWhileCharging then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:ApplyFlag(player, "Invisible", 9999, player)
		end
	end
end

function LauncherAbilityService:_handleLaunch(player: Player, chargeRatio: number, launchState: any)
	local ability = self:_ensureAbility(player)
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	local config = ability.Config
	if not (stateService and state and config) then
		return
	end

	if config.postLaunchInvisibleDuration then
		stateService:RemoveFlag(player, "Invisible")
		stateService:ApplyFlag(player, "Invisible", config.postLaunchInvisibleDuration, player)
	elseif config.invisibleWhileCharging then
		stateService:RemoveFlag(player, "Invisible")
	end

	local passiveHealPercent = 0
	local launcherDef = LauncherConfig.GetById(state.LaunchershotType or "")
	local passiveAbility = launcherDef and launcherDef.passiveAbility or nil
	if type(passiveAbility) == "table" and passiveAbility.type == "HealOnLaunch" then
		passiveHealPercent = math.max(0, tonumber(passiveAbility.percent) or 0)
	end
	local healPercent = math.max(passiveHealPercent, tonumber(config.healOnLaunchMaxHpPercent) or 0)
	if healPercent > 0 then
		stateService:Heal(player, state.MaxHP * healPercent)
	end

	if config.moveSpeedPerLaunchPercent then
		local runtime = stateService:GetLauncherRuntime(player)
		local maxStacks = config.maxMoveSpeedStacks or 10
		local previousStacks = runtime.SpeedStacks or 0
		if previousStacks < maxStacks then
			runtime.SpeedStacks = previousStacks + 1
			state.MoveSpeed *= (1 + config.moveSpeedPerLaunchPercent)
			stateService:PublishState(player)
		end
	end

	if config.clientScanOnly then
		local playerService = getService(self._context, "PlayerService")
		local root = playerService and playerService:GetRoot(player)
		self._context.EventBus:Fire("AbilityVacuumPulse", player, {
			Center = root and root.Position or nil,
			Radius = config.scanRadius,
		})
	end

	ability:OnLaunch({ ChargeRatio = chargeRatio, LaunchState = launchState })
end

function LauncherAbilityService:_revealIfStealth(player: Player)
	local ability = self:_ensureAbility(player)
	if ability.Config.revealOnCollision then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:RemoveFlag(player, "Invisible")
		end
	end
end

-- Applies collision effects to the victim. The attacker is not modified here except for ally healing.
function LauncherAbilityService:_handleCollision(attacker: Player, victim: Player, collisionMeta: any)
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return
	end
	if stateService:IsHuman(attacker) or stateService:IsHuman(victim) or stateService:HasFlag(attacker, "Ghost") or stateService:HasFlag(victim, "Ghost") then
		return
	end
	local ability = self:_ensureAbility(attacker)
	local config = ability.Config
	local attackerState = stateService:GetState(attacker)
	if not (config and attackerState) then
		return
	end

	self:_revealIfStealth(attacker)

	local teamService = getService(self._context, "TeamService")
	local isFriendly = teamService and teamService:IsFriendly(attacker, victim)

	-- SupportLauncher: heal allies, no damage.
	if config.healAllyOnCollision and isFriendly then
		stateService:Heal(victim, (attackerState.BaseDamage or 0) * config.healAmountBaseDamageMultiplier)
		return
	end

	if isFriendly then
		return
	end

	-- Equipment-owned collision status effects now execute through EquipmentEffectService.
	-- LauncherAbilityService keeps launcher-specific ability callbacks and legacy launcher-only passives.

	ability:OnCollision({ TargetPlayer = victim, CollisionMeta = collisionMeta })
end

return LauncherAbilityService