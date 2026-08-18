--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)

local EquipmentEffectService = {}
EquipmentEffectService.__index = EquipmentEffectService

local function getService(context, name: string)
	if context.ServiceRegistry then return context.ServiceRegistry:GetOptional(name) end
	return context.Services and context.Services[name]
end

function EquipmentEffectService.new(context)
	local self = setmetatable({}, EquipmentEffectService)
	self._context = context
	self._activeEffects = {}
	self._effectModules = {}
	self._connections = {}
	self._heartbeatConnection = nil
	self._heartbeatConnectCount = 0
	return self
end

function EquipmentEffectService:Init()
	print("[ROUND_END_TRACE][EquipmentEffectService] Init START; registering effect modules")
	self:RegisterEffect("NoOp", require(script.EquipmentEffects.NoOp))
	self:RegisterEffect("Poison", require(script.EquipmentEffects.Poison))
	self:RegisterEffect("Fire", require(script.EquipmentEffects.Fire))
	self:RegisterEffect("Slow", require(script.EquipmentEffects.Slow))
	self:RegisterEffect("Stun", require(script.EquipmentEffects.Stun))
	self:RegisterEffect("Petrify", require(script.EquipmentEffects.Petrify))
	self:RegisterEffect("ExpBonus", require(script.EquipmentEffects.ExpBonus))
	self:RegisterEffect("Magnet", require(script.EquipmentEffects.Magnet))
	self:RegisterEffect("Shield", require(script.EquipmentEffects.Shield))
	self:RegisterEffect("Titan", require(script.EquipmentEffects.Titan))
	self:RegisterEffect("SmokeBomb", require(script.EquipmentEffects.SmokeBomb))
	local bus = self._context.EventBus
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		local effects = self._activeEffects[player]
		if effects then
			for instanceId in pairs(effects) do
				print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus EquipmentUnequipped; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId)))
				self:DeactivateEquipment(player, instanceId)
			end
		end
		self._activeEffects[player] = nil
	end))
	if bus then
		print("[ROUND_END_TRACE][EquipmentEffectService] EventBus found; binding equipment/effect lifecycle handlers")
		table.insert(self._connections, bus:On("EquipmentEquipped", function(player, slotType, instanceId, ownedInstance)
			print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus EquipmentEquipped; player=%s slot=%s instanceId=%s", player and player.Name or "nil", tostring(slotType), tostring(instanceId)))
			self:ActivateEquipment(player, slotType, instanceId, ownedInstance)
		end))
		table.insert(self._connections, bus:On("EquipmentUnequipped", function(player, _slotType, instanceId)
			self:DeactivateEquipment(player, instanceId)
		end))
		table.insert(self._connections, bus:On("EquipmentUpdated", function(player, instanceId, ownedInstance)
			print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus EquipmentUpdated; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId)))
			local dataService = getService(self._context, "PlayerDataService")
			local equipped = dataService and dataService:GetEquippedEquipment(player) or {}
			for slotType, equippedInstanceId in pairs(equipped) do
				if equippedInstanceId == instanceId then
					self:ActivateEquipment(player, slotType, instanceId, ownedInstance)
					break
				end
			end
		end))
		table.insert(self._connections, bus:On("LauncherLaunched", function(player, payload)
			print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus LauncherLaunched -> Dispatch OnLaunch; player=%s", player and player.Name or "nil"))
			self:Dispatch(player, "OnLaunch", payload)
		end))
		table.insert(self._connections, bus:On("CollisionDetected", function(collisionType, attacker, defender, payload)
			print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus CollisionDetected -> Dispatch OnCollision; attacker=%s type=%s", attacker and attacker.Name or "nil", tostring(collisionType)))
			self:Dispatch(attacker, "OnCollision", collisionType, defender, payload)
		end))
		table.insert(self._connections, bus:On("CollisionPlayerHit", function(victim, attacker, _rawDamage, _knockback, collisionMeta)
			if attacker then
				print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus CollisionPlayerHit -> Dispatch OnCollision; attacker=%s victim=%s", attacker.Name, victim and victim.Name or "nil"))
				self:Dispatch(attacker, "OnCollision", "Player", victim, collisionMeta)
			end
		end))
		table.insert(self._connections, bus:On("PlayerAttack", function(player, payload)
			print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus PlayerAttack -> Dispatch OnAttack; player=%s", player and player.Name or "nil"))
			self:Dispatch(player, "OnAttack", payload)
		end))
	end
	self:_ensureHeartbeat()
	print("[ROUND_END_TRACE][EquipmentEffectService] Init END; heartbeat ensured")
end

function EquipmentEffectService:RegisterEffect(effectId: string, effectModule: any)
	self._effectModules[effectId] = effectModule
end

function EquipmentEffectService:_ensureHeartbeat()
	if self._heartbeatConnection then
		print("[ROUND_END_TRACE][EquipmentEffectService] _ensureHeartbeat skipped; already connected")
		return
	end
	print("[ROUND_END_TRACE][EquipmentEffectService] _ensureHeartbeat creating Heartbeat connection")
	self._heartbeatConnectCount += 1
	local signal = self._heartbeatSignal or RunService.Heartbeat
	self._heartbeatConnection = signal:Connect(function(dt)
		self:_onHeartbeat(dt)
	end)
