--!strict

-- Sling archetype tuning from Rule_DESIGN.md section 5.
-- Values only define the rules in the design; services own server-authoritative execution.
local AbilityConfig = {}

AbilityConfig.Types = {
	SupportSling = {
		id = "SupportSling",
		healAllyOnCollision = true,
		healAmountBaseDamageMultiplier = 0.5,
	},
	StunSling = {
		id = "StunSling",
		collisionFlag = "Stun",
		collisionCCDuration = 1,
	},
	NormalSling = {
		id = "NormalSling",
		expBonus = 0.5,
	},
	VacuumSling = {
		id = "VacuumSling",
		clientScanOnly = true,
		scanRadius = 22,
	},
	StealthSling = {
		id = "StealthSling",
		invisibleWhileCharging = true,
		postLaunchInvisibleDuration = 1,
		revealOnCollision = true,
	},
	HealSling = {
		id = "HealSling",
		healOnLaunchMaxHpPercent = 0.05,
	},
	SpeedSling = {
		id = "SpeedSling",
		moveSpeedPerLaunchPercent = 0.05,
		maxMoveSpeedStacks = 10,
	},
	BonusBuffSling = {
		id = "BonusBuffSling",
		maxHpMultiplier = 1.15,
		armor = 0.15,
		moveSpeedMultiplier = 1.1,
		regenMultiplier = 1.1,
		damageMultiplier = 1.15,
		reflectDamage = 0.1,
	},
	FreezeSling = {
		id = "FreezeSling",
		collisionFlag = "Freeze",
		collisionCCDuration = 1.5,
		cannotFreezeAbilityTypes = { FireSling = true },
	},
	FireSling = {
		id = "FireSling",
		dotFlag = "Burn",
		dotDamagePerTick = 250,
		dotTickInterval = 1,
		dotDuration = 4,
		dotMaxStack = 3,
	},
	PoisonSling = {
		id = "PoisonSling",
		dotFlag = "Poison",
		dotDamagePerTick = 150,
		dotTickInterval = 1,
		dotDuration = 5,
		dotMaxStack = 5,
		slowAmount = 0.25,
		slowDuration = 3,
	},
}

local byId = AbilityConfig.Types

function AbilityConfig.GetById(id: string)
	return byId[id]
end

function AbilityConfig.GetAllIds(): { string }
	local ids = {}
	for id in pairs(byId) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return AbilityConfig
