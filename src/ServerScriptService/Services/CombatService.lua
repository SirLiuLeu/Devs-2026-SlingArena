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

function CombatService.new(context: Context)
	local self = setmetatable({}, CombatService)
	return self
end

local function computeLevelDamageBonus(level: number): number
	local perLevel = BalanceConfig.DamageLevelBonusMin + (BalanceConfig.DamageLevelBonusMax - BalanceConfig.DamageLevelBonusMin) * 0.5
	local total = math.max(0, level - 1) * perLevel
	return math.min(total, BalanceConfig.DamageLevelBonusCap)
end

function CombatService:Init() end

function CombatService:ComputeImpactDamage(attackerState, velocityMagnitude: number): number
	local slingMod = SlingshotConfig.SlingshotModifiers[attackerState.SlingshotType] or 1
	local base = velocityMagnitude * math.log(attackerState.Size + 1) * slingMod * attackerState.DamageMultiplier
	local withFlat = base + attackerState.BaseDamage + computeLevelDamageBonus(attackerState.Level)
	return math.clamp(withFlat, 0, BalanceConfig.MaxDamagePerHit)
end

function CombatService:ComputeKnockback(attackerState, defenderState, direction: Vector3): Vector3
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(1, 0, 0)
	end
	local sizeRatio = attackerState.Size / math.max(defenderState.Size, 0.01)
	local dir = direction.Unit
	if sizeRatio < 1 then
		dir = -dir
	end
	local forceMag = math.clamp(BalanceConfig.BaseImpactForce * sizeRatio, 0, BalanceConfig.MaxKnockback)
	local resistance = math.clamp(defenderState.KnockbackResistance, 0, 0.75)
	forceMag *= (1 - resistance)
	return dir * forceMag
end

return CombatService
