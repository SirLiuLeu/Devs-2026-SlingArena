--!strict

-- Existing milestones and values through level 20 are retained. Level 20 is
-- 80% of the extended Level1->Level50 range; levels 21-50 supply the last 20%.
local PetAbilityProgressionConfig = {}

PetAbilityProgressionConfig.MaxLevel = 50
PetAbilityProgressionConfig.TitanVisualGrowthPerPlayerLevel = 0.04
PetAbilityProgressionConfig.TitanVisualMultiplierCap = 2
PetAbilityProgressionConfig.Milestones = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }

PetAbilityProgressionConfig.Abilities = {
	ExpBonus = {
		[1] = { expBonus = 0.30 }, [5] = { expBonus = 0.35 }, [10] = { expBonus = 0.40 },
		[15] = { expBonus = 0.45 }, [20] = { expBonus = 0.50 },
		Level50 = { expBonus = 0.55 },
	},
	Titan = {
		[1] = { weightMultiplier = 1.00, hitboxMultiplier = 1.00, incomingKnockbackMultiplier = 0.90, outgoingKnockbackMultiplier = 1.10 },
		[5] = { weightMultiplier = 1.06, hitboxMultiplier = 1.08, incomingKnockbackMultiplier = 0.86, outgoingKnockbackMultiplier = 1.14 },
		[10] = { weightMultiplier = 1.135, hitboxMultiplier = 1.18, incomingKnockbackMultiplier = 0.81, outgoingKnockbackMultiplier = 1.19 },
		[15] = { weightMultiplier = 1.21, hitboxMultiplier = 1.28, incomingKnockbackMultiplier = 0.76, outgoingKnockbackMultiplier = 1.24 },
		[20] = { weightMultiplier = 1.29, hitboxMultiplier = 1.38, incomingKnockbackMultiplier = 0.71, outgoingKnockbackMultiplier = 1.29 },
		Level50 = { weightMultiplier = 1.3625, hitboxMultiplier = 1.475, incomingKnockbackMultiplier = 0.6625, outgoingKnockbackMultiplier = 1.3375 },
	},
	LauncherBoost = {
		[1] = { launcherStatMultiplier = 1.10 }, [5] = { launcherStatMultiplier = 1.10 },
		[10] = { launcherStatMultiplier = 1.10 }, [15] = { launcherStatMultiplier = 1.10 },
		[20] = { launcherStatMultiplier = 1.10 }, Level50 = { launcherStatMultiplier = 1.10 },
	},
	PetBaseBoost = {
		[1] = { petBaseStatsMultiplier = 2.0 }, [5] = { petBaseStatsMultiplier = 2.0 },
		[10] = { petBaseStatsMultiplier = 2.0 }, [15] = { petBaseStatsMultiplier = 2.0 },
		[20] = { petBaseStatsMultiplier = 2.0 }, Level50 = { petBaseStatsMultiplier = 2.0 },
	},
	LastStand = {
		[1] = { lastStandMaxDamageBonus = 0.20 }, [5] = { lastStandMaxDamageBonus = 0.22 },
		[10] = { lastStandMaxDamageBonus = 0.24 }, [15] = { lastStandMaxDamageBonus = 0.27 },
		[20] = { lastStandMaxDamageBonus = 0.30 }, Level50 = { lastStandMaxDamageBonus = 0.40 },
	},
	FullForce = {
		[1] = { fullForceDamageBonus = 0.10 }, [5] = { fullForceDamageBonus = 0.11 },
		[10] = { fullForceDamageBonus = 0.12 }, [15] = { fullForceDamageBonus = 0.13 },
		[20] = { fullForceDamageBonus = 0.15 }, Level50 = { fullForceDamageBonus = 0.25 },
	},
	Lifesteal = {
		[1] = { playerLifestealPercent = 0.02, foodLifestealPercent = 0.01 },
		[5] = { playerLifestealPercent = 0.02, foodLifestealPercent = 0.01 },
		[10] = { playerLifestealPercent = 0.02, foodLifestealPercent = 0.01 },
		[15] = { playerLifestealPercent = 0.02, foodLifestealPercent = 0.01 },
		[20] = { playerLifestealPercent = 0.02, foodLifestealPercent = 0.01 },
		Level50 = { playerLifestealPercent = 0.02, foodLifestealPercent = 0.01 },
	},
	MaxHPBoost = {
		[1] = { maxHPMultiplier = 1.10 }, [5] = { maxHPMultiplier = 1.11 },
		[10] = { maxHPMultiplier = 1.12 }, [15] = { maxHPMultiplier = 1.13 },
		[20] = { maxHPMultiplier = 1.15 }, Level50 = { maxHPMultiplier = 1.25 },
	},
	DamageBoost = {
		[1] = { baseDamageMultiplier = 1.10 }, [5] = { baseDamageMultiplier = 1.11 },
		[10] = { baseDamageMultiplier = 1.12 }, [15] = { baseDamageMultiplier = 1.13 },
		[20] = { baseDamageMultiplier = 1.15 }, Level50 = { baseDamageMultiplier = 1.20 },
	},
	MoveSpeedBoost = {
		[1] = { moveSpeedMultiplier = 1.05 }, [5] = { moveSpeedMultiplier = 1.06 },
		[10] = { moveSpeedMultiplier = 1.07 }, [15] = { moveSpeedMultiplier = 1.08 },
		[20] = { moveSpeedMultiplier = 1.10 }, Level50 = { moveSpeedMultiplier = 1.15 },
	},
	AbsorbShield = {
		[1] = { absorbCapacity = 5000, refreshInterval = 10 },
		[5] = { absorbCapacity = 5000, refreshInterval = 10 },
		[10] = { absorbCapacity = 5000, refreshInterval = 10 },
		[15] = { absorbCapacity = 5000, refreshInterval = 10 },
		[20] = { absorbCapacity = 5000, refreshInterval = 10 },
		Level50 = { absorbCapacity = 5000, refreshInterval = 10 },
	},
	-- Fish: its own fixed regeneration is 10 HP/s. HealingReceivedMultiplier
	-- affects external healing only; Regeneration.lua bypasses this multiplier.
	Regeneration = {
		[1] = { healAmount = 10, tickInterval = 1, healingReceivedMultiplier = 1.10 },
		[5] = { healAmount = 10, tickInterval = 1, healingReceivedMultiplier = 1.11 },
		[10] = { healAmount = 10, tickInterval = 1, healingReceivedMultiplier = 1.13 },
		[15] = { healAmount = 10, tickInterval = 1, healingReceivedMultiplier = 1.15 },
		[20] = { healAmount = 10, tickInterval = 1, healingReceivedMultiplier = 1.18 },
		Level50 = { healAmount = 10, tickInterval = 1, healingReceivedMultiplier = 1.25 },
	},
	-- Separate projectile progression ID; this is not a Pet catalog type.
	Burn = {
		[1] = { damagePerTick = 250 }, [5] = { damagePerTick = 265 },
		[10] = { damagePerTick = 285 }, [15] = { damagePerTick = 305 },
		[20] = { damagePerTick = 325 }, Level50 = { damagePerTick = 375 },
	},
	Poison = {
		[1] = { damagePerTick = 150 }, [5] = { damagePerTick = 160 },
		[10] = { damagePerTick = 175 }, [15] = { damagePerTick = 185 },
		[20] = { damagePerTick = 195 }, Level50 = { damagePerTick = 225 },
	},
	LaunchBooster = {
		[1] = { launchSpeedMultiplier = 1.20 }, [5] = { launchSpeedMultiplier = 1.205 },
		[10] = { launchSpeedMultiplier = 1.215 }, [15] = { launchSpeedMultiplier = 1.225 },
		[20] = { launchSpeedMultiplier = 1.24 }, Level50 = { launchSpeedMultiplier = 1.26 },
	},
	QuickReload = {
		[1] = { launchCooldownReduction = 1.0 }, [5] = { launchCooldownReduction = 1.05 },
		[10] = { launchCooldownReduction = 1.10 }, [15] = { launchCooldownReduction = 1.15 },
		[20] = { launchCooldownReduction = 1.20 }, Level50 = { launchCooldownReduction = 1.30 },
	},
	ThornArmor = {
		[1] = { reflectDamageBonus = 0.20 }, [5] = { reflectDamageBonus = 0.205 },
		[10] = { reflectDamageBonus = 0.215 }, [15] = { reflectDamageBonus = 0.225 },
		[20] = { reflectDamageBonus = 0.24 }, Level50 = { reflectDamageBonus = 0.25 },
	},
	IdleStealth = {
		[1] = { idleSeconds = 3.0 }, [5] = { idleSeconds = 2.9 },
		[10] = { idleSeconds = 2.8 }, [15] = { idleSeconds = 2.65 },
		[20] = { idleSeconds = 2.5 }, Level50 = { idleSeconds = 2.25 },
	},
}

function PetAbilityProgressionConfig.GetParams(abilityId: string?, level: number): { [string]: any }
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, PetAbilityProgressionConfig.MaxLevel)
	local ability = abilityId and PetAbilityProgressionConfig.Abilities[abilityId]
	if not ability then return {} end

	local selectedMilestone = 1
	for _, milestone in ipairs(PetAbilityProgressionConfig.Milestones) do
		if safeLevel >= milestone then selectedMilestone = milestone else break end
	end

	local baseMilestone = if selectedMilestone <= 20 then selectedMilestone else 20
	local baseParams = ability[baseMilestone] or ability[1] or {}
	local result = {}
	for key, value in pairs(baseParams) do result[key] = value end

	if selectedMilestone > 20 then
		local alpha = math.clamp((selectedMilestone - 20) / 30, 0, 1)
		local level50Params = ability.Level50 or {}
		for key, level20Value in pairs(baseParams) do
			local targetValue = level50Params[key]
			if type(level20Value) == "number" and type(targetValue) == "number" then
				result[key] = level20Value + ((targetValue - level20Value) * alpha)
			end
		end
	end
	return result
end

return PetAbilityProgressionConfig
