--!strict

local LauncherConfig = {}

export type LauncherStats = {
	maxHP: number,
	baseDamage: number,
	armor: number,
	regen: number,
	speed: number,
	launchPower: number,
	control: number,
	launchSpeed: number,
}

export type PassiveAbility = {
	type: string,
	params: { [string]: any }?,
	[string]: any,
}

export type CollisionAbility = {
	flagName: string?,
	durationBase: number?,
	[string]: any,
}

export type LauncherDefinition = {
	id: string,
	name: string,
	abilityType: string?,
	iconId: string,
	stats: LauncherStats,
	passiveAbility: PassiveAbility,
	collisionAbility: CollisionAbility,
}

LauncherConfig.DefaultLauncherId = "NormalLauncher"
LauncherConfig.ModelScale = 1
LauncherConfig.BaseStats = {
	maxHP = 30000,
	baseDamage = 1000,
	reflectDamagePercent = 0.05,
	regenPerSecond = 2,
	maxShootRange = 120,
	size = 1,
}

LauncherConfig.Types = {
	SupportLauncher = {
		id = "SupportLauncher",
		name = "Support Launcher",
		abilityType = "SupportLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 18000, baseDamage = 900, armor = 0, regen = 1, speed = 15.5, launchPower = 1.0, control = 1.05, launchSpeed = 80 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = {},
	},
	StunLauncher = {
		id = "StunLauncher",
		name = "Stun Launcher",
		abilityType = "StunLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 20000, baseDamage = 1000, armor = 0, regen = 1, speed = 15.5, launchPower = 1.0, control = 1.0, launchSpeed = 85 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Stun", durationBase = 1.25 },
	},
	NormalLauncher = {
		id = "NormalLauncher",
		name = "Normal Launcher",
		iconId = "rbxassetid://0",
		abilityType = "NormalLauncher",
		stats = {
			maxHP = 16000,
			baseDamage = 1000,
			armor = 0,
			regen = 1,
			speed = 16,
			launchPower = 1.0,
			control = 1.0,
			launchSpeed = 100,
		},
		passiveAbility = { type = "ExpBonus", value = 0.5 },
		collisionAbility = {},
	},
	VacuumLauncher = {
		id = "VacuumLauncher",
		name = "Vacuum Launcher",
		abilityType = "VacuumLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 15000, baseDamage = 800, armor = 0, regen = 1, speed = 16.2, launchPower = 0.95, control = 1.1, launchSpeed = 88 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = {},
	},
	StealthLauncher = {
		id = "StealthLauncher",
		name = "Stealth Launcher",
		abilityType = "StealthLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 13000, baseDamage = 1200, armor = 0, regen = 1, speed = 18, launchPower = 1.05, control = 1.15, launchSpeed = 95 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = {},
	},
	HealLauncher = {
		id = "HealLauncher",
		name = "Heal Launcher",
		abilityType = "HealLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 18000, baseDamage = 800, armor = 0, regen = 1.1, speed = 15, launchPower = 0.95, control = 1.05, launchSpeed = 82 },
		passiveAbility = { type = "HealOnLaunch", percent = 0.05 },
		collisionAbility = {},
	},
	BonusBuffLauncher = {
		id = "BonusBuffLauncher",
		name = "Bonus Buff Launcher",
		abilityType = "BonusBuffLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 22000, baseDamage = 1200, armor = 0.15, regen = 1.1, speed = 17, launchPower = 1.1, control = 1.05, launchSpeed = 80 },
		passiveAbility = { type = "ExpBoost", params = { expBonus = 0.1 } },
		collisionAbility = {},
	},
	PetrifyLauncher = {
		id = "PetrifyLauncher",
		name = "Petrify Launcher",
		abilityType = "PetrifyLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 20000, baseDamage = 900, armor = 0, regen = 1, speed = 15, launchPower = 1.0, control = 1.1, launchSpeed = 82 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Petrify", durationBase = 1.5 },
	},
	FireLauncher = {
		id = "FireLauncher",
		name = "Fire Launcher",
		abilityType = "FireLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 14000, baseDamage = 1200, armor = 0, regen = 1, speed = 17, launchPower = 1.1, control = 0.95, launchSpeed = 90 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Burn", durationBase = 4, TickInterval = 1, DamagePerTick = 250 },
	},
	PoisonLauncher = {
		id = "PoisonLauncher",
		name = "Poison Launcher",
		abilityType = "PoisonLauncher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 15000, baseDamage = 900, armor = 0, regen = 1, speed = 16.5, launchPower = 1.0, control = 1.05, launchSpeed = 88 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Poison", durationBase = 5, TickInterval = 1, DamagePerTick = 150, SlowAmount = 0.25 },
	},
} :: { [string]: LauncherDefinition }

function LauncherConfig.GetById(id: string): LauncherDefinition?
	return LauncherConfig.Types[id]
end

function LauncherConfig.GetAllIds(): { string }
	local result = {}
	for id in pairs(LauncherConfig.Types) do
		table.insert(result, id)
	end
	table.sort(result)
	return result
end

return LauncherConfig
