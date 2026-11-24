--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetProgression = require(ReplicatedStorage.Shared.Utils.PetProgression)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local ServiceResolver = require(script.Parent.Parent.Infrastructure.ServiceResolver)

local PetAbilityService = {}
PetAbilityService.__index = PetAbilityService

-- Intentionally always on while investigating collision pet. Keep this prefix when
-- collecting a server log so the complete pet lifecycle can be filtered easily.
local TRACE_ABILITY_IDS = { Poison = true, Burn = true }

local function tracePet(definition: any, message: string)
	local abilityId = definition and definition.abilityId
	if abilityId and TRACE_ABILITY_IDS[abilityId] then
		print(string.format("[PET_ATTACK_TRACE][%s] %s", abilityId, message))
	end
end

function PetAbilityService:_traceExpectedPet(player: Player?, checkpoint: string)
	local activeEffects = player and self._activeEffects[player]
	local equipped = { Poison = false, Burn = false }
	local activeIds = {}
	if activeEffects then
		for instanceId, effectState in pairs(activeEffects) do
			local abilityId = effectState.context.definition and effectState.context.definition.abilityId
			if abilityId then
				if abilityId == "Poison" then equipped.Poison = true end
				if abilityId == "Burn" then equipped.Burn = true end
				table.insert(activeIds, string.format("%s(%s)", abilityId, tostring(instanceId)))
			end
		end
	end
	table.sort(activeIds)
	print(string.format("[PET_ATTACK_TRACE] ability validation checkpoint=%s player=%s Poison=%s Burn=%s active=[%s]", checkpoint, player and player.Name or "nil", tostring(equipped.Poison), tostring(equipped.Burn), table.concat(activeIds, ", ")))
end


function PetAbilityService.new(context)
	local self = setmetatable({}, PetAbilityService)
	self._context = context
	self._activeEffects = {}
	self._effectModules = {}
	self._connections = {}
	self._heartbeatConnection = nil
	self._heartbeatConnectCount = 0
	return self
end

