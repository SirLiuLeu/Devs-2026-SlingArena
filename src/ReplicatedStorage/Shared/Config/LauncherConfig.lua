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
	description: string?,
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
	TitanBulwarkLauncher = {
		id = "TitanBulwarkLauncher", name = "Titan Bulwark Launcher", description = "A reinforced launcher plated for the front line — soaks up punishment and shrugs off incoming fire, at the cost of raw mobility.", iconId = "rbxassetid://0",
		stats = { maxHP = 28000, baseDamage = 700, armor = 0.30, regen = 1.4, speed = 12.5, launchPower = 0.85, control = 0.90, launchSpeed = 65 },
	},
	ZephyrDartLauncher = {
		id = "ZephyrDartLauncher", name = "Zephyr Dart Launcher", description = "Built for hit-and-run tactics — outruns and outmaneuvers everything else on the field, but can't take a sustained fight.", iconId = "rbxassetid://0",
		stats = { maxHP = 11000, baseDamage = 650, armor = 0.0, regen = 0.8, speed = 22.0, launchPower = 1.05, control = 1.30, launchSpeed = 130 },
	},
	RavagerCoreLauncher = {
		id = "RavagerCoreLauncher", name = "Ravager Core Launcher", description = "An unstable overcharged core optimized purely for burst damage — devastating hits, fragile chassis.", iconId = "rbxassetid://0",
		stats = { maxHP = 13500, baseDamage = 1650, armor = 0.0, regen = 0.9, speed = 15.0, launchPower = 1.20, control = 0.95, launchSpeed = 90 },
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
