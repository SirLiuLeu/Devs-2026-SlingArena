--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local BaseAbility = require(script.Parent.BaseAbility)

local LauncherAbilityService = {}
LauncherAbilityService.__index = LauncherAbilityService

local function getService(context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function getFlagConfig(flagName: string): any
	return GameConfig.FlagConfig[flagName] or {}
end

local function getCollisionTransferredVelocity(collisionMeta: any): number
	if collisionMeta and typeof(collisionMeta.TransferredVelocity) == "number" then
		return math.max(0, collisionMeta.TransferredVelocity)
	end
	if collisionMeta and typeof(collisionMeta.TransferredVelocityVector) == "Vector3" then
		return collisionMeta.TransferredVelocityVector.Magnitude
	end
	return 0
end

local function resolveImpactScaledFlagDuration(flagName: string, collisionMeta: any, fallbackDuration: number?): number
	local flagConfig = getFlagConfig(flagName)
	local baseDuration = math.max(0, fallbackDuration or flagConfig.Duration or 0)
	local maxLaunchSpeed = math.max(PhysicsConfig.Launch.SpeedMax or 0, 0.001)
	return (getCollisionTransferredVelocity(collisionMeta) / maxLaunchSpeed) * baseDuration
end

-- Food DoT state: tracks active Burn/Poison effects per food model, flag name, and attacker user ID.
local _foodDotState: { [string]: any } = {}

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

	-- Player collisions apply the attacker's effect to the victim only.
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

	self._context.EventBus:On("CollisionDetected", function(
		collisionType: string,
		player: Player,
		target: any,
		_meta: any
	)
		if collisionType ~= "Food" then
			return
		end
		self:_tryApplyFoodDot(player, target)
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
		self:_tickFoodDots()
	end)
end

-- ── Food Burn/Poison DoT ─────────────────────────────────────────────────────

function LauncherAbilityService:_tryApplyFoodDot(player: Player, target: any)
	local stateServiceForMode = getService(self._context, "PlayerStateService")
	if stateServiceForMode and stateServiceForMode:IsHuman(player) then
		return
	end
	local ability = self:_ensureAbility(player)
	local config = ability.Config
	if not (config and config.dotFlag) then
		return
	end
	if not (target and typeof(target) == "Instance" and target:IsA("Model")) then
		return
	end
	local foodId = target:GetAttribute("FoodId")
	if typeof(foodId) ~= "string" then
		return
	end
	self:_applyFoodDot(target, foodId, config, player)
end

function LauncherAbilityService:_applyFoodDot(food: Model, foodId: string, config: any, instigator: Player?)
	local flagName = config.dotFlag
	local flagConfig = getFlagConfig(flagName)
	local instigatorUserId = instigator and instigator.UserId or 0
	local stateKey = string.format("%s:%s:%d", foodId, flagName, instigatorUserId)
	local existing = _foodDotState[stateKey]
	local maxStack = math.max(1, flagConfig.MaxStack or 1)
	local stacks = math.clamp((existing and (existing.stacks or 1) or 0) + 1, 1, maxStack)
	local now = os.clock()
	_foodDotState[stateKey] = {
		food = food,
		foodId = foodId,
		flagName = flagName,
		stacks = stacks,
		damagePerTick = flagConfig.DamagePerTick or 0,
		tickInterval = flagConfig.TickInterval or 1,
		lastTickAt = existing and existing.lastTickAt or now,
		expiresAt = now + (flagConfig.Duration or 0),
		instigator = instigator,
		instigatorUserId = instigatorUserId,
	}
end

function LauncherAbilityService:_tickFoodDots()
	local now = os.clock()
	local toRemove = {}
	for stateKey, dotData in pairs(_foodDotState) do
		local food = dotData.food
		if not (food and food.Parent) or now >= dotData.expiresAt then
			table.insert(toRemove, stateKey)
			continue
		end
		if now - (dotData.lastTickAt or now) >= dotData.tickInterval then
			dotData.lastTickAt = now
			local totalDamage = math.max(0, dotData.damagePerTick or 0) * math.max(1, dotData.stacks or 1)
			if totalDamage <= 0 then
				continue
			end
			local foodService = getService(self._context, "FoodService")
			if not (foodService and typeof(foodService.ApplyDamageToFood) == "function") then
				table.insert(toRemove, stateKey)
				continue
			end
			local damaged = foodService:ApplyDamageToFood(food, totalDamage, dotData.instigator)
			if not damaged or not food.Parent then
				table.insert(toRemove, stateKey)
			end
		end
	end
	for _, stateKey in ipairs(toRemove) do
		_foodDotState[stateKey] = nil
	end
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
	if type(payload) == "table" and payload.action == "EquipLauncher" and typeof(payload.launcherId) == "string" then
		local stateService = getService(self._context, "PlayerStateService")
		local equipped = false
		if stateService and typeof(payload.instanceId) == "string" and typeof(stateService.SetEquippedLauncherInstance) == "function" then
			equipped = stateService:SetEquippedLauncherInstance(player, payload.instanceId)
		end
		if stateService and (equipped or stateService:SetLauncherType(player, payload.launcherId)) then
			local playerService = getService(self._context, "PlayerService")
			if playerService and typeof(playerService.EquipLauncherModel) == "function" then
				playerService:EquipLauncherModel(player, payload.launcherId)
			end
			self:_destroyAbility(player)
			self:_ensureAbility(player):OnInit(nil)
		end
	end
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

	-- Petrify cannot be applied to FireLauncher (immune to frost).
	if config.collisionFlag == "Petrify" then
		local victimAbilityType = stateService:GetLauncherAbilityType(victim)
		if config.cannotPetrifyAbilityTypes and config.cannotPetrifyAbilityTypes[victimAbilityType] then
			return
		end
	end

	-- Hard CC duration scales with the actual velocity transferred to the defender.
	if config.collisionFlag then
		local flagName = config.collisionFlag
		local duration = resolveImpactScaledFlagDuration(flagName, collisionMeta, config.collisionExtraDuration)
		stateService:ApplyFlag(victim, flagName, duration, attacker)

		-- RCA Fix E: injected after hard CC application to notify the victim client explicitly.
		local feedbackRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
		if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
			feedbackRemote:FireClient(victim, {
				EventType = "CCApplied",
				Payload = { FlagName = flagName, Duration = duration },
			})
		end
	end

	-- Burn/Poison use centralized flag config for duration, stacking, ticks, damage, slow, and VFX.
	if config.dotFlag then
		local flagName = config.dotFlag
		local flagConfig = getFlagConfig(flagName)
		stateService:ApplyFlag(victim, flagName, flagConfig.Duration, attacker, {
			Stackable = flagConfig.Stackable,
			MaxStack = flagConfig.MaxStack,
			TickInterval = flagConfig.TickInterval,
			DamagePerTick = flagConfig.DamagePerTick,
		})

		if flagConfig.SlowAmount then
			local slowConfig = getFlagConfig("Slow")
			stateService:ApplyFlag(victim, "Slow", flagConfig.SlowDuration or slowConfig.Duration, attacker, {
				Stackable = slowConfig.Stackable,
				MaxStack = slowConfig.MaxStack,
				SlowAmount = flagConfig.SlowAmount,
			})
		end
	end

	ability:OnCollision({ TargetPlayer = victim, CollisionMeta = collisionMeta })
end

return LauncherAbilityService