end

function EquipmentEffectService:GetHeartbeatConnectionCount(): number
	return self._heartbeatConnectCount
end

function EquipmentEffectService:GetActiveEffectCount(player): number
	local effects = self._activeEffects[player]
	local count = 0
	if effects then for _ in pairs(effects) do count += 1 end end
	return count
end

function EquipmentEffectService:ActivateEquipment(player, _slotType: string, instanceId: string, ownedInstance: any): boolean
	print(string.format("[ROUND_END_TRACE][EquipmentEffectService] ActivateEquipment START; player=%s instanceId=%s definitionId=%s", player and player.Name or "nil", tostring(instanceId), tostring(ownedInstance and ownedInstance.definitionId)))
	local definition = ownedInstance and EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
	if not definition or not definition.effectId then return false end
	local module = self._effectModules[definition.effectId]
	if not module then
		warn(string.format("[EQUIPMENT_EFFECT] Missing effect module for configured effectId %s on %s", tostring(definition.effectId), tostring(definition.id)))
		return false
	end
	self._activeEffects[player] = self._activeEffects[player] or {}
	print("[ROUND_END_TRACE][EquipmentEffectService] ActivateEquipment before replacing/deactivating existing effect")
	self:DeactivateEquipment(player, instanceId)
	local context = {
		player = player,
		instanceId = instanceId,
		definition = definition,
		ownedInstance = ownedInstance,
		FlagService = getService(self._context, "FlagService"),
		PlayerStateService = getService(self._context, "PlayerStateService"),
		PlayerDataService = getService(self._context, "PlayerDataService"),
		TeamService = getService(self._context, "TeamService"),
		Remotes = self._context.Remotes,
		FoodService = getService(self._context, "FoodService"),
		PlayerService = getService(self._context, "PlayerService"),
	}
	local effectState = { module = module, context = context }
	self._activeEffects[player][instanceId] = effectState
	if typeof(module.OnInit) == "function" then
		print(string.format("[ROUND_END_TRACE][EquipmentEffectService] ActivateEquipment before OnInit; effectId=%s", tostring(definition.effectId)))
		module.OnInit(context)
		print(string.format("[ROUND_END_TRACE][EquipmentEffectService] ActivateEquipment after OnInit; effectId=%s", tostring(definition.effectId)))
	end
	print("[ROUND_END_TRACE][EquipmentEffectService] ActivateEquipment END")
	return true
end

function EquipmentEffectService:DeactivateEquipment(player, instanceId: string): boolean
	print(string.format("[ROUND_END_TRACE][EquipmentEffectService] DeactivateEquipment START; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId)))
	local playerEffects = self._activeEffects[player]
	local effectState = playerEffects and playerEffects[instanceId]
	if not effectState then return false end
	if typeof(effectState.module.OnDestroy) == "function" then
		print("[ROUND_END_TRACE][EquipmentEffectService] DeactivateEquipment before OnDestroy")
		effectState.module.OnDestroy(effectState.context)
		print("[ROUND_END_TRACE][EquipmentEffectService] DeactivateEquipment after OnDestroy")
	end
	playerEffects[instanceId] = nil
	return true
end

function EquipmentEffectService:Dispatch(player, lifecycleName: string, ...)
	local shouldTraceDispatch = lifecycleName ~= "OnTick"
	if shouldTraceDispatch then
		print(string.format("[ROUND_END_TRACE][EquipmentEffectService] Dispatch START; player=%s lifecycle=%s", player and player.Name or "nil", tostring(lifecycleName)))
	end
	local playerEffects = self._activeEffects[player]
	if not playerEffects then return end
	for instanceId, effectState in pairs(playerEffects) do
		if shouldTraceDispatch then
			print(string.format("[ROUND_END_TRACE][EquipmentEffectService] Dispatch loop; lifecycle=%s instanceId=%s", tostring(lifecycleName), tostring(instanceId)))
		end
		local handler = effectState.module[lifecycleName]
		if typeof(handler) == "function" then
			if shouldTraceDispatch then
				print(string.format("[ROUND_END_TRACE][EquipmentEffectService] Dispatch before handler; lifecycle=%s instanceId=%s", tostring(lifecycleName), tostring(instanceId)))
			end
			handler(effectState.context, ...)
			if shouldTraceDispatch then
				print(string.format("[ROUND_END_TRACE][EquipmentEffectService] Dispatch after handler; lifecycle=%s instanceId=%s", tostring(lifecycleName), tostring(instanceId)))
			end
		end
	end
end

function EquipmentEffectService:_onHeartbeat(dt: number)
	for player in pairs(self._activeEffects) do
		self:Dispatch(player, "OnTick", dt)
	end
end

function EquipmentEffectService:Destroy()
	if self._heartbeatConnection then self._heartbeatConnection:Disconnect(); self._heartbeatConnection = nil end
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for player, effects in pairs(self._activeEffects) do
		for instanceId in pairs(effects) do self:DeactivateEquipment(player, instanceId) end
	end
end

return EquipmentEffectService
