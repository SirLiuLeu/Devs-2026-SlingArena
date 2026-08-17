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
				self:DeactivateEquipment(player, instanceId)
			end
		end
		self._activeEffects[player] = nil
	end))
	if bus then
		table.insert(self._connections, bus:On("EquipmentEquipped", function(player, slotType, instanceId, ownedInstance)
			self:ActivateEquipment(player, slotType, instanceId, ownedInstance)
		end))
		table.insert(self._connections, bus:On("EquipmentUnequipped", function(player, _slotType, instanceId)
			self:DeactivateEquipment(player, instanceId)
		end))
		table.insert(self._connections, bus:On("EquipmentUpdated", function(player, instanceId, ownedInstance)
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
			self:Dispatch(player, "OnLaunch", payload)
		end))
		table.insert(self._connections, bus:On("CollisionDetected", function(collisionType, attacker, defender, payload)
			self:Dispatch(attacker, "OnCollision", collisionType, defender, payload)
		end))
		table.insert(self._connections, bus:On("CollisionPlayerHit", function(victim, attacker, _rawDamage, _knockback, collisionMeta)
			if attacker then self:Dispatch(attacker, "OnCollision", "Player", victim, collisionMeta) end
		end))
		table.insert(self._connections, bus:On("PlayerAttack", function(player, payload)
			self:Dispatch(player, "OnAttack", payload)
		end))
	end
	self:_ensureHeartbeat()
end

function EquipmentEffectService:RegisterEffect(effectId: string, effectModule: any)
	self._effectModules[effectId] = effectModule
end

function EquipmentEffectService:_ensureHeartbeat()
	if self._heartbeatConnection then return end
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
	local definition = ownedInstance and EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
	if not definition or not definition.effectId then return false end
	local module = self._effectModules[definition.effectId]
	if not module then
		warn(string.format("[EQUIPMENT_EFFECT] Missing effect module for configured effectId %s on %s", tostring(definition.effectId), tostring(definition.id)))
		return false
	end
	self._activeEffects[player] = self._activeEffects[player] or {}
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
	if typeof(module.OnInit) == "function" then module.OnInit(context) end
	return true
end

function EquipmentEffectService:DeactivateEquipment(player, instanceId: string): boolean
	local playerEffects = self._activeEffects[player]
	local effectState = playerEffects and playerEffects[instanceId]
	if not effectState then return false end
	if typeof(effectState.module.OnDestroy) == "function" then effectState.module.OnDestroy(effectState.context) end
	playerEffects[instanceId] = nil
	return true
end

function EquipmentEffectService:Dispatch(player, lifecycleName: string, ...)
	local playerEffects = self._activeEffects[player]
	if not playerEffects then return end
	for _, effectState in pairs(playerEffects) do
		local handler = effectState.module[lifecycleName]
		if typeof(handler) == "function" then handler(effectState.context, ...) end
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