function PetAbilityService:Init()
	-- [DEBUG_TRACE] print("[ROUND_END_TRACE][PetAbilityService] Init START; registering effect modules")
	local petEffects = script.Parent.PetAbilities
	-- Only abilities with lifecycle-driven behavior need effect modules. Pure
	-- stat/conditional abilities are resolved by PetStatResolver/DamagePipelineService.
	self:RegisterEffect("Titan", require(petEffects.Titan))
	self:RegisterEffect("Poison", require(petEffects.Poison))
	self:RegisterEffect("Burn", require(petEffects.Burn))
	self:RegisterEffect("Regeneration", require(petEffects.Regeneration))
	local bus = self._context.EventBus
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		local effects = self._activeEffects[player]
		if effects then
			for instanceId in pairs(effects) do
				if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus PetUnequipped; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId))) end
				self:DeactivatePet(player, instanceId)
			end
		end
		self._activeEffects[player] = nil
	end))
	if bus then
		if DebugConfig.VerboseTrace then print("[ROUND_END_TRACE][PetAbilityService] EventBus found; binding pet/effect lifecycle handlers") end
		table.insert(self._connections, bus:On("LevelUp", function(player: Player, playerLevel: number)
			local effects = self._activeEffects[player]
			if not effects then return end
			for _, effectState in pairs(effects) do
				local definition = effectState.context.definition
				if definition and definition.abilityId == "Titan" and typeof(effectState.module.OnLevelUp) == "function" then
					effectState.module.OnLevelUp(effectState.context, playerLevel)
					break -- A player-level event increments Titan visual growth once, even with multiple copies equipped.
				end
			end
		end))
		table.insert(self._connections, bus:On("RoundProgressionReset", function(player: Player)
			local effects = self._activeEffects[player]
			if not effects then return end
			for _, effectState in pairs(effects) do
				local context = effectState.context
				if context.definition and context.definition.abilityId == "Titan"
					and typeof(effectState.module.OnRoundReset) == "function" then
					effectState.module.OnRoundReset(context)
					break
				end
			end
		end))
		table.insert(self._connections, bus:On("PetEquipped", function(player, slotType, instanceId, ownedInstance)
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus PetEquipped; player=%s slot=%s instanceId=%s", player and player.Name or "nil", tostring(slotType), tostring(instanceId))) end
			local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
			if stateService and stateService:IsLauncher(player) then
				self:ActivatePet(player, slotType, instanceId, ownedInstance)
			end
		end))
		table.insert(self._connections, bus:On("PetUnequipped", function(player, _slotType, instanceId)
			self:DeactivatePet(player, instanceId)
		end))
		table.insert(self._connections, bus:On("PetUpdated", function(player, instanceId, ownedInstance)
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus PetUpdated; player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId))) end
			local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
			if not (stateService and stateService:IsLauncher(player)) then return end
			local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
			local equipped = dataService and dataService:GetEquippedPets(player) or {}
			for slotType, equippedInstanceId in pairs(equipped) do
				if equippedInstanceId == instanceId then
					local oldEffect = self._activeEffects[player] and self._activeEffects[player][instanceId]
					if oldEffect and oldEffect.context.definition and oldEffect.context.definition.abilityId == "Titan" then
						-- Refresh Titan's pet-level stats in place so the player-level visual factor
						-- survives upgrades without clearing/reapplying scale attributes.
						local context = oldEffect.context
						context.ownedInstance = ownedInstance
						context.progression = PetProgression.Resolve(ownedInstance)
						context.preservedTitanVisualGrowth = {
							multiplier = tonumber(context._visualMultiplier) or 1,
							levels = math.max(0, math.floor(tonumber(context._visualGrowthLevels) or 0)),
						}
						if typeof(oldEffect.module.OnInit) == "function" then oldEffect.module.OnInit(context) end
					else
						self:ActivatePet(player, slotType, instanceId, ownedInstance)
					end
					break
				end
			end
		end))
		table.insert(self._connections, bus:On("LauncherLaunched", function(player, payload)
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus LauncherLaunched -> Dispatch OnLaunch; player=%s", player and player.Name or "nil")) end
			self:Dispatch(player, "OnLaunch", payload)
		end))
		table.insert(self._connections, bus:On("CollisionDetected", function(collisionType, attacker, defender, payload)
			if collisionType == "Food" then
				if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus CollisionDetected -> Dispatch Food OnCollision; attacker=%s", attacker and attacker.Name or "nil")) end
				self:Dispatch(attacker, "OnCollision", collisionType, defender, payload)
			end
		end))
		table.insert(self._connections, bus:On("CollisionPlayerHit", function(victim, attacker, _rawDamage, _knockback, collisionMeta)
			if attacker then
				self:_traceExpectedPet(attacker, "CollisionPlayerHit")
				print(string.format("[PET_ATTACK_TRACE] CollisionPlayerHit fired attacker=%s victim=%s impactSpeed=%s transferredVelocity=%s", attacker.Name, victim and victim.Name or "nil", tostring(collisionMeta and collisionMeta.ImpactSpeed), tostring(collisionMeta and collisionMeta.TransferredVelocity)))
				if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus CollisionPlayerHit -> Dispatch OnCollision; attacker=%s victim=%s", attacker.Name, victim and victim.Name or "nil")) end
				self:Dispatch(attacker, "OnCollision", "Player", victim, collisionMeta)
			end
		end))
		table.insert(self._connections, bus:On("PlayerAttack", function(player, payload)
			self:_traceExpectedPet(player, "PlayerAttack")
			print(string.format("[PET_ATTACK_TRACE] PlayerAttack hook fired player=%s payload=%s", player and player.Name or "nil", tostring(payload)))
			if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] EventBus PlayerAttack -> Dispatch OnAttack; player=%s", player and player.Name or "nil")) end
			self:Dispatch(player, "OnAttack", payload)
		end))
	end
	self:_ensureHeartbeat()
	-- [DEBUG_TRACE] print("[ROUND_END_TRACE][PetAbilityService] Init END; heartbeat ensured")
end

function PetAbilityService:RegisterEffect(abilityId: string, effectModule: any)
	self._effectModules[abilityId] = effectModule
end

function PetAbilityService:_ensureHeartbeat()
	if self._heartbeatConnection then
		-- [DEBUG_TRACE] print("[ROUND_END_TRACE][PetAbilityService] _ensureHeartbeat skipped; already connected")
		return
	end
	-- [DEBUG_TRACE] print("[ROUND_END_TRACE][PetAbilityService] _ensureHeartbeat creating Heartbeat connection")
	self._heartbeatConnectCount += 1
	local signal = self._heartbeatSignal or RunService.Heartbeat
	self._heartbeatConnection = signal:Connect(function(dt)
		self:_onHeartbeat(dt)
	end)
end

function PetAbilityService:GetHeartbeatConnectionCount(): number
	return self._heartbeatConnectCount
end

function PetAbilityService:GetActiveEffectCount(player): number
	local effects = self._activeEffects[player]
	local count = 0
	if effects then for _ in pairs(effects) do count += 1 end end
	return count
end

function PetAbilityService:ActivateEquippedPets(player): ()
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return end
	local owned = dataService:GetOwnedPets(player)
	local equipped = dataService:GetEquippedPets(player)
	for slotType, instanceId in pairs(equipped) do
		local ownedInstance = instanceId and owned[instanceId]
		if type(ownedInstance) == "table" then
			self:ActivatePet(player, slotType, instanceId, ownedInstance)
		end
	end
end

