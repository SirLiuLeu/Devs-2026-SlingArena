--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
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

function EquipmentAbilityService.new(context)
	local self = setmetatable({}, EquipmentAbilityService)
	self._context = context
	self._abilityTriggerRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent?
	self._abilities = {} :: { [Player]: { [string]: any } }
	self._heartbeatConnection = nil
	self._abilityConfigs = {} :: { [Player]: { [string]: any } }
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
	end)
end

-- ── Ability helpers ──────────────────────────────────────────────────────────

function EquipmentAbilityService:_onAbilityTrigger(_player: Player, _payload)
end

function EquipmentAbilityService:_destroyAbility(player: Player, instanceId: string?)
	local abilities = self._abilities[player]
	if not abilities then return end
	if instanceId then
		local ability = abilities[instanceId]
		if ability then ability:OnDestroy(); abilities[instanceId] = nil end
		if self._abilityConfigs[player] then self._abilityConfigs[player][instanceId] = nil end
		return
	end
	for _, ability in pairs(abilities) do ability:OnDestroy() end
	self._abilities[player] = nil
	self._abilityConfigs[player] = nil
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

function EquipmentAbilityService:_ensureAbility(player: Player, instanceId: string, config: any)
	local abilities = self._abilities[player]
	if not abilities then
		abilities = {}
		self._abilities[player] = abilities
	end
	local configs = self._abilityConfigs[player]
	if not configs then
		configs = {}
		self._abilityConfigs[player] = configs
	end
	if abilities[instanceId] then
		return abilities[instanceId]
	end
	local ability = BaseAbility.new(self._context, player, config)
	abilities[instanceId] = ability
	configs[instanceId] = config
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
			local passive = definition.passiveAbility
			if type(passive) == "table" and passive.type == "HealOnLaunch" then
				config.healOnLaunchMaxHpPercent = math.max(tonumber(config.healOnLaunchMaxHpPercent) or 0, tonumber(passive.percent) or 0)
			end
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
	local stateService = getService(self._context, "PlayerStateService")
	local configs = self._abilityConfigs[player] or {}
	for _, config in pairs(configs) do
		if config.invisibleWhileCharging and stateService then
			stateService:ApplyFlag(player, "Invisible", 9999, player)
		end
	end
end

function EquipmentAbilityService:_handleLaunch(player: Player, chargeRatio: number, launchState: any)
	self:_syncPlayerAbilities(player)
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not (stateService and state) then return end
	local abilities = self._abilities[player]
	local configs = self._abilityConfigs[player] or {}

	for instanceId, config in pairs(configs) do
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

		local ability = abilities and abilities[instanceId]
		if ability then
			ability:OnLaunch({ ChargeRatio = chargeRatio, LaunchState = launchState })
		end
	end
end

function EquipmentAbilityService:_revealIfStealth(player: Player)
	self:_syncPlayerAbilities(player)
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then return end
	for _, config in pairs(self._abilityConfigs[player] or {}) do
		if config.revealOnCollision then
			stateService:RemoveFlag(player, "Invisible")
			return
		end
	end
end

function EquipmentAbilityService:_handleCollision(attacker: Player, victim: Player, collisionMeta: any)
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then return end
	if stateService:IsHuman(attacker) or stateService:IsHuman(victim) or stateService:HasFlag(attacker, "Ghost") or stateService:HasFlag(victim, "Ghost") then
		return
	end

	local teamService = getService(self._context, "TeamService")
	if teamService and teamService:IsFriendly(attacker, victim) then return end

	self:_syncPlayerAbilities(attacker)
	self:_revealIfStealth(attacker)
	local abilities = self._abilities[attacker]
	if not abilities then return end
	for _, ability in pairs(abilities) do
		ability:OnCollision({ TargetPlayer = victim, CollisionMeta = collisionMeta })
	end
end

return EquipmentAbilityService