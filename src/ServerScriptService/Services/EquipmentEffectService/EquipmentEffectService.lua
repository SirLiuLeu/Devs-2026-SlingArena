--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)

local EquipmentEffectService = {}
EquipmentEffectService.__index = EquipmentEffectService

-- Intentionally always on while investigating collision equipment. Keep this prefix when
-- collecting a server log so the complete equipment lifecycle can be filtered easily.
local TRACE_EQUIPMENT_IDS = { Medusa = true, GhostFlame = true, ThunderHammer = true }

local function traceEquipment(definition: any, message: string)
	if definition and TRACE_EQUIPMENT_IDS[definition.id] then
		print(string.format("[EQUIPMENT_ATTACK_TRACE][%s] %s", definition.id, message))
	end
end

function EquipmentEffectService:_traceExpectedEquipment(player: Player?, checkpoint: string)
	local activeEffects = player and self._activeEffects[player]
	local equipped = { Medusa = false, GhostFlame = false, ThunderHammer = false }
	local activeIds = {}
	if activeEffects then
		for instanceId, effectState in pairs(activeEffects) do
			local definitionId = effectState.context.definition and effectState.context.definition.id
			if definitionId then
				if definitionId == "Medusa" then equipped.Medusa = true end
				if definitionId == "GhostFlame" then equipped.GhostFlame = true end
				if definitionId == "ThunderHammer" then equipped.ThunderHammer = true end
				table.insert(activeIds, string.format("%s(%s)", definitionId, tostring(instanceId)))
			end
		end
	end
	table.sort(activeIds)
	print(string.format("[EQUIPMENT_ATTACK_TRACE] equipment validation checkpoint=%s player=%s Medusa=%s GhostFlame=%s ThunderHammer=%s active=[%s]", checkpoint, player and player.Name or "nil", tostring(equipped.Medusa), tostring(equipped.GhostFlame), tostring(equipped.ThunderHammer), table.concat(activeIds, ", ")))
end

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
	self._abilityTriggerRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent?
	return self
end

