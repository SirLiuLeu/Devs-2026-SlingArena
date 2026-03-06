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
	local speed = math.max(0, velocityMagnitude)
	local size = math.max(attackerState.Size or 1, 0)
	local slingMod = SlingshotConfig.SlingshotModifiers[attackerState.SlingshotType] or 1
	local damageMultiplier = math.max(attackerState.DamageMultiplier or 1, 0)
	local charge = math.clamp(chargeRatio or attackerState.ChargeValue or 0, 0, 1)
	local chargeMult = 1 + (charge * BalanceConfig.ChargeDamageFactor)

	local baseDamage = speed * math.log(size + 1) * slingMod * damageMultiplier * chargeMult
	return math.clamp(baseDamage, 0, BalanceConfig.MaxDamagePerHit)
end

function CombatService:ComputeKnockback(attackerState, defenderState, direction: Vector3, velocityMagnitude: number): Vector3
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(1, 0, 0)
	end
	local attackerSize = math.max(attackerState.Size or 1, 0.1)
	local defenderSize = math.max(defenderState.Size or 1, 0.1)
	local sizeRatio = attackerSize / defenderSize
	local baseForce = math.max(BalanceConfig.BaseImpactForce, velocityMagnitude * BalanceConfig.KnockbackFactor)
	local knockbackForce = math.clamp(baseForce * sizeRatio, 0, BalanceConfig.MaxKnockback)
	if sizeRatio < 1 then
		return -direction.Unit * knockbackForce
	end
	return direction.Unit * knockbackForce
end

return CombatService
