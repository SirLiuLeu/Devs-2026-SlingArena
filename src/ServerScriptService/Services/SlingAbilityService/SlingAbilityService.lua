-- --!strict

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

-- local Stealth = require(script.Abilities.Stealth)
-- local Vacuum = require(script.Abilities.Vacuum)
-- local Stun = require(script.Abilities.Stun)

-- local SlingAbilityService = {}
-- SlingAbilityService.__index = SlingAbilityService

-- local ABILITY_BY_SLING = {
-- 	Stealth = Stealth,
-- 	Vacuum = Vacuum,
-- 	Stun = Stun,
-- }

-- local function resolveAbilityForType(slingType: string)
-- 	local lowered = string.lower(slingType)
-- 	if string.find(lowered, "stealth", 1, true) then
-- 		return ABILITY_BY_SLING.Stealth
-- 	end
-- 	if string.find(lowered, "vacuum", 1, true) then
-- 		return ABILITY_BY_SLING.Vacuum
-- 	end
-- 	if string.find(lowered, "stun", 1, true) then
-- 		return ABILITY_BY_SLING.Stun
-- 	end
-- 	return nil
-- end

-- function SlingAbilityService.new(context)
-- 	local self = setmetatable({}, SlingAbilityService)
-- 	self._context = context
-- 	self._abilityTriggerRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent?
-- 	return self
-- end

-- function SlingAbilityService:Init()
-- 	if self._abilityTriggerRemote then
-- 		self._abilityTriggerRemote.OnServerEvent:Connect(function(player: Player, payload)
-- 			self:_onAbilityTrigger(player, payload)
-- 		end)
-- 	end

-- 	self._context.EventBus:On("SlingLaunched", function(player: Player, chargeRatio: number, launchVector: Vector3)
-- 		local root = self._context.Services.PlayerService:GetRoot(player)
-- 		self:_dispatch(player, "OnLaunch", {
-- 			ChargeRatio = chargeRatio,
-- 			LaunchVector = launchVector,
-- 			RootPosition = root and root.Position or nil,
-- 		})
-- 	end)

-- 	self._context.EventBus:On("CollisionPlayerHit", function(victim: Player, attacker: Player?, _rawDamage: number, _knockback: Vector3, collisionMeta: any)
-- 		if attacker then
-- 			self:_dispatch(attacker, "OnCollision", {
-- 				TargetPlayer = victim,
-- 				CollisionMeta = collisionMeta,
-- 			})
-- 		end
-- 	end)
-- end

-- function SlingAbilityService:_onAbilityTrigger(player: Player, payload)
-- 	if not RemoteContracts.Validate(RemoteContracts.Names.AbilityTrigger, payload) then
-- 		return
-- 	end
-- 	self:_dispatch(player, "Passive", payload)
-- end

-- function SlingAbilityService:_dispatch(player: Player, phase: string, contextData)
-- 	local playerState = self._context.Services.PlayerStateService:GetState(player)
-- 	if not playerState then
-- 		return
-- 	end
-- 	local ability = resolveAbilityForType(playerState.SlingshotType or "")
-- 	if not ability then
-- 		return
-- 	end
-- 	local fn = ability[phase]
-- 	if typeof(fn) ~= "function" then
-- 		return
-- 	end
-- 	local effect = fn(player, contextData)
-- 	self:_applyEffect(player, effect)
-- end

-- function SlingAbilityService:_applyEffect(player: Player, effect)
-- 	if type(effect) ~= "table" then
-- 		return
-- 	end

-- 	if effect.SetVisibility ~= nil then
-- 		local visible = effect.SetVisibility == true
-- 		self._context.Services.PlayerStateService:SetVisibility(player, visible)
-- 		local duration = tonumber(effect.VisibilityDuration)
-- 		if duration and duration > 0 then
-- 			task.delay(duration, function()
-- 				self._context.Services.PlayerStateService:SetVisibility(player, true)
-- 			end)
-- 		end
-- 	end

-- 	if effect.ApplyStunTo then
-- 		self._context.Services.PlayerStateService:ApplyStun(effect.ApplyStunTo, tonumber(effect.Duration) or 0)
-- 	end

-- 	if effect.Event then
-- 		self._context.EventBus:Fire(effect.Event, player, effect.Payload)
-- 	end
-- end

-- return SlingAbilityService
