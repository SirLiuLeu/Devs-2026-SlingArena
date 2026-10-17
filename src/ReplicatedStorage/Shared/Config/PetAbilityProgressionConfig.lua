--!strict

-- Most ability values change at milestones; Titan weight/hitbox scale with pet level,
-- while equipped Titan's visual growth is earned from player level-ups in real time.
local PetAbilityProgressionConfig = {}

PetAbilityProgressionConfig.TitanVisualGrowthPerPlayerLevel = 0.04
PetAbilityProgressionConfig.TitanVisualMultiplierCap = 2

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
		[1] = { weightMultiplier = 1.00, hitboxMultiplier = 1.00, visualMultiplier = 1.00, incomingKnockbackMultiplier = 0.90, outgoingKnockbackMultiplier = 1.10 }, [5] = { weightMultiplier = 1.06, hitboxMultiplier = 1.08, visualMultiplier = 1.16, incomingKnockbackMultiplier = 0.86, outgoingKnockbackMultiplier = 1.14 }, [10] = { weightMultiplier = 1.135, hitboxMultiplier = 1.18, visualMultiplier = 1.36, incomingKnockbackMultiplier = 0.81, outgoingKnockbackMultiplier = 1.19 }, [15] = { weightMultiplier = 1.21, hitboxMultiplier = 1.28, visualMultiplier = 1.56, incomingKnockbackMultiplier = 0.76, outgoingKnockbackMultiplier = 1.24 }, [20] = { weightMultiplier = 1.29, hitboxMultiplier = 1.38, visualMultiplier = 1.76, incomingKnockbackMultiplier = 0.71, outgoingKnockbackMultiplier = 1.29 },
		Display = { Format = "text", Templates = { vi = "Khi Hydra được trang bị: Launcher tăng 4% kích thước mỗi cấp người chơi (tối đa 2x)", en = "While Hydra is equipped: Launcher size grows 4% per player level (up to 2x)" } },
	},
	Regeneration = {
		[1] = { healAmount = 500, tickInterval = 5 }, [5] = { healAmount = 650, tickInterval = 5 }, [10] = { healAmount = 800, tickInterval = 5 }, [15] = { healAmount = 950, tickInterval = 5 }, [20] = { healAmount = 1100, tickInterval = 5 },
		Display = { Format = "number", Templates = { vi = "Hồi {current} -> {next} HP", en = "Restore {current} -> {next} HP" } },
	},
	PlasmaCannon = {
		[1] = { damage = 700, cooldown = 10, projectileSpeed = 15 }, [5] = { damage = 800, cooldown = 10, projectileSpeed = 60 }, [10] = { damage = 900, cooldown = 10, projectileSpeed = 60 }, [15] = { damage = 1000, cooldown = 10, projectileSpeed = 60 }, [20] = { damage = 1100, cooldown = 10, projectileSpeed = 60 },
		Display = { Format = "number", Templates = { vi = "Sát thương {current} -> {next}", en = "Damage {current} -> {next}" } },
	},
	SlowBlaster = {
		[1] = { slowDuration = 3, cooldown = 8, projectileSpeed = 10, lifetime = 10 }, [5] = { slowDuration = 3.5, cooldown = 8, projectileSpeed = 15, lifetime = 10 }, [10] = { slowDuration = 4, cooldown = 8, projectileSpeed = 15, lifetime = 10 }, [15] = { slowDuration = 4.5, cooldown = 8, projectileSpeed = 15, lifetime = 10 }, [20] = { slowDuration = 5, cooldown = 8, projectileSpeed = 15, lifetime = 10 },
		Display = { Format = "number", Templates = { vi = "Làm chậm {current} -> {next}s", en = "Slow for {current} -> {next}s" } },
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
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, 20)
	if abilityId == "Titan" then
		return {
			weightMultiplier = math.min(1.5, 1 + 0.015 * (safeLevel - 1) + (if safeLevel >= 20 then 0.005 else 0)),
			hitboxMultiplier = math.min(1.5, 1 + 0.02 * (safeLevel - 1)),
			visualMultiplier = 1,
			sizeMultiplier = 1,
			incomingKnockbackMultiplier = math.max(0.70, 0.90 - 0.01 * (safeLevel - 1)),
			outgoingKnockbackMultiplier = 1.10 + 0.01 * (safeLevel - 1),
		}
	end
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
