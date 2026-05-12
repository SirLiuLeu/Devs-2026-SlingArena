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
	self._context.EventBus:On("CollisionPlayerHit", function(victim: Player, attacker: Player?, _rawDamage: number, _knockback: Vector3, collisionMeta: any)
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
	end)
end

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
	if config.healAllyOnCollision and isFriendly then
		stateService:Heal(victim, (attackerState.BaseDamage or 0) * config.healAmountBaseDamageMultiplier)
		return
	end

	if isFriendly then
		return
	end

	if config.collisionFlag == "Freeze" then
		local victimAbilityType = stateService:GetSlingAbilityType(victim)
		if config.cannotFreezeAbilityTypes and config.cannotFreezeAbilityTypes[victimAbilityType] then
			return
		end
	end
	if config.collisionFlag then
		stateService:ApplyFlag(victim, config.collisionFlag, config.collisionCCDuration, attacker)
	end
	if config.dotFlag then
		stateService:ApplyFlag(victim, config.dotFlag, config.dotDuration, attacker, {
			Stackable = true,
			MaxStack = config.dotMaxStack,
			TickInterval = config.dotTickInterval,
			DamagePerTick = config.dotDamagePerTick,
		})
	end
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
