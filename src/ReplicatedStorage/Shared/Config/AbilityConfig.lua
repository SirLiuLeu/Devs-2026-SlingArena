--!strict

-- Sling archetype tuning from Rule_DESIGN.md section 5.
-- Values only define the rules in the design; services own server-authoritative execution.
local GameConfig = require(script.Parent.GameConfig)

local AbilityConfig = {}

local function flagDuration(flagName: string): number
	local flagConfig = GameConfig.FlagConfig[flagName]
	return (flagConfig and flagConfig.Duration) or 0
end

AbilityConfig.SlingFlagMap = {
	PetrifySling = "Petrify",
	StunSling = "Stun",
	PoisonSling = "Poison",
	FireSling = "Burn",
}

AbilityConfig.Types = {
	SupportSling = {
		id = "SupportSling",
		healAllyOnCollision = true,
		healAmountBaseDamageMultiplier = 0.5,
	},
	StunSling = {
		id = "StunSling",
		collisionFlag = AbilityConfig.SlingFlagMap.StunSling,
		collisionExtraDuration = flagDuration("Stun"),
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
	PetrifySling = {
		id = "PetrifySling",
		collisionFlag = AbilityConfig.SlingFlagMap.PetrifySling,
		collisionExtraDuration = flagDuration("Petrify"),
		cannotPetrifyAbilityTypes = { FireSling = true },
	},
	FireSling = {
		id = "FireSling",
		dotFlag = AbilityConfig.SlingFlagMap.FireSling,
	},
	PoisonSling = {
		id = "PoisonSling",
		dotFlag = AbilityConfig.SlingFlagMap.PoisonSling,
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