function EquipmentEffectService:Init()
	-- [DEBUG_TRACE] print("[ROUND_END_TRACE][EquipmentEffectService] Init START; registering effect modules")
	local equipmentEffects = script.Parent.EquipmentEffects
	self:RegisterEffect("NoOp", require(equipmentEffects.NoOp))
	self:RegisterEffect("Poison", require(equipmentEffects.Poison))
	self:RegisterEffect("Fire", require(equipmentEffects.Fire))
	self:RegisterEffect("Slow", require(equipmentEffects.Slow))
	self:RegisterEffect("Stun", require(equipmentEffects.Stun))
	self:RegisterEffect("Petrify", require(equipmentEffects.Petrify))
	self:RegisterEffect("ExpBonus", require(equipmentEffects.ExpBonus))
	self:RegisterEffect("Magnet", require(equipmentEffects.Magnet))
	self:RegisterEffect("Shield", require(equipmentEffects.Shield))
	self:RegisterEffect("Titan", require(equipmentEffects.Titan))
	self:RegisterEffect("SmokeBomb", require(equipmentEffects.SmokeBomb))
	self:RegisterEffect("Freeze", require(equipmentEffects.Slow))
	self:RegisterEffect("Regen", require(equipmentEffects.Regen))
	self:RegisterEffect("ShadowCloak", require(equipmentEffects.ShadowCloak))
	if self._abilityTriggerRemote then
		table.insert(self._connections, self._abilityTriggerRemote.OnServerEvent:Connect(function(player: Player, payload)
			self:_onAbilityTrigger(player, payload)
		end))
	end
	local bus = self._context.EventBus
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		local effects = self._activeEffects[player]
		if effects then
			for instanceId in pairs(effects) do
				if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus EquipmentUnequipped; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId))) end
				self:DeactivateEquipment(player, instanceId)
			end
		end
		self._activeEffects[player] = nil
	end))
	if bus then
		if DebugConfig.VerboseTrace then print("[ROUND_END_TRACE][EquipmentEffectService] EventBus found; binding equipment/effect lifecycle handlers") end
		table.insert(self._connections, bus:On("EquipmentEquipped", function(player, slotType, instanceId, ownedInstance)
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus EquipmentEquipped; player=%s slot=%s instanceId=%s", player and player.Name or "nil", tostring(slotType), tostring(instanceId))) end
			local stateService = getService(self._context, "PlayerStateService")
			if stateService and stateService:IsLauncher(player) then
				self:ActivateEquipment(player, slotType, instanceId, ownedInstance)
			end
		end))
		table.insert(self._connections, bus:On("EquipmentUnequipped", function(player, _slotType, instanceId)
			self:DeactivateEquipment(player, instanceId)
		end))
		table.insert(self._connections, bus:On("EquipmentUpdated", function(player, instanceId, ownedInstance)
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus EquipmentUpdated; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId))) end
			local stateService = getService(self._context, "PlayerStateService")
			if not (stateService and stateService:IsLauncher(player)) then return end
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
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus LauncherLaunched -> Dispatch OnLaunch; player=%s", player and player.Name or "nil")) end
			self:Dispatch(player, "OnLaunch", payload)
		end))
		table.insert(self._connections, bus:On("CollisionDetected", function(collisionType, attacker, defender, payload)
			if collisionType == "Food" then
				if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus CollisionDetected -> Dispatch Food OnCollision; attacker=%s", attacker and attacker.Name or "nil")) end
				self:Dispatch(attacker, "OnCollision", collisionType, defender, payload)
			end
		end))
		table.insert(self._connections, bus:On("CollisionPlayerHit", function(victim, attacker, _rawDamage, _knockback, collisionMeta)
			if attacker then
				self:_traceExpectedEquipment(attacker, "CollisionPlayerHit")
				print(string.format("[EQUIPMENT_ATTACK_TRACE] CollisionPlayerHit fired attacker=%s victim=%s impactSpeed=%s transferredVelocity=%s", attacker.Name, victim and victim.Name or "nil", tostring(collisionMeta and collisionMeta.ImpactSpeed), tostring(collisionMeta and collisionMeta.TransferredVelocity)))
				if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus CollisionPlayerHit -> Dispatch OnCollision; attacker=%s victim=%s", attacker.Name, victim and victim.Name or "nil")) end
				self:Dispatch(attacker, "OnCollision", "Player", victim, collisionMeta)
			end
		end))
		table.insert(self._connections, bus:On("PlayerAttack", function(player, payload)
			self:_traceExpectedEquipment(player, "PlayerAttack")
			print(string.format("[EQUIPMENT_ATTACK_TRACE] PlayerAttack hook fired player=%s payload=%s", player and player.Name or "nil", tostring(payload)))
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] EventBus PlayerAttack -> Dispatch OnAttack; player=%s", player and player.Name or "nil")) end
			self:Dispatch(player, "OnAttack", payload)
		end))
	end
	self:_ensureHeartbeat()
	-- [DEBUG_TRACE] print("[ROUND_END_TRACE][EquipmentEffectService] Init END; heartbeat ensured")
end

function EquipmentEffectService:_onAbilityTrigger(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.abilityId) ~= "string" then return end
	local playerEffects = self._activeEffects[player]
	if not playerEffects then return end
	for _, effectState in pairs(playerEffects) do
		local definition = effectState.context.definition
		if definition and definition.abilityId == payload.abilityId then
			local handler = effectState.module.OnAbilityTrigger or effectState.module.OnAttack
			if typeof(handler) == "function" then
				handler(effectState.context, payload)
			else
				warn(string.format("[EQUIPMENT_EFFECT] Ability trigger for %s is not implemented.", tostring(definition.id)))
			end
		end
	end
end

function EquipmentEffectService:RegisterEffect(effectId: string, effectModule: any)
	self._effectModules[effectId] = effectModule
end

function EquipmentEffectService:_ensureHeartbeat()
	if self._heartbeatConnection then
		-- [DEBUG_TRACE] print("[ROUND_END_TRACE][EquipmentEffectService] _ensureHeartbeat skipped; already connected")
		return
	end
	-- [DEBUG_TRACE] print("[ROUND_END_TRACE][EquipmentEffectService] _ensureHeartbeat creating Heartbeat connection")
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

