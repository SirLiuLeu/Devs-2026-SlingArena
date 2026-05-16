--!strict

-- [SLING_MODEL_GUIDE]
-- 1) Create each sling as a Model under ReplicatedStorage/Slings or ReplicatedStorage/Assets/Slings.
-- 2) Model.Name MUST match config id exactly (case-sensitive).
-- 3) Each model should have a PrimaryPart and physics-ready parts.
-- 4) Register the same id below with stats/rarity/modelPath.
-- 5) modelPath format in this config: "ReplicatedStorage/<Folder>/<ModelName>".

local SlingConfig = {}

SlingConfig.DefaultSlingId = "NormalSling"

SlingConfig.Types = {
	{
		id = "SupportSling",
		name = "Support Sling",
		abilityType = "SupportSling",
		modelPath = "ReplicatedStorage/Assets/Slings/SupportSling",
		rarity = "Uncommon",
		stats = { speed = 15.5, weight = 1.0, launchPower = 1.0, control = 1.05, maxHP = 18000, baseDamage = 900, armor = 0, regen = 1 },
	},
	{
		id = "StunSling",
		name = "Stun Sling",
		abilityType = "StunSling",
		modelPath = "ReplicatedStorage/Assets/Slings/StunSling",
		rarity = "Rare",
		stats = { speed = 15.5, weight = 1.05, launchPower = 1.0, control = 1.0, maxHP = 20000, baseDamage = 1000, armor = 0, regen = 1 },
	},
	{
		id = "NormalSling",
		name = "Normal Sling",
		abilityType = "NormalSling",
		modelPath = "ReplicatedStorage/Assets/Slings/NormalSling",
		rarity = "Common",
		stats = { speed = 16, weight = 1.0, launchPower = 1.0, control = 1.0, maxHP = 16000, baseDamage = 1000, armor = 0, regen = 1 },
	},
	{
		id = "VacuumSling",
		name = "Vacuum Sling",
		abilityType = "VacuumSling",
		modelPath = "ReplicatedStorage/Assets/Slings/VacuumSling",
		rarity = "Uncommon",
		stats = { speed = 16.2, weight = 0.98, launchPower = 0.95, control = 1.1, maxHP = 15000, baseDamage = 800, armor = 0, regen = 1 },
	},
	{
		id = "StealthSling",
		name = "Stealth Sling",
		abilityType = "StealthSling",
		modelPath = "ReplicatedStorage/Assets/Slings/StealthSling",
		rarity = "Epic",
		stats = { speed = 18, weight = 0.9, launchPower = 1.05, control = 1.15, maxHP = 13000, baseDamage = 1200, armor = 0, regen = 1 },
	},
	{
		id = "HealSling",
		name = "Heal Sling",
		abilityType = "HealSling",
		modelPath = "ReplicatedStorage/Assets/Slings/HealSling",
		rarity = "Rare",
		stats = { speed = 15, weight = 1.0, launchPower = 0.95, control = 1.05, maxHP = 18000, baseDamage = 800, armor = 0, regen = 1.1 },
	},
	{
		id = "SpeedSling",
		name = "Speed Sling",
		abilityType = "SpeedSling",
		modelPath = "ReplicatedStorage/Assets/Slings/SpeedSling",
		rarity = "Epic",
		stats = { speed = 18.5, weight = 0.85, launchPower = 1.0, control = 1.1, maxHP = 13000, baseDamage = 1000, armor = 0, regen = 1 },
	},
	{
		id = "BonusBuffSling",
		name = "Bonus Buff Sling",
		abilityType = "BonusBuffSling",
		modelPath = "ReplicatedStorage/Assets/Slings/BonusBuffSling",
		rarity = "Legendary",
		stats = { speed = 17, weight = 1.0, launchPower = 1.1, control = 1.05, maxHP = 22000, baseDamage = 1200, armor = 0.15, regen = 1.1 },
	},
	{
		id = "PetrifyModel",
		name = "Petrify Sling",
		abilityType = "PetrifyModel",
		modelPath = "ReplicatedStorage/Assets/Slings/PetrifyModel",
		rarity = "Epic",
		stats = { speed = 15, weight = 1.05, launchPower = 1.0, control = 1.1, maxHP = 20000, baseDamage = 900, armor = 0, regen = 1 },
	},
	{
		id = "FireSling",
		name = "Fire Sling",
		abilityType = "FireSling",
		modelPath = "ReplicatedStorage/Assets/Slings/FireSling",
		rarity = "Rare",
		stats = { speed = 17, weight = 0.95, launchPower = 1.1, control = 0.95, maxHP = 14000, baseDamage = 1200, armor = 0, regen = 1 },
	},
	{
		id = "PoisonSling",
		name = "Poison Sling",
		abilityType = "PoisonSling",
		modelPath = "ReplicatedStorage/Assets/Slings/PoisonSling",
		rarity = "Rare",
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
