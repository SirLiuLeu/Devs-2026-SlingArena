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
	Shield = {
		[1] = { damageMultiplier = 0.80 }, [5] = { damageMultiplier = 0.75 }, [10] = { damageMultiplier = 0.70 },
		[15] = { damageMultiplier = 0.65 }, [20] = { damageMultiplier = 0.60 },
		Level50 = { damageMultiplier = 0.55 },
	},
	Titan = {
		[1] = { weightMultiplier = 1.00, hitboxMultiplier = 1.00, incomingKnockbackMultiplier = 0.90, outgoingKnockbackMultiplier = 1.10 },
		[5] = { weightMultiplier = 1.06, hitboxMultiplier = 1.08, incomingKnockbackMultiplier = 0.86, outgoingKnockbackMultiplier = 1.14 },
		[10] = { weightMultiplier = 1.135, hitboxMultiplier = 1.18, incomingKnockbackMultiplier = 0.81, outgoingKnockbackMultiplier = 1.19 },
		[15] = { weightMultiplier = 1.21, hitboxMultiplier = 1.28, incomingKnockbackMultiplier = 0.76, outgoingKnockbackMultiplier = 1.24 },
		[20] = { weightMultiplier = 1.29, hitboxMultiplier = 1.38, incomingKnockbackMultiplier = 0.71, outgoingKnockbackMultiplier = 1.29 },
		Level50 = { weightMultiplier = 1.3625, hitboxMultiplier = 1.475, incomingKnockbackMultiplier = 0.6625, outgoingKnockbackMultiplier = 1.3375 },
	},
	Regeneration = {
		[1] = { healAmount = 500, tickInterval = 5 }, [5] = { healAmount = 650, tickInterval = 5 },
		[10] = { healAmount = 800, tickInterval = 5 }, [15] = { healAmount = 950, tickInterval = 5 },
		[20] = { healAmount = 1100, tickInterval = 5 }, Level50 = { healAmount = 1250, tickInterval = 5 },
	},
	PlasmaCannon = {
		[1] = { damage = 700, cooldown = 10, projectileSpeed = 15 },
		[5] = { damage = 800, cooldown = 10, projectileSpeed = 60 },
		[10] = { damage = 900, cooldown = 10, projectileSpeed = 60 },
		[15] = { damage = 1000, cooldown = 10, projectileSpeed = 60 },
		[20] = { damage = 1100, cooldown = 10, projectileSpeed = 60 },
		Level50 = { damage = 1200, cooldown = 10, projectileSpeed = 60 },
	},
	SlowBlaster = {
		[1] = { slowDuration = 3, cooldown = 8, projectileSpeed = 10, lifetime = 10 },
		[5] = { slowDuration = 3.5, cooldown = 8, projectileSpeed = 15, lifetime = 10 },
		[10] = { slowDuration = 4, cooldown = 8, projectileSpeed = 15, lifetime = 10 },
		[15] = { slowDuration = 4.5, cooldown = 8, projectileSpeed = 15, lifetime = 10 },
		[20] = { slowDuration = 5, cooldown = 8, projectileSpeed = 15, lifetime = 10 },
		Level50 = { slowDuration = 5.5, cooldown = 8, projectileSpeed = 15, lifetime = 10 },
	},
	Slow = {
		[1] = { collisionExtraDuration = 3 }, [5] = { collisionExtraDuration = 3.5 },
		[10] = { collisionExtraDuration = 4 }, [15] = { collisionExtraDuration = 4.5 },
		[20] = { collisionExtraDuration = 5 }, Level50 = { collisionExtraDuration = 5.5 },
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
