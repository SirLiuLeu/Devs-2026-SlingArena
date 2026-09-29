--!strict

-- Ability values change only at the listed pet-level milestones.
local PetAbilityProgressionConfig = {}

PetAbilityProgressionConfig.Milestones = { 1, 5, 10, 15, 20 }
PetAbilityProgressionConfig.Abilities = {
	ExpBonus = {
		[1] = { expBonus = 0.30 }, [5] = { expBonus = 0.35 }, [10] = { expBonus = 0.40 }, [15] = { expBonus = 0.45 }, [20] = { expBonus = 0.50 },
		Display = { Format = "percent", Templates = { vi = "Tăng {current} -> {next} EXP", en = "Increase {current} -> {next} EXP" } },
	},
	Shield = {
		[1] = { damageMultiplier = 0.80 }, [5] = { damageMultiplier = 0.75 }, [10] = { damageMultiplier = 0.70 }, [15] = { damageMultiplier = 0.65 }, [20] = { damageMultiplier = 0.60 },
		Display = { Format = "percent", Templates = { vi = "Giảm sát thương nhận vào {current} -> {next}", en = "Reduce incoming damage {current} -> {next}" } },
	},
	Titan = {
		[1] = { sizeMultiplier = 1.20, incomingKnockbackMultiplier = 0.75, outgoingKnockbackMultiplier = 1.25 }, [5] = { sizeMultiplier = 1.25, incomingKnockbackMultiplier = 0.70, outgoingKnockbackMultiplier = 1.30 }, [10] = { sizeMultiplier = 1.30, incomingKnockbackMultiplier = 0.65, outgoingKnockbackMultiplier = 1.35 }, [15] = { sizeMultiplier = 1.35, incomingKnockbackMultiplier = 0.60, outgoingKnockbackMultiplier = 1.40 }, [20] = { sizeMultiplier = 1.40, incomingKnockbackMultiplier = 0.55, outgoingKnockbackMultiplier = 1.45 },
		Display = { Format = "multiplier", Templates = { vi = "Tăng kích thước {current} -> {next}", en = "Increase size {current} -> {next}" } },
	},
	Regeneration = {
		[1] = { healAmount = 500, tickInterval = 5 }, [5] = { healAmount = 650, tickInterval = 5 }, [10] = { healAmount = 800, tickInterval = 5 }, [15] = { healAmount = 950, tickInterval = 5 }, [20] = { healAmount = 1100, tickInterval = 5 },
		Display = { Format = "number", Templates = { vi = "Hồi {current} -> {next} HP", en = "Restore {current} -> {next} HP" } },
	},
	Slow = {
		[1] = { collisionExtraDuration = 3 }, [5] = { collisionExtraDuration = 3.5 }, [10] = { collisionExtraDuration = 4 }, [15] = { collisionExtraDuration = 4.5 }, [20] = { collisionExtraDuration = 5 },
		Display = { Format = "number", Templates = { vi = "Làm chậm {current} -> {next}s", en = "Slow for {current} -> {next}s" } },
	},
}

local function copy(source: { [string]: any }): { [string]: any }
	local result = {}
	for key, value in pairs(source) do result[key] = value end
	return result
end

function PetAbilityProgressionConfig.GetParams(abilityId: string?, level: number): { [string]: any }
	local ability = abilityId and PetAbilityProgressionConfig.Abilities[abilityId]
	if not ability then return {} end
	local selected = 1
	for _, milestone in ipairs(PetAbilityProgressionConfig.Milestones) do
		if level >= milestone then selected = milestone else break end
	end
	return copy(ability[selected] or {})
end

function PetAbilityProgressionConfig.GetDisplay(abilityId: string?): { [string]: any }?
	local ability = abilityId and PetAbilityProgressionConfig.Abilities[abilityId]
	return ability and ability.Display or nil
end

return PetAbilityProgressionConfig
