--!strict

local LauncherConfig = {}

export type LauncherStats = {
	maxHP: number,
	baseDamage: number,
	armor: number,
	regen: number,
	speed: number,
	launchPower: number,
	launchSpeed: number,
	reflectDamage: number,
	weight: number,
}

export type LauncherDefinition = {
	id: string,
	name: string,
	description: string?,
	script: string,
	shopPrice: number,
	iconId: string,
	sellPrice: number,
	stats: LauncherStats,
}

LauncherConfig.DefaultLauncherId = "Normalduck"
LauncherConfig.ModelScale = 1
LauncherConfig.TemporarySellPrice = 5
LauncherConfig.BaseStats = {
	maxHP = 30000,
	baseDamage = 1000,
	reflectDamagePercent = 0.05,
	regenPerSecond = 2,
	size = 1,
	weight = 100,
}

local DEFAULT_ICON = "rbxassetid://116884908373456"

LauncherConfig.Types = {
	Normalduck = {
		id = "Normalduck",
		name = "Normal Duck",
		description = "A balanced all-rounder.",
		script = "Launcher cơ bản với HP, sát thương, tốc độ và lực phóng cân bằng. Phù hợp làm lựa chọn khởi đầu.",
		shopPrice = 100,
		iconId = DEFAULT_ICON,
		sellPrice = 1,
		stats = {
			maxHP = 16000,
			baseDamage = 1000,
			armor = 0,
			regen = 1.0,
			speed = 16,
			launchPower = 1.0,
			launchSpeed = 100,
			reflectDamage = 0.05,
			weight = 100,
		},
	},
	Kingduck = {
		id = "Kingduck",
		name = "King Duck",
		description = "A heavy defensive launcher with high durability.",
		script = "Launcher thiên phòng thủ, có HP và giáp cao. Đổi lại tốc độ di chuyển và khả năng cơ động thấp hơn.",
		shopPrice = 900,
		iconId = DEFAULT_ICON,
		sellPrice = 2,
		stats = {
			maxHP = 28000,
			baseDamage = 700,
			armor = 0.30,
			regen = 1.4,
			speed = 12.5,
			launchPower = 0.85,
			launchSpeed = 65,
			reflectDamage = 0.12,
			weight = 130,
		},
	},
	Witchduck = {
		id = "Witchduck",
		name = "Witch Duck",
		description = "A light, highly mobile launcher.",
		script = "Launcher nhẹ, cơ động và có tốc độ di chuyển cao, nhưng khả năng chịu đòn thấp hơn.",
		shopPrice = 1200,
		iconId = DEFAULT_ICON,
		sellPrice = 2,
		stats = {
			maxHP = 11000,
			baseDamage = 650,
			armor = 0,
			regen = 0.8,
			speed = 22,
			launchPower = 1.05,
			launchSpeed = 110,
			reflectDamage = 0.03,
			weight = 80,
		},
	},
	Drakeduck = {
		id = "Drakeduck",
		name = "Drake Duck",
		description = "A high-impact launcher focused on damage.",
		script = "Launcher tập trung vào sát thương và lực va chạm mạnh, phù hợp lối chơi tấn công chủ động.",
		shopPrice = 1800,
		iconId = DEFAULT_ICON,
		sellPrice = 3,
		stats = {
			maxHP = 13500,
			baseDamage = 1650,
			armor = 0,
			regen = 0.9,
			speed = 15,
			launchPower = 1.20,
			launchSpeed = 90,
			reflectDamage = 0.08,
			weight = 115,
		},
	},
	Shielduck = {
		id = "Shielduck",
		name = "Shield Duck",
		description = "A resilient launcher with strong defensive stats.",
		script = "Launcher bền bỉ với HP và giáp tốt, phù hợp lối chơi trụ giao tranh và chịu đòn.",
		shopPrice = 1500,
		iconId = DEFAULT_ICON,
		sellPrice = 3,
		stats = {
			maxHP = 23000,
			baseDamage = 850,
			armor = 0.22,
			regen = 1.2,
			speed = 14,
			launchPower = 0.90,
			launchSpeed = 80,
			reflectDamage = 0.10,
			weight = 120,
		},
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
