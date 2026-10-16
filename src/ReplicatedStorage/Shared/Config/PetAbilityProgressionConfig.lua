--!strict

-- Most ability values use milestones; Titan growth is calculated for every level.
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
		[1] = { sizeMultiplier = 1, weightMultiplier = 1, hitboxMultiplier = 1, visualMultiplier = 1, incomingKnockbackMultiplier = 0.90, outgoingKnockbackMultiplier = 1.10 },
		[5] = { sizeMultiplier = 1.06, weightMultiplier = 1.06, hitboxMultiplier = 1.08, visualMultiplier = 1.16, incomingKnockbackMultiplier = 0.86, outgoingKnockbackMultiplier = 1.13 },
		[10] = { sizeMultiplier = 1.135, weightMultiplier = 1.135, hitboxMultiplier = 1.18, visualMultiplier = 1.36, incomingKnockbackMultiplier = 0.82, outgoingKnockbackMultiplier = 1.16 },
		[15] = { sizeMultiplier = 1.21, weightMultiplier = 1.21, hitboxMultiplier = 1.28, visualMultiplier = 1.56, incomingKnockbackMultiplier = 0.78, outgoingKnockbackMultiplier = 1.19 },
		[20] = { sizeMultiplier = 1.29, weightMultiplier = 1.29, hitboxMultiplier = 1.38, visualMultiplier = 1.76, incomingKnockbackMultiplier = 0.74, outgoingKnockbackMultiplier = 1.22 },
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
	if abilityId == "Titan" then
		local safeLevel = math.clamp(math.floor(level), 1, 20)
		local weightMultiplier = 1 + math.min(safeLevel - 1, 18) * 0.015 + (if safeLevel >= 20 then 0.02 else 0)
		return {
			sizeMultiplier = weightMultiplier,
			weightMultiplier = weightMultiplier,
			hitboxMultiplier = math.min(1.5, 1 + (safeLevel - 1) * 0.02),
			visualMultiplier = math.min(2, 1 + (safeLevel - 1) * 0.04),
			incomingKnockbackMultiplier = 0.90 - (safeLevel - 1) * (0.16 / 19),
			outgoingKnockbackMultiplier = 1.10 + (safeLevel - 1) * (0.12 / 19),
		}
	end
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
