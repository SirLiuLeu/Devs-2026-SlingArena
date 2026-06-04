--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local BaseAbility = require(script.Parent.BaseAbility)

local SlingAbilityService = {}
SlingAbilityService.__index = SlingAbilityService

local function getService(context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

-- Food DoT state: tracks active Burn/Poison effects per food model and flag name.
local _foodDotState: { [string]: any } = {}

function SlingAbilityService.new(context)
	local self = setmetatable({}, SlingAbilityService)
	self._context = context
	self._abilityTriggerRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent?
	self._abilities = {} :: { [Player]: any }
	self._heartbeatConnection = nil
	return self
end

function SlingAbilityService:Init()
	if self._abilityTriggerRemote then
		self._abilityTriggerRemote.OnServerEvent:Connect(function(player: Player, payload)
			self:_onAbilityTrigger(player, payload)
		end)
	end

	self._context.EventBus:On("ChargeStarted", function(player: Player)
		self:_handleChargeStarted(player)
	end)

	self._context.EventBus:On("SlingLaunched", function(player: Player, chargeRatio: number, launchState: any)
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

function SlingAbilityService:Start()
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

function SlingAbilityService:_tryApplyFoodDot(player: Player, target: any)
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

local function getDotSourceKey(instigator: Player?): string
	if instigator then
		return tostring(instigator.UserId)
	end
	return "environment"
end

function SlingAbilityService:_applyFoodDot(food: Model, foodId: string, config: any, instigator: Player?)
	local flagName = config.dotFlag
	local stateKey = string.format("%s:%s", foodId, flagName)
	local existing = _foodDotState[stateKey]
	local now = os.clock()
	local sources = (existing and existing.sources) or {}
	local sourceKey = getDotSourceKey(instigator)
	local existingSource = sources[sourceKey]
	sources[sourceKey] = {
		instigator = instigator,
		lastTickAt = existingSource and existingSource.lastTickAt or now,
		expiresAt = now + (config.dotDuration or 0),
	}
	_foodDotState[stateKey] = {
		food = food,
		foodId = foodId,
		flagName = flagName,
		damagePerTick = config.dotDamagePerTick or 0,
		tickInterval = config.dotTickInterval or 1,
		sources = sources,
	}
end

function SlingAbilityService:_tickFoodDots()
	local now = os.clock()
	local toRemove = {}
	local foodService = getService(self._context, "FoodService")
	for stateKey, dotData in pairs(_foodDotState) do
		local food = dotData.food
		if not (food and food.Parent) then
			table.insert(toRemove, stateKey)
			continue
		end
		if not (foodService and typeof(foodService.ApplyDamageToFood) == "function") then
			table.insert(toRemove, stateKey)
			continue
		end
		local hasActiveSource = false
		for sourceKey, sourceData in pairs(dotData.sources or {}) do
			if now >= sourceData.expiresAt then
				dotData.sources[sourceKey] = nil
				continue
			end
			hasActiveSource = true
			if now - (sourceData.lastTickAt or now) >= dotData.tickInterval then
				sourceData.lastTickAt = now
				local damage = math.max(0, dotData.damagePerTick or 0)
				if damage > 0 then
					local damaged = foodService:ApplyDamageToFood(food, damage, sourceData.instigator)
					if not damaged or not food.Parent then
						table.insert(toRemove, stateKey)
						break
					end
				end
			end
		end
		if not hasActiveSource then
			table.insert(toRemove, stateKey)
		end
	end
	for _, stateKey in ipairs(toRemove) do
		_foodDotState[stateKey] = nil
	end
end

-- ── Ability helpers ──────────────────────────────────────────────────────────

function SlingAbilityService:_onAbilityTrigger(player: Player, payload)
	if not RemoteContracts.Validate(RemoteContracts.Names.AbilityTrigger, payload) then
		return
	end
	if type(payload) == "table" and payload.action == "EquipSling" and typeof(payload.slingId) == "string" then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService and stateService:SetSlingType(player, payload.slingId) then
			local playerService = getService(self._context, "PlayerService")
			if playerService and typeof(playerService.EquipSlingModel) == "function" then
				playerService:EquipSlingModel(player, payload.slingId)
			end
			self:_destroyAbility(player)
			self:_ensureAbility(player):OnInit(nil)
		end
	end
end

function SlingAbilityService:_destroyAbility(player: Player)
	local ability = self._abilities[player]
	if ability then
		ability:OnDestroy()
		self._abilities[player] = nil
	end
end

function SlingAbilityService:_ensureAbility(player: Player)
	local stateService = getService(self._context, "PlayerStateService")
	local abilityType = stateService and stateService:GetSlingAbilityType(player) or "NormalSling"
	local config = AbilityConfig.GetById(abilityType) or AbilityConfig.GetById("NormalSling")
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

function SlingAbilityService:_handleChargeStarted(player: Player)
	local ability = self:_ensureAbility(player)
	if ability.Config.invisibleWhileCharging then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:ApplyFlag(player, "Invisible", 9999, player)
		end
	end
end

function SlingAbilityService:_handleLaunch(player: Player, chargeRatio: number, launchState: any)
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

	if config.healOnLaunchMaxHpPercent then
		stateService:Heal(player, state.MaxHP * config.healOnLaunchMaxHpPercent)
	end

	if config.moveSpeedPerLaunchPercent then
		local runtime = stateService:GetSlingRuntime(player)
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

function SlingAbilityService:_revealIfStealth(player: Player)
	local ability = self:_ensureAbility(player)
	if ability.Config.revealOnCollision then
		local stateService = getService(self._context, "PlayerStateService")
		if stateService then
			stateService:RemoveFlag(player, "Invisible")
		end
	end
end

-- Applies collision effects to the victim. The attacker is not modified here except for ally healing.
function SlingAbilityService:_handleCollision(attacker: Player, victim: Player, collisionMeta: any)
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return
	end
	if stateService:HasFlag(attacker, "Ghost") or stateService:HasFlag(victim, "Ghost") then
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

	-- SupportSling: heal allies, no damage.
	if config.healAllyOnCollision and isFriendly then
		stateService:Heal(victim, (attackerState.BaseDamage or 0) * config.healAmountBaseDamageMultiplier)
		return
	end

	if isFriendly then
		return
	end

	-- Petrify cannot be applied to FireSling (immune to frost).
	if config.collisionFlag == "Petrify" then
		local victimAbilityType = stateService:GetSlingAbilityType(victim)
		if config.cannotPetrifyAbilityTypes and config.cannotPetrifyAbilityTypes[victimAbilityType] then
			return
		end
	end

	-- Hard CC flags include visual effect data for FlagService.
	if config.collisionFlag then
		local effectData: any = {
			Effect = config.collisionEffect,    -- e.g. "Frost" for Petrify, "Stun" for Stun
			Material = config.collisionMaterial, -- Enum.Material.Pebble for Petrify, nil for Stun
		}
		stateService:ApplyFlag(victim, config.collisionFlag, config.collisionCCDuration, attacker, effectData)
	end

	-- Burn/Poison uses the same stack, refresh, tick, and duration settings as food DoT.
	if config.dotFlag then
		local dotData: any = {
			Effect = config.dotEffect,           -- "Fire" for Burn, "Poison" for Poison
			SourceScoped = true,
			Stackable = true,
			MaxStack = config.dotMaxStack,
			TickInterval = config.dotTickInterval,
			DamagePerTick = config.dotDamagePerTick,
		}
		stateService:ApplyFlag(victim, config.dotFlag, config.dotDuration, attacker, dotData)
	end

	-- Poison also applies a stackable slow.
	if config.slowAmount then
		stateService:ApplyFlag(victim, "Slow", config.slowDuration, attacker, {
			Stackable = true,
			MaxStack = 3,
			SlowAmount = config.slowAmount,
		})
	end

	ability:OnCollision({ TargetPlayer = victim, CollisionMeta = collisionMeta })
end

return SlingAbilityService