function PetAbilityService:DeactivateAllPet(player): ()
	local effects = self._activeEffects[player]
	if not effects then return end
	local instanceIds = {}
	for instanceId in pairs(effects) do
		table.insert(instanceIds, instanceId)
	end
	for _, instanceId in ipairs(instanceIds) do
		self:DeactivatePet(player, instanceId)
	end
end

function PetAbilityService:ActivatePet(player, _slotType: string, instanceId: string, ownedInstance: any): boolean
	local abilityId = tostring(ownedInstance and ownedInstance.abilityId or "")
	local definition = PetsConfig.GetByAbilityId(abilityId)
	if not definition then
		warn(string.format("[PET_EFFECT] Unknown Pet AbilityID %q for player=%s instanceId=%s", abilityId, player and player.Name or "nil", tostring(instanceId)))
		return false
	end
	local module = self._effectModules[abilityId]
	if not module then
		-- Ability is passive/stat-only; its effects are resolved outside this lifecycle service.
		if DebugConfig.VerboseTrace then
			print(string.format("[PET_EFFECT][PASSIVE] abilityId=%s player=%s instanceId=%s", abilityId, player and player.Name or "nil", tostring(instanceId)))
		end
		return true
	end
	print(string.format("[PET_EFFECT][SUCCESS] ActivatePet player=%s instanceId=%s abilityId=%s", player and player.Name or "nil", tostring(instanceId), abilityId))
	self._activeEffects[player] = self._activeEffects[player] or {}
	self:DeactivatePet(player, instanceId)
	local context = {
		player = player,
		slot = tonumber(_slotType),
		instanceId = instanceId,
		definition = definition,
		ownedInstance = ownedInstance,
		progression = PetProgression.Resolve(ownedInstance),
		FlagService = ServiceResolver.Get(self._context, "FlagService"),
		PlayerStateService = ServiceResolver.Get(self._context, "PlayerStateService"),
		PlayerDataService = ServiceResolver.Get(self._context, "PlayerDataService"),
		TeamService = ServiceResolver.Get(self._context, "TeamService"),
		Remotes = self._context.Remotes,
		FoodService = ServiceResolver.Get(self._context, "FoodService"),
		PlayerService = ServiceResolver.Get(self._context, "PlayerService"),
		DamagePipelineService = ServiceResolver.Get(self._context, "DamagePipelineService"),
	}
	local effectState = { module = module, context = context }
	self._activeEffects[player][instanceId] = effectState
	if typeof(module.OnInit) == "function" then
		module.OnInit(context)
	end
	return true
end

function PetAbilityService:DeactivatePet(player, instanceId: string): boolean
	if DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] DeactivatePet player=%s instanceId=%s", player and player.Name or "nil", tostring(instanceId))) end
	local playerEffects = self._activeEffects[player]
	local effectState = playerEffects and playerEffects[instanceId]
	if not effectState then return false end
	if typeof(effectState.module.OnDestroy) == "function" then
		effectState.module.OnDestroy(effectState.context)
	end
	playerEffects[instanceId] = nil
	return true
end

function PetAbilityService:Dispatch(player, lifecycleName: string, ...)
	local shouldTraceDispatch = lifecycleName ~= "OnTick"
	if shouldTraceDispatch and DebugConfig.VerboseTrace then print(string.format("[ROUND_END_TRACE][PetAbilityService] Dispatch player=%s lifecycle=%s", player and player.Name or "nil", tostring(lifecycleName))) end
	local playerEffects = self._activeEffects[player]
	if not playerEffects then
		print(string.format("[PET_ATTACK_TRACE] Dispatch aborted player=%s lifecycle=%s reason=no_active_effects", player and player.Name or "nil", tostring(lifecycleName)))
		return
	end
	for instanceId, effectState in pairs(playerEffects) do
		local handler = effectState.module[lifecycleName]
		tracePet(effectState.context.definition, string.format("lifecycle=%s player=%s instanceId=%s handler=%s", lifecycleName, player and player.Name or "nil", tostring(instanceId), tostring(typeof(handler) == "function")))
		if typeof(handler) == "function" then
			handler(effectState.context, ...)
		elseif TRACE_ABILITY_IDS[effectState.context.definition.abilityId] then
			print(string.format("[PET_ATTACK_TRACE][%s] lifecycle skipped: no %s handler", effectState.context.definition.abilityId, lifecycleName))
		end
	end
end

function PetAbilityService:_onHeartbeat(dt: number)
	for player in pairs(self._activeEffects) do
		self:Dispatch(player, "OnTick", dt)
	end
end

function PetAbilityService:Destroy()
	if self._heartbeatConnection then self._heartbeatConnection:Disconnect(); self._heartbeatConnection = nil end
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for player, effects in pairs(self._activeEffects) do
		for instanceId in pairs(effects) do self:DeactivatePet(player, instanceId) end
	end
end

return PetAbilityService
