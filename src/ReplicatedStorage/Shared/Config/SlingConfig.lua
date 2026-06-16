--!strict

local SlingConfig = {}

export type SlingStats = {
	maxHP: number,
	baseDamage: number,
	armor: number,
	regen: number,
	speed: number,
	launchPower: number,
	control: number,
	weight: number,
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

export type SlingDefinition = {
	id: string,
	name: string,
	abilityType: string?,
	iconId: string,
	stats: SlingStats,
	passiveAbility: PassiveAbility,
	collisionAbility: CollisionAbility,
}

SlingConfig.DefaultSlingId = "NormalSling"
SlingConfig.ModelScale = 1
SlingConfig.BaseStats = {
	maxHP = 30000,
	baseDamage = 1000,
	reflectDamagePercent = 0.05,
	regenPerSecond = 2,
	maxShootRange = 120,
	size = 1,
}

SlingConfig.Types = {
	SupportSling = {
		id = "SupportSling",
		name = "Support Sling",
		abilityType = "SupportSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 18000, baseDamage = 900, armor = 0, regen = 1, speed = 15.5, launchPower = 1.0, control = 1.05, weight = 111.0 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = {},
	},
	StunSling = {
		id = "StunSling",
		name = "Stun Sling",
		abilityType = "StunSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 20000, baseDamage = 1000, armor = 0, regen = 1, speed = 15.5, launchPower = 1.0, control = 1.0, weight = 0.5 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Stun", durationBase = 1.25 },
	},
	NormalSling = {
		id = "NormalSling",
		name = "Normal Sling",
		iconId = "rbxassetid://0",
		abilityType = "NormalSling",
		stats = {
			maxHP = 16000,
			baseDamage = 1000,
			armor = 0,
			regen = 1,
			speed = 16,
			launchPower = 1.0,
			control = 1.0,
			weight = 1.0,
		},
		passiveAbility = { type = "ExpBonus", value = 0.5 },
		collisionAbility = {},
	},
	VacuumSling = {
		id = "VacuumSling",
		name = "Vacuum Sling",
		abilityType = "VacuumSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 15000, baseDamage = 800, armor = 0, regen = 1, speed = 16.2, launchPower = 0.95, control = 1.1, weight = 0.98 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = {},
	},
	StealthSling = {
		id = "StealthSling",
		name = "Stealth Sling",
		abilityType = "StealthSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 13000, baseDamage = 1200, armor = 0, regen = 1, speed = 18, launchPower = 1.05, control = 1.15, weight = 10.9 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = {},
	},
	HealSling = {
		id = "HealSling",
		name = "Heal Sling",
		abilityType = "HealSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 18000, baseDamage = 800, armor = 0, regen = 1.1, speed = 15, launchPower = 0.95, control = 1.05, weight = 1.0 },
		passiveAbility = { type = "HealOnLaunch", percent = 0.05 },
		collisionAbility = {},
	},
	BonusBuffSling = {
		id = "BonusBuffSling",
		name = "Bonus Buff Sling",
		abilityType = "BonusBuffSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 22000, baseDamage = 1200, armor = 0.15, regen = 1.1, speed = 17, launchPower = 1.1, control = 1.05, weight = 1.0 },
		passiveAbility = { type = "ExpBoost", params = { expBonus = 0.1 } },
		collisionAbility = {},
	},
	PetrifySling = {
		id = "PetrifySling",
		name = "Petrify Sling",
		abilityType = "PetrifySling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 20000, baseDamage = 900, armor = 0, regen = 1, speed = 15, launchPower = 1.0, control = 1.1, weight = 1.05 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Petrify", durationBase = 1.5 },
	},
	FireSling = {
		id = "FireSling",
		name = "Fire Sling",
		abilityType = "FireSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 14000, baseDamage = 1200, armor = 0, regen = 1, speed = 17, launchPower = 1.1, control = 0.95, weight = 0.95 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Burn", durationBase = 4, TickInterval = 1, DamagePerTick = 250 },
	},
	PoisonSling = {
		id = "PoisonSling",
		name = "Poison Sling",
		abilityType = "PoisonSling",
		iconId = "rbxassetid://0",
		stats = { maxHP = 15000, baseDamage = 900, armor = 0, regen = 1, speed = 16.5, launchPower = 1.0, control = 1.05, weight = 0.95 },
		passiveAbility = { type = "None", params = {} },
		collisionAbility = { flagName = "Poison", durationBase = 5, TickInterval = 1, DamagePerTick = 150, SlowAmount = 0.25 },
	},
} :: { [string]: SlingDefinition }

function SlingConfig.GetById(id: string): SlingDefinition?
	return SlingConfig.Types[id]
end

function SlingConfig.GetAllIds(): { string }
	local result = {}
	for id in pairs(SlingConfig.Types) do
		table.insert(result, id)
	end
	table.sort(result)
	return result
end

return SlingConfig
