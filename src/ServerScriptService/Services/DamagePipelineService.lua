--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)

type Context = {
	Services: any,
	EventBus: any,
}

local DamagePipelineService = {}
DamagePipelineService.__index = DamagePipelineService

function DamagePipelineService.new(context: Context)
	local self = setmetatable({}, DamagePipelineService)
	self._context = context
	return self
end

function DamagePipelineService:Init()
	self._context.EventBus:On("CollisionPlayerHit", function(victim: Player, attacker: Player?, rawDamage: number, knockbackDirection: Vector3)
		self:ApplyDamage(victim, rawDamage, attacker, knockbackDirection)
	end)
	self._context.EventBus:On("TrapCollision", function(player: Player, penalty: number)
		self:ApplyExpPenalty(player, penalty)
	end)
	task.spawn(function()
		while true do
			self:_runRegenTick()
			task.wait(1)
		end
	end)
end

function DamagePipelineService:_runRegenTick()
	for player, state in pairs(self._context.Services.PlayerStateService:GetAllStates()) do
		if state.IsAlive and state.CurrentHP > 0 then
			local regen = SlingshotConfig.SlingConfig.RegenPerSecond + state.Attributes.Regen
			if regen > 0 then
				self._context.Services.PlayerStateService:Heal(player, regen)
			end
		end
	end
end

function DamagePipelineService:ApplyDamage(victim: Player, rawDamage: number, attacker: Player?, knockbackDirection: Vector3?): boolean
	local playerStateService = self._context.Services.PlayerStateService
	if playerStateService:IsInvulnerable(victim) then
		return false
	end

	local amount = math.clamp(rawDamage, 0, BalanceConfig.MaxDamagePerHit)
	if attacker then
		playerStateService:SetLastAttacker(victim, attacker)
	end
	local didDamage = playerStateService:ApplyDamage(victim, amount)
	if not didDamage then
		return false
	end

	if attacker then
		playerStateService:AddDamageDealt(attacker, amount)
		local victimStats = playerStateService:GetFinalStats(victim)
		if victimStats then
			local reflectPct = math.clamp(victimStats.Reflect, 0, 0.5)
			if reflectPct > 0 then
				local reflected = amount * reflectPct
				playerStateService:ApplyDamage(attacker, reflected)
			end
		end
		self._context.EventBus:Fire("DamageDealt", attacker, victim, amount)
	end

	if knockbackDirection then
		local root = self._context.Services.PlayerService:GetRoot(victim)
		if root and knockbackDirection.Magnitude > 0 then
			root.AssemblyLinearVelocity += knockbackDirection.Unit * 45
		end
	end

	local state = playerStateService:GetState(victim)
	if state and state.CurrentHP <= 0 then
		self:HandlePlayerDeath(victim)
	end
	return true
end

function DamagePipelineService:ApplyExpPenalty(player: Player, amount: number)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	self._context.Services.PlayerStateService:TryApplyExpPenalty(player, amount)
end

function DamagePipelineService:HandlePlayerDeath(player: Player)
	local playerStateService = self._context.Services.PlayerStateService
	local state = playerStateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end
	playerStateService:SetAlive(player, false)
	self._context.EventBus:Fire("PlayerDied", player)

	local killer = playerStateService:GetLastAttacker(player)
	if killer then
		self._context.EventBus:Fire("PlayerKilled", killer, player)
		playerStateService:ClearLastAttacker(player)
	end
end

return DamagePipelineService
