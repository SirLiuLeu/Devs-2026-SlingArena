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

-- Food burn state: tracks active burn DoT per food model (keyed by foodId string).
-- Structure: { [foodId]: { stacks: number, damagePerTick: number, tickInterval: number,
--              maxStacks: number, lastTickAt: number, expiresAt: number, instigator: Player? } }
local _foodBurnState: { [string]: any } = {}

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

	-- FIX 4: CollisionPlayerHit – apply effect (CC / DoT) to the VICTIM only.
	-- The attacker triggers the ability; the victim receives the effect.
	-- We also fire food-burn logic here when the attacker is a FireSling.
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

	-- FIX 5: When a Launching FireSling player collides with an HP-food,
	-- apply a burn DoT to that food so it takes periodic damage.
	self._context.EventBus:On("CollisionDetected", function(
		collisionType: string,
		player: Player,
		_target: any,
		_meta: any
	)
		if collisionType ~= "Food" then
			return
		end
		self:_tryApplyFoodBurn(player)
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
		-- FIX 5: Tick food burn DoT state.
		self:_tickFoodBurn()
	end)
end

-- ── Food burn (FireSling DoT on HP food) ────────────────────────────────────

function SlingAbilityService:_tryApplyFoodBurn(player: Player)
	local ability = self:_ensureAbility(player)
	local config = ability.Config
	if not (config and config.dotFlag == "Burn") then
		return
	end
	-- Find the food entity the FireSling player just collided with.
	-- FoodService stores FoodId as an attribute on the food model.
	-- We look through the active food container near the player's position.
	local playerService = getService(self._context, "PlayerService")
	local root = playerService and playerService:GetRoot(player)
	if not root then
		return
	end
	local pos = root.Position

	local Workspace = game:GetService("Workspace")
	local maps = Workspace:FindFirstChild("Maps")
	if not maps then return end
	for _, map in ipairs(maps:GetChildren()) do
		local container = map:FindFirstChild("FoodContainer")
		if not (container and container:IsA("Folder")) then continue end
		for _, food in ipairs(container:GetChildren()) do
			if not food:IsA("Model") then continue end
			local foodId = food:GetAttribute("FoodId")
			if typeof(foodId) ~= "string" then continue end
			local hitbox = food:FindFirstChild("Hitbox")
			if not (hitbox and hitbox:IsA("BasePart")) then continue end
			local dist = (hitbox.Position - pos).Magnitude
			-- Only apply if within close range (collision just happened).
			if dist > 12 then continue end
			self:_applyFoodBurnFlag(food, foodId, config, player)
		end
	end
end

function SlingAbilityService:_applyFoodBurnFlag(food: Model, foodId: string, config: any, instigator: Player?)
	local existing = _foodBurnState[foodId]
	local maxStacks = math.max(1, config.dotMaxStack or 3)
	local stacks = existing and math.min((existing.stacks or 0) + 1, maxStacks) or 1
	local duration = config.dotDuration or 4
	_foodBurnState[foodId] = {
		food = food,
		stacks = stacks,
		damagePerTick = config.dotDamagePerTick or 250,
		tickInterval = config.dotTickInterval or 1,
		maxStacks = maxStacks,
		lastTickAt = os.clock(),
		expiresAt = os.clock() + duration,
		instigator = instigator,
	}
	warn(string.format(
		"[SlingAbility] Food burn applied: foodId=%s stacks=%d instigator=%s",
		foodId, stacks, instigator and instigator.Name or "nil"
	))
end

function SlingAbilityService:_tickFoodBurn()
	local now = os.clock()
	local toRemove = {}
	for foodId, burnData in pairs(_foodBurnState) do
		local food = burnData.food
		if not (food and food.Parent) then
			table.insert(toRemove, foodId)
			continue
		end
		if now >= burnData.expiresAt then
			table.insert(toRemove, foodId)
			continue
		end
		if now - burnData.lastTickAt >= burnData.tickInterval then
			burnData.lastTickAt = now
			local totalDamage = burnData.damagePerTick * burnData.stacks
			-- Reduce food HP directly via attribute; FoodService will react.
			local currentHp = food:GetAttribute("FoodHP")
			if typeof(currentHp) == "number" and currentHp > 0 then
				local newHp = math.max(0, currentHp - totalDamage)
				food:SetAttribute("FoodHP", newHp)
				warn(string.format(
					"[SlingAbility] Food burn tick: foodId=%s dmg=%.0f newHP=%.0f",
					foodId, totalDamage, newHp
				))
				if newHp <= 0 then
					-- Notify FoodService to finalize the food kill.
					self._context.EventBus:Fire("FoodBurnKill", food, burnData.instigator)
					table.insert(toRemove, foodId)
				end
			else
				table.insert(toRemove, foodId)
			end
		end
	end
	for _, foodId in ipairs(toRemove) do
		_foodBurnState[foodId] = nil
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

-- FIX 4: _handleCollision – apply the correct effect to VICTIM only.
-- All effects (Stun, Burn, Poison, Petrify) are applied to `victim`.
-- The attacker is never modified here (except for SupportSling healing allies).
-- Effect data now includes the Effect key for particle emitters and the Material
-- key for Petrify, matching what PlayerStateService._applyFlagVisual expects.
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

	-- FIX 4a: Petrify cannot be applied to FireSling (immune to frost).
	if config.collisionFlag == "Petrify" then
		local victimAbilityType = stateService:GetSlingAbilityType(victim)
		if config.cannotPetrifyAbilityTypes and config.cannotPetrifyAbilityTypes[victimAbilityType] then
			warn(string.format("[SlingAbility] Petrify blocked: victim=%s is immune (%s)",
				victim.Name, victimAbilityType))
			return
		end
	end

	-- FIX 4b: Hard CC (Stun / Petrify) applied to victim with correct Effect data
	-- so that PlayerStateService._applyFlagVisual can attach the particle emitter.
	if config.collisionFlag then
		local effectData: any = {
			Effect = config.collisionEffect,    -- e.g. "Frost" for Petrify, "Stun" for Stun
			Material = config.collisionMaterial, -- Enum.Material.Pebble for Petrify, nil for Stun
		}
		warn(string.format(
			"[SlingAbility] Applying flag %s to %s (from %s, effect=%s)",
			config.collisionFlag, victim.Name, attacker.Name, tostring(config.collisionEffect)
		))
		stateService:ApplyFlag(victim, config.collisionFlag, config.collisionCCDuration, attacker, effectData)
	end

	-- FIX 4c: DoT (Burn / Poison) applied to victim with correct Effect data
	-- so the particle emitter (Fire or Poison) attaches to the victim's pawn.
	if config.dotFlag then
		local dotData: any = {
			Effect = config.dotEffect,           -- "Fire" for Burn, "Poison" for Poison
			Stackable = true,
			MaxStack = config.dotMaxStack,
			TickInterval = config.dotTickInterval,
			DamagePerTick = config.dotDamagePerTick,
		}
		warn(string.format(
			"[SlingAbility] Applying DoT %s to %s (from %s, stacks up to %d)",
			config.dotFlag, victim.Name, attacker.Name, config.dotMaxStack or 1
		))
		stateService:ApplyFlag(victim, config.dotFlag, config.dotDuration, attacker, dotData)
	end

	-- FIX 4d: Slow (PoisonSling) applied to victim.
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