function EquipmentEffectService:ActivateEquippedEquipment(player): ()
	local dataService = getService(self._context, "PlayerDataService")
	if not dataService then return end
	local owned = dataService:GetOwnedEquipment(player)
	local equipped = dataService:GetEquippedEquipment(player)
	for slotType, instanceId in pairs(equipped) do
		local ownedInstance = instanceId and owned[instanceId]
		if type(ownedInstance) == "table" then
			self:ActivateEquipment(player, slotType, instanceId, ownedInstance)
		end
	end
end

function EquipmentEffectService:DeactivateAllEquipment(player): ()
	local effects = self._activeEffects[player]
	if not effects then return end
	local instanceIds = {}
	for instanceId in pairs(effects) do
		table.insert(instanceIds, instanceId)
	end
	for _, instanceId in ipairs(instanceIds) do
		self:DeactivateEquipment(player, instanceId)
	end
end

function EquipmentEffectService:ActivateEquipment(player, _slotType: string, instanceId: string, ownedInstance: any): boolean
	print(string.format("[EQUIPMENT_EFFECT][SUCCESS] ActivateEquipment player=%s instanceId=%s definitionId=%s", player and player.Name or "nil", tostring(instanceId), tostring(ownedInstance and ownedInstance.definitionId)))
	local definition = ownedInstance and EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
	if not definition or not definition.effectId then
		print(string.format("[EQUIPMENT_ATTACK_TRACE] activation aborted player=%s instanceId=%s definitionFound=%s effectId=%s", player and player.Name or "nil", tostring(instanceId), tostring(definition ~= nil), tostring(definition and definition.effectId)))
		return false
	end
	local module = self._effectModules[definition.effectId]
	if not module then
		warn(string.format("[EQUIPMENT_EFFECT] Missing effect module for configured effectId %s on %s", tostring(definition.effectId), tostring(definition.id)))
		return false
	end
	self._activeEffects[player] = self._activeEffects[player] or {}
	self:DeactivateEquipment(player, instanceId)
	local context = {
		player = player,
		slot = tonumber(_slotType),
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
		module.OnInit(context)
	end
	return true
end

function EquipmentEffectService:DeactivateEquipment(player, instanceId: string): boolean
	if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] DeactivateEquipment player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId))) end
	local playerEffects = self._activeEffects[player]
	local effectState = playerEffects and playerEffects[instanceId]
	if not effectState then return false end
	if typeof(effectState.module.OnDestroy) == "function" then
		effectState.module.OnDestroy(effectState.context)
	end
	playerEffects[instanceId] = nil
	return true
end

function EquipmentEffectService:Dispatch(player, lifecycleName: string, ...)
	local shouldTraceDispatch = lifecycleName ~= "OnTick"
	if shouldTraceDispatch and DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][EquipmentEffectService] Dispatch player=%s lifecycle=%s", player and player.Name or "nil", tostring(lifecycleName))) end
	local playerEffects = self._activeEffects[player]
	if not playerEffects then
		print(string.format("[EQUIPMENT_ATTACK_TRACE] Dispatch aborted player=%s lifecycle=%s reason=no_active_effects", player and player.Name or "nil", tostring(lifecycleName)))
		return
	end
	for instanceId, effectState in pairs(playerEffects) do
		local handler = effectState.module[lifecycleName]
		traceEquipment(effectState.context.definition, string.format("lifecycle=%s player=%s instanceId=%s handler=%s", lifecycleName, player and player.Name or "nil", tostring(instanceId), tostring(typeof(handler) == "function")))
		if typeof(handler) == "function" then
			handler(effectState.context, ...)
		elseif TRACE_EQUIPMENT_IDS[effectState.context.definition.id] then
			print(string.format("[EQUIPMENT_ATTACK_TRACE][%s] lifecycle skipped: no %s handler", effectState.context.definition.id, lifecycleName))
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
