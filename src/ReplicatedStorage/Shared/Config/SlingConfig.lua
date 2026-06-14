--!strict

local SlingConfig = {}

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
	{
		id = "SupportSling",
		name = "Support Sling",
		abilityType = "SupportSling",
		stats = { speed = 15.5, weight = 111.0, launchPower = 1.0, control = 1.05, maxHP = 18000, baseDamage = 900, armor = 0, regen = 1 },
	},
	{
		id = "StunSling",
		name = "Stun Sling",
		abilityType = "StunSling",
		stats = { speed = 15.5, weight = 0.5, launchPower = 1.0, control = 1.0, maxHP = 20000, baseDamage = 1000, armor = 0, regen = 1 },
	},
	{
		id = "NormalSling",
		name = "Normal Sling",
		abilityType = "NormalSling",
		stats = { speed = 16, weight = 1.0, launchPower = 1.0, control = 1.0, maxHP = 16000, baseDamage = 1000, armor = 0, regen = 1 },
	},
	{
		id = "VacuumSling",
		name = "Vacuum Sling",
		abilityType = "VacuumSling",
		stats = { speed = 16.2, weight = 0.98, launchPower = 0.95, control = 1.1, maxHP = 15000, baseDamage = 800, armor = 0, regen = 1 },
	},
	{
		id = "StealthSling",
		name = "Stealth Sling",
		abilityType = "StealthSling",
		stats = { speed = 18, weight = 10.9, launchPower = 1.05, control = 1.15, maxHP = 13000, baseDamage = 1200, armor = 0, regen = 1 },
	},
	{
		id = "HealSling",
		name = "Heal Sling",
		abilityType = "HealSling",
		stats = { speed = 15, weight = 1.0, launchPower = 0.95, control = 1.05, maxHP = 18000, baseDamage = 800, armor = 0, regen = 1.1 },
	},
	{
		id = "BonusBuffSling",
		name = "Bonus Buff Sling",
		abilityType = "BonusBuffSling",
		stats = { speed = 17, weight = 1.0, launchPower = 1.1, control = 1.05, maxHP = 22000, baseDamage = 1200, armor = 0.15, regen = 1.1 },
	},
	{
		id = "PetrifySling",
		name = "Petrify Sling",
		abilityType = "PetrifySling",
		stats = { speed = 15, weight = 1.05, launchPower = 1.0, control = 1.1, maxHP = 20000, baseDamage = 900, armor = 0, regen = 1 },
	},
	{
		id = "FireSling",
		name = "Fire Sling",
		abilityType = "FireSling",
		stats = { speed = 17, weight = 0.95, launchPower = 1.1, control = 0.95, maxHP = 14000, baseDamage = 1200, armor = 0, regen = 1 },
	},
	{
		id = "PoisonSling",
		name = "Poison Sling",
		abilityType = "PoisonSling",
		stats = { speed = 16.5, weight = 0.95, launchPower = 1.0, control = 1.05, maxHP = 15000, baseDamage = 900, armor = 0, regen = 1 },
	},
}

local byId = {}
for _, sling in ipairs(SlingConfig.Types) do
	byId[sling.id] = sling
end

function SlingConfig.GetById(id: string)
	return byId[id]
end

function SlingConfig.GetAllIds(): { string }
	local result = {}
	for _, sling in ipairs(SlingConfig.Types) do
		table.insert(result, sling.id)
	end
	return result
end

return SlingConfig
