--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

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
end

-- Domain ownership: all mutation for HP/EXP/level-down/death flows through this pipeline.
function DamagePipelineService:ApplyDamage(victim: Player, rawDamage: number, _attacker: Player?, knockbackDirection: Vector3?): boolean
	local playerStateService = self._context.Services.PlayerStateService
	if playerStateService:IsInvulnerable(victim) then
		return false
	end

	local amount = math.clamp(rawDamage, 0, BalanceConfig.MaxDamagePerHit)
	local didDamage = playerStateService:ApplyDamage(victim, amount)
	if not didDamage then
		return false
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

	if self._context.Services.MatchService and self._context.Services.MatchService:IsRoundActive() then
		return
	end
	self._context.Services.PlayerService:SpawnPawn(player)
end

return DamagePipelineService
