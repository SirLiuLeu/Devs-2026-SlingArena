--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local BaseAbility = require(script.Parent.BaseAbility)

local EquipmentAbilityService = {}
EquipmentAbilityService.__index = EquipmentAbilityService

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

function EquipmentAbilityService.new(context)
	local self = setmetatable({}, EquipmentAbilityService)
	self._context = context
	self._abilityTriggerRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent?
	self._abilities = {} :: { [Player]: { [string]: any } }
	self._heartbeatConnection = nil
	return self
end

function EquipmentAbilityService:Init()
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

function EquipmentAbilityService:Start()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			self:_syncPlayerAbilities(player)
			local abilities = self._abilities[player]
			if abilities then
				for _, ability in pairs(abilities) do
					ability:OnTick(dt)
				end
			end
		end
		self:_tickFoodDots()
	end)
end

-- ── Food Burn/Poison DoT ─────────────────────────────────────────────────────

function EquipmentAbilityService:_tryApplyFoodDot(player: Player, target: any)
	local stateServiceForMode = getService(self._context, "PlayerStateService")
	if stateServiceForMode and stateServiceForMode:IsHuman(player) then
		return
	end
	local configs = self:_getActiveAbilityConfigs(player)
	local config = nil
	for _, candidate in ipairs(configs) do
		if candidate.dotFlag then
			config = candidate
			break
		end
	end
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

function EquipmentAbilityService:_applyFoodDot(food: Model, foodId: string, config: any, instigator: Player?)
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

function EquipmentAbilityService:_tickFoodDots()
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

function EquipmentAbilityService:_onAbilityTrigger(_player: Player, _payload)
	-- Launcher equip requests remain owned by LauncherAbilityService during migration.
end

function EquipmentAbilityService:_destroyAbility(player: Player, instanceId: string?)
	local abilities = self._abilities[player]
	if not abilities then return end
	if instanceId then
		local ability = abilities[instanceId]
		if ability then ability:OnDestroy(); abilities[instanceId] = nil end
		return
	end
	for _, ability in pairs(abilities) do ability:OnDestroy() end
	self._abilities[player] = nil
end

function EquipmentAbilityService:_getEquippedEquipment(player: Player): ({ [any]: string }, { [string]: any })
	local stateService = getService(self._context, "PlayerStateService")
	if stateService and typeof(stateService.GetEquippedEquipment) == "function" then
		return stateService:GetEquippedEquipment(player), stateService:GetOwnedEquipment(player)
	end
	local dataService = getService(self._context, "PlayerDataService")
	if dataService then return dataService:GetEquippedEquipment(player), dataService:GetOwnedEquipment(player) end
	return {}, {}
end

function EquipmentAbilityService:_getActiveAbilityConfigs(player: Player): { any }
	local equipped, owned = self:_getEquippedEquipment(player)
	local configs = {}
	for _, instanceId in pairs(equipped) do
		local ownedInstance = owned[instanceId]
		local definition = ownedInstance and EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
		if definition then
			local config = table.clone(definition.combatEffect or {})
			config.id = definition.abilityId or definition.id
			local passive = definition.passiveAbility
			if type(passive) == "table" and passive.type == "HealOnLaunch" then
				config.healOnLaunchMaxHpPercent = math.max(tonumber(config.healOnLaunchMaxHpPercent) or 0, tonumber(passive.percent) or 0)
			end
			table.insert(configs, config)
		end
	end
	return configs
end

function EquipmentAbilityService:_ensureAbility(player: Player, instanceId: string, config: any)
	local abilities = self._abilities[player]
	if not abilities then abilities = {}; self._abilities[player] = abilities end
	local current = abilities[instanceId]
	if current and current.Config == config then return current end
	if current then current:OnDestroy() end
	local ability = BaseAbility.new(self._context, player, config)
	abilities[instanceId] = ability
	ability:OnInit(nil)
	return ability
end

function EquipmentAbilityService:_syncPlayerAbilities(player: Player)
	local equipped, owned = self:_getEquippedEquipment(player)
	local seen = {}
	for _, instanceId in pairs(equipped) do
		local ownedInstance = owned[instanceId]
		local definition = ownedInstance and EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
		if definition then
			seen[instanceId] = true
			local config = table.clone(definition.combatEffect or {})
			config.id = definition.abilityId or definition.id
			self:_ensureAbility(player, instanceId, config)
		end
	end
	local abilities = self._abilities[player]
	if abilities then
		for instanceId in pairs(abilities) do if not seen[instanceId] then self:_destroyAbility(player, instanceId) end end
	end
end

function EquipmentAbilityService:_handleChargeStarted(player: Player)
	self:_syncPlayerAbilities(player)
	local ability = { Config = {} }
	if ability.Config.invisibleWhileCharging then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:ApplyFlag(player, "Invisible", 9999, player)
		end
	end
end

function EquipmentAbilityService:_handleLaunch(player: Player, chargeRatio: number, launchState: any)
	self:_syncPlayerAbilities(player)
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not (stateService and state) then return end
	local configs = self:_getActiveAbilityConfigs(player)

	for _, config in ipairs(configs) do
	if config.postLaunchInvisibleDuration then
		stateService:RemoveFlag(player, "Invisible")
		stateService:ApplyFlag(player, "Invisible", config.postLaunchInvisibleDuration, player)
	elseif config.invisibleWhileCharging then
		stateService:RemoveFlag(player, "Invisible")
	end

	local healPercent = math.max(0, tonumber(config.healOnLaunchMaxHpPercent) or 0)
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

		local ability = BaseAbility.new(self._context, player, config)
		ability:OnLaunch({ ChargeRatio = chargeRatio, LaunchState = launchState })
	end
end

function EquipmentAbilityService:_revealIfStealth(player: Player)
	self:_syncPlayerAbilities(player)
	local ability = { Config = {} }
	if ability.Config.revealOnCollision then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:RemoveFlag(player, "Invisible")
		end
	end
end

-- Applies collision effects to the victim. The attacker is not modified here except for ally healing.
function EquipmentAbilityService:_handleCollision(attacker: Player, victim: Player, collisionMeta: any)
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return
	end
	if stateService:IsHuman(attacker) or stateService:IsHuman(victim) or stateService:HasFlag(attacker, "Ghost") or stateService:HasFlag(victim, "Ghost") then
		return
	end
	self:_syncPlayerAbilities(attacker)
	local configs = self:_getActiveAbilityConfigs(attacker)
	local attackerState = stateService:GetState(attacker)
	if not attackerState then return end

	self:_revealIfStealth(attacker)

	local teamService = getService(self._context, "TeamService")
	local isFriendly = teamService and teamService:IsFriendly(attacker, victim)

	if isFriendly then
		return
	end

	for _, config in ipairs(configs) do
	-- Petrify cannot be applied to FireLauncher (immune to frost).
	if config.collisionFlag == "Petrify" then
		if false then
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

		local ability = BaseAbility.new(self._context, attacker, config)
		ability:OnCollision({ TargetPlayer = victim, CollisionMeta = collisionMeta })
	end
end

return EquipmentAbilityService