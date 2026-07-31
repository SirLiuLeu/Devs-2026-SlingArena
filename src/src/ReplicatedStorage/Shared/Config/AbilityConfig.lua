--!strict

-- Launcher archetype tuning from Rule_DESIGN.md section 5.
-- Values only define the rules in the design; services own server-authoritative execution.
local GameConfig = require(script.Parent.GameConfig)

local AbilityConfig = {}

-- RCA cleanup: define the launcher-to-flag map before AbilityConfig.Types to avoid nil forward references.
local LauncherFlagMap = {
	PetrifyLauncher = "Petrify",
	StunLauncher = "Stun",
	PoisonLauncher = "Poison",
	FireLauncher = "Burn",
}

AbilityConfig.LauncherFlagMap = LauncherFlagMap

local function flagDuration(flagName: string): number
	local flagConfig = GameConfig.FlagConfig[flagName]
	return (flagConfig and flagConfig.Duration) or 0
end

AbilityConfig.Types = {
	SupportLauncher = {
		id = "SupportLauncher",
		healAllyOnCollision = true,
		healAmountBaseDamageMultiplier = 0.5,
	},
	StunLauncher = {
		id = "StunLauncher",
		collisionFlag = LauncherFlagMap.StunLauncher,
		collisionExtraDuration = flagDuration("Stun"),
	},
	NormalLauncher = {
		id = "NormalLauncher",
		expBonus = 0.5,
	},
	VacuumLauncher = {
		id = "VacuumLauncher",
		clientScanOnly = true,
		scanRadius = 22,
	},
	StealthLauncher = {
		id = "StealthLauncher",
		invisibleWhileCharging = true,
		postLaunchInvisibleDuration = 1,
		revealOnCollision = true,
	},
	HealLauncher = {
		id = "HealLauncher",
		healOnLaunchMaxHpPercent = 0.05,
	},
	SpeedLauncher = {
		id = "SpeedLauncher",
		moveSpeedPerLaunchPercent = 0.05,
		maxMoveSpeedStacks = 10,
	},
	BonusBuffLauncher = {
		id = "BonusBuffLauncher",
		maxHpMultiplier = 1.15,
		armor = 0.15,
		moveSpeedMultiplier = 1.1,
		regenMultiplier = 1.1,
		damageMultiplier = 1.15,
		reflectDamage = 0.1,
	},
	PetrifyLauncher = {
		id = "PetrifyLauncher",
		collisionFlag = LauncherFlagMap.PetrifyLauncher,
		collisionExtraDuration = flagDuration("Petrify"),
		cannotPetrifyAbilityTypes = { FireLauncher = true },
	},
	FireLauncher = {
		id = "FireLauncher",
		dotFlag = LauncherFlagMap.FireLauncher,
	},
	PoisonLauncher = {
		id = "PoisonLauncher",
		dotFlag = LauncherFlagMap.PoisonLauncher,
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
