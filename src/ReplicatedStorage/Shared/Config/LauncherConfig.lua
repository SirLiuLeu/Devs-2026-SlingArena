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

export type LauncherDefinition = {
	id: string,
	name: string,
	iconId: string,
	stats: LauncherStats,
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
		iconId = "rbxassetid://0",
		stats = { maxHP = 18000, baseDamage = 900, armor = 0, regen = 1, speed = 15.5, launchPower = 1.0, control = 1.05, launchSpeed = 80 },
	},
	StunLauncher = {
		id = "StunLauncher",
		name = "Stun Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 20000, baseDamage = 1000, armor = 0, regen = 1, speed = 15.5, launchPower = 1.0, control = 1.0, launchSpeed = 85 },
	},
	NormalLauncher = {
		id = "NormalLauncher",
		name = "Normal Launcher",
		iconId = "rbxassetid://0",
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
	},
	VacuumLauncher = {
		id = "VacuumLauncher",
		name = "Vacuum Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 15000, baseDamage = 800, armor = 0, regen = 1, speed = 16.2, launchPower = 0.95, control = 1.1, launchSpeed = 88 },
	},
	StealthLauncher = {
		id = "StealthLauncher",
		name = "Stealth Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 13000, baseDamage = 1200, armor = 0, regen = 1, speed = 18, launchPower = 1.05, control = 1.15, launchSpeed = 95 },
	},
	HealLauncher = {
		id = "HealLauncher",
		name = "Heal Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 18000, baseDamage = 800, armor = 0, regen = 1.1, speed = 15, launchPower = 0.95, control = 1.05, launchSpeed = 82 },
	},
	BonusBuffLauncher = {
		id = "BonusBuffLauncher",
		name = "Bonus Buff Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 22000, baseDamage = 1200, armor = 0.15, regen = 1.1, speed = 17, launchPower = 1.1, control = 1.05, launchSpeed = 80 },
	},
	PetrifyLauncher = {
		id = "PetrifyLauncher",
		name = "Petrify Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 20000, baseDamage = 900, armor = 0, regen = 1, speed = 15, launchPower = 1.0, control = 1.1, launchSpeed = 82 },
	},
	FireLauncher = {
		id = "FireLauncher",
		name = "Fire Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 14000, baseDamage = 1200, armor = 0, regen = 1, speed = 17, launchPower = 1.1, control = 0.95, launchSpeed = 90 },
	},
	PoisonLauncher = {
		id = "PoisonLauncher",
		name = "Poison Launcher",
		iconId = "rbxassetid://0",
		stats = { maxHP = 15000, baseDamage = 900, armor = 0, regen = 1, speed = 16.5, launchPower = 1.0, control = 1.05, launchSpeed = 88 },
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
