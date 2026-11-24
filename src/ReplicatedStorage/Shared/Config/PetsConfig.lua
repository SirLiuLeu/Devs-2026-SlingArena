--!strict

local PetsConfig = {}

export type StatModifiers = {
	Add: { [string]: number }?,
	Multiply: { [string]: number }?,
}

export type CombatEffect = {
	collisionFlag: string?,
	collisionExtraDuration: number?,
	dotFlag: string?,
	applySlow: boolean?,
	cannotPetrifyPetIds: { [string]: boolean }?,
}

export type PetDefinition = {
	type: string,
	modelName: string,
	rarity: string,
	category: string,
	abilityId: string?,
	effectId: string,
	activeAbilityId: string?,
	combatEffect: CombatEffect?,
	effectParams: { [string]: any }?,
	statModifiers: StatModifiers?,
	iconId: string?,
}

type PetDefinitionOptions = {
	modelName: string,
	rarity: string,
	category: string,
	abilityId: string?,
	effectId: string?,
	activeAbilityId: string?,
	combatEffect: CombatEffect?,
	effectParams: { [string]: any }?,
	statModifiers: StatModifiers?,
	iconId: string?,
}

PetsConfig.EquippedSlotCount = 3
-- Retained for legacy slot-name normalization; Pet definitions themselves are Universal.
PetsConfig.SlotTypes = { Universal = "Universal", Core = "Core", Module = "Module", Charm = "Charm" }
PetsConfig.Rarities = { Common = "Common", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }
PetsConfig.MaxLevel = 50
PetsConfig.Categories = {
	ActiveAttack = "Active Attack",
	CrowdControl = "Crowd Control",
	DamageOverTime = "Damage Over Time",
	PassiveStatModifier = "Passive Stat Modifier",
	RegenerationHealing = "Regeneration / Healing",
	ConditionalEffect = "Conditional Effect",
	UtilityAreaEffect = "Utility / Area Effect",
}

-- Old definition IDs are normalized when persisted player profiles are loaded.
PetsConfig.LegacyIdAliases = {
	PlasmaCannon = "Titan",
}

local function pet(petType: string, options: PetDefinitionOptions): PetDefinition
	local abilityId = options.abilityId or petType
	return {
		type = petType,
		modelName = options.modelName,
		rarity = options.rarity,
		category = options.category,
		abilityId = abilityId,
		effectId = options.effectId or abilityId or "NoOp",
		activeAbilityId = options.activeAbilityId,
		combatEffect = options.combatEffect,
		effectParams = options.effectParams,
		statModifiers = options.statModifiers,
		iconId = options.iconId,
	}
end

-- The Pet type is supplied once. Model name, ability identity and runtime effect
-- are separate only when their actual values differ.
local definitions: { PetDefinition } = {
	pet("Titan", {
		modelName = "Octopus",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),

	pet("Hydra", {
		modelName = "Hydra",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.ConditionalEffect,
		abilityId = "LastStand",
	}),

	pet("ThunderHammer", {
		modelName = "Yeti",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "LauncherBoost",
	}),

	pet("Medusa", {
		modelName = "Snake",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.DamageOverTime,
		abilityId = "Poison",
	}),

	pet("IceCrystal", {
		modelName = "Penguin",
		rarity = PetsConfig.Rarities.Legendary,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "PetBaseBoost",
	}),

	pet("GhostFlame", {
		modelName = "Phoenix",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.DamageOverTime,
		abilityId = "Burn",
		statModifiers = { Add = { baseDamage = 50 } },
	}),

	pet("Poison", {
		modelName = "Caterpillar",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "Lifesteal",
		statModifiers = { Add = { baseDamage = 25 } },
	}),

	pet("HealthCore", {
		modelName = "Pig",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "MaxHPBoost",
	}),

	pet("PowerCore", {
		modelName = "Panda",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "DamageBoost",
	}),

	pet("Shield", {
		modelName = "Elephant",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.UtilityAreaEffect,
		abilityId = "AbsorbShield",
	}),

	pet("BrainBoost", {
		modelName = "Monkey",
		rarity = PetsConfig.Rarities.Common,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "ExpBonus",
	}),

	pet("TurboModule", {
		modelName = "Bunny",
		rarity = PetsConfig.Rarities.Common,
		category = PetsConfig.Categories.PassiveStatModifier,
		abilityId = "MoveSpeedBoost",
	}),

	pet("LaunchBooster", {
		modelName = "Bee",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),

	pet("Dragon", {
		modelName = "Dragon",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.ConditionalEffect,
		abilityId = "FullForce",
	}),

	pet("QuickReload", {
		modelName = "Dog",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),

	pet("ThornArmor", {
		modelName = "Pufferfish",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),

	pet("RegenBooster", {
		modelName = "Fish",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.RegenerationHealing,
		abilityId = "Regeneration",
	}),

	pet("ShadowCloak", {
		modelName = "Unicorn",
		rarity = PetsConfig.Rarities.Legendary,
		category = PetsConfig.Categories.ConditionalEffect,
		abilityId = "IdleStealth",
		effectParams = { idleSeconds = 3 },
	}),
}

PetsConfig.Definitions = {}
for _, definition in ipairs(definitions) do
	PetsConfig.Definitions[definition.type] = definition
end

function PetsConfig.GetMaxLevelForRarity(_rarity: string): number
	return PetsConfig.MaxLevel
end

function PetsConfig.GetById(definitionId: string): PetDefinition?
	return PetsConfig.Definitions[definitionId]
end

function PetsConfig.GetAllIds(): { string }
	local ids = {}
	for id in pairs(PetsConfig.Definitions) do table.insert(ids, id) end
	table.sort(ids)
	return ids
end

function PetsConfig.IsValidEquippedSlot(slot: any): boolean
	local n = tonumber(slot)
	return n ~= nil and n % 1 == 0 and n >= 1 and n <= PetsConfig.EquippedSlotCount
end

function PetsConfig.IsValidSlot(slotType: string): boolean
	return PetsConfig.IsValidEquippedSlot(slotType) or PetsConfig.SlotTypes[slotType] ~= nil
end

return PetsConfig
