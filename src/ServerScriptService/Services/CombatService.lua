--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)

type Context = {
	EventBus: any,
	Services: any,
}

local CombatService = {}
CombatService.__index = CombatService

function CombatService.new(_context: Context)
	local self = setmetatable({}, CombatService)
	return self
end

function CombatService:Init() end

function CombatService:ComputeImpactDamage(attackerState, velocityMagnitude: number, chargeRatio: number?): number
	local speedMultiplier = math.max(1, velocityMagnitude * BalanceConfig.SpeedDamageFactor)
	local sizeMultiplier = math.max(0.6, attackerState.Size * BalanceConfig.SizeDamageFactor)
	local chargeMultiplier = 1 + (math.clamp(chargeRatio or attackerState.ChargeValue or 0, 0, 1) * BalanceConfig.ChargeDamageFactor)
	local slingMod = SlingshotConfig.SlingshotModifiers[attackerState.SlingshotType] or 1
	local damage = attackerState.BaseDamage * speedMultiplier * sizeMultiplier * chargeMultiplier * slingMod * attackerState.DamageMultiplier
	return math.clamp(damage, 0, BalanceConfig.MaxDamagePerHit)
end

function CombatService:ComputeKnockback(_attackerState, _defenderState, direction: Vector3, velocityMagnitude: number): Vector3
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(1, 0, 0)
	end
	local forceMag = math.clamp(velocityMagnitude * BalanceConfig.KnockbackFactor, 0, BalanceConfig.MaxKnockback)
	return direction.Unit * forceMag
end

return CombatService
