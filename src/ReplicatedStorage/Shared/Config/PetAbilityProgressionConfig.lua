--!strict

-- Ability growth is authored per parameter using Level1 and Level50 targets.
-- Milestones 5/10/15/20 deliver 20% each (80% total); levels 25-50 distribute
-- the remaining 20% evenly. Discrete unlocks remain explicit milestone overrides.
local PetAbilityProgressionConfig = {}

PetAbilityProgressionConfig.MaxLevel = 50
PetAbilityProgressionConfig.TitanVisualGrowthPerPlayerLevel = 0.04
PetAbilityProgressionConfig.TitanVisualMultiplierCap = 2
PetAbilityProgressionConfig.Milestones = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }

PetAbilityProgressionConfig.Abilities = {
	ExpBonus = {
		Level1 = { expBonus = 0.30 },
		Level50 = { expBonus = 0.60 },
	},
	Shield = {
		Level1 = { damageMultiplier = 0.80 },
		Level50 = { damageMultiplier = 0.52 },
	},
	Titan = {
		Level1 = {
			weightMultiplier = 1.00,
			hitboxMultiplier = 1.00,
			incomingKnockbackMultiplier = 0.90,
			outgoingKnockbackMultiplier = 1.10,
		},
		Level50 = {
			weightMultiplier = 1.348,
			hitboxMultiplier = 1.456,
			incomingKnockbackMultiplier = 0.652,
			outgoingKnockbackMultiplier = 1.348,
		},
	},
	Regeneration = {
		Level1 = { healAmount = 500, tickInterval = 5 },
		Level50 = { healAmount = 1320, tickInterval = 5 },
	},
	PlasmaCannon = {
		Level1 = { damage = 700, cooldown = 10, projectileSpeed = 15 },
		Level50 = { damage = 1320, cooldown = 10, projectileSpeed = 15 },
		MilestoneOverrides = {
			[5] = { projectileSpeed = 60 },
		},
	},
	SlowBlaster = {
		Level1 = { slowDuration = 3, cooldown = 8, projectileSpeed = 10, lifetime = 10 },
		Level50 = { slowDuration = 6, cooldown = 8, projectileSpeed = 10, lifetime = 10 },
		MilestoneOverrides = {
			[5] = { projectileSpeed = 15 },
		},
	},
	Slow = {
		Level1 = { collisionExtraDuration = 3 },
		Level50 = { collisionExtraDuration = 6 },
	},
}

local function getMilestoneProgress(level: number): number
	if level <= 1 then return 0 end
	if level <= 20 then return level / 25 end
	return 0.80 + ((level - 20) / 30) * 0.20
end

function PetAbilityProgressionConfig.GetParams(abilityId: string?, level: number): { [string]: any }
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, PetAbilityProgressionConfig.MaxLevel)
	local ability = abilityId and PetAbilityProgressionConfig.Abilities[abilityId]
	if not ability then return {} end

	local selectedMilestone = 1
	for _, milestone in ipairs(PetAbilityProgressionConfig.Milestones) do
		if safeLevel >= milestone then
			selectedMilestone = milestone
		else
			break
		end
	end

	local progress = getMilestoneProgress(selectedMilestone)
	local result = {}
	local level1 = ability.Level1 or {}
	local level50 = ability.Level50 or {}
	for key, initialValue in pairs(level1) do
		local targetValue = level50[key]
		if type(initialValue) == "number" and type(targetValue) == "number" then
			result[key] = initialValue + (targetValue - initialValue) * progress
		else
			result[key] = initialValue
		end
	end

	for _, milestone in ipairs(PetAbilityProgressionConfig.Milestones) do
		if milestone > selectedMilestone then break end
		local overrides = ability.MilestoneOverrides and ability.MilestoneOverrides[milestone]
		if type(overrides) == "table" then
			for key, value in pairs(overrides) do result[key] = value end
		end
	end
	return result
end

return PetAbilityProgressionConfig
