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
}

export type PetDefinition = {
	abilityId: string,
	modelName: string,
	rarity: string,
	category: string,
	combatEffect: CombatEffect?,
	effectParams: { [string]: any }?,
	statModifiers: StatModifiers?,
	iconId: string?,
}

type PetDefinitionOptions = {
	modelName: string,
	rarity: string,
	category: string,
	combatEffect: CombatEffect?,
	effectParams: { [string]: any }?,
	statModifiers: StatModifiers?,
	iconId: string?,
}

PetsConfig.EquippedSlotCount = 3
-- Slot names remain accepted only for migration of old EquippedPets layouts.
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

-- Legacy catalog identifiers are migrated to the owning AbilityID when profiles load.
-- These are data-compatibility aliases only; they are never valid current catalog keys.
PetsConfig.LegacyPetDefinitionIdAliases = {
	PlasmaCannon = "Titan",
	Hydra = "LastStand",
	ThunderHammer = "LauncherBoost",
	Medusa = "Poison",
	IceCrystal = "PetBaseBoost",
	GhostFlame = "Burn",
	Poison = "Lifesteal",
	HealthCore = "MaxHPBoost",
	PowerCore = "DamageBoost",
	Shield = "IronBody",
	BrainBoost = "ExpBonus",
	TurboModule = "MoveSpeedBoost",
	Dragon = "FullForce",
	RegenBooster = "Regeneration",
	ShadowCloak = "AbsorbShield",

	-- Older aliases retained from historical catalog migrations.
	ShadowCloakZ = "AbsorbShield",
	Pufferfish = "ThornArmor",
	SlowBlaster = "LastStand",
	TitanCore = "FullForce",
}

local function pet(abilityId: string, options: PetDefinitionOptions): PetDefinition
	return {
		abilityId = abilityId,
		modelName = options.modelName,
		rarity = options.rarity,
		category = options.category,
		combatEffect = options.combatEffect,
		effectParams = options.effectParams,
		statModifiers = options.statModifiers,
		iconId = options.iconId,
	}
end

-- AbilityID is the sole catalog and ownership identifier. Model names are presentation assets only.
PetsConfig.Definitions = {
	Titan = pet("Titan", {
		modelName = "Octopus",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	LastStand = pet("LastStand", {
		modelName = "Hydra",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.ConditionalEffect,
	}),
	LauncherBoost = pet("LauncherBoost", {
		modelName = "Yeti",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	Poison = pet("Poison", {
		modelName = "Snake",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.DamageOverTime,
	}),
	PetBaseBoost = pet("PetBaseBoost", {
		modelName = "Penguin",
		rarity = PetsConfig.Rarities.Legendary,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	Burn = pet("Burn", {
		modelName = "Phoenix",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.DamageOverTime,
		statModifiers = { Add = { baseDamage = 50 } },
	}),
	Lifesteal = pet("Lifesteal", {
		modelName = "Caterpillar",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
		statModifiers = { Add = { baseDamage = 25 } },
	}),
	MaxHPBoost = pet("MaxHPBoost", {
		modelName = "Pig",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	DamageBoost = pet("DamageBoost", {
		modelName = "Panda",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	IronBody = pet("IronBody", {
		modelName = "Elephant",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	AbsorbShield = pet("AbsorbShield", {
		modelName = "Unicorn",
		rarity = PetsConfig.Rarities.Legendary,
		category = PetsConfig.Categories.UtilityAreaEffect,
	}),
	ExpBonus = pet("ExpBonus", {
		modelName = "Monkey",
		rarity = PetsConfig.Rarities.Common,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	MoveSpeedBoost = pet("MoveSpeedBoost", {
		modelName = "Bunny",
		rarity = PetsConfig.Rarities.Common,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	LaunchBooster = pet("LaunchBooster", {
		modelName = "Bee",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	FullForce = pet("FullForce", {
		modelName = "Dragon",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.ConditionalEffect,
	}),
	QuickReload = pet("QuickReload", {
		modelName = "Dog",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	ThornArmor = pet("ThornArmor", {
		modelName = "Pufferfish",
		rarity = PetsConfig.Rarities.Epic,
		category = PetsConfig.Categories.PassiveStatModifier,
	}),
	Regeneration = pet("Regeneration", {
		modelName = "Fish",
		rarity = PetsConfig.Rarities.Rare,
		category = PetsConfig.Categories.RegenerationHealing,
	}),
}

function PetsConfig.GetMaxLevelForRarity(_rarity: string): number
	return PetsConfig.MaxLevel
end

function PetsConfig.GetByAbilityId(abilityId: string): PetDefinition?
	return PetsConfig.Definitions[abilityId]
end

function PetsConfig.GetAllAbilityIds(): { string }
	local abilityIds = {}
	for abilityId in pairs(PetsConfig.Definitions) do
		table.insert(abilityIds, abilityId)
	end
	table.sort(abilityIds)
	return abilityIds
end

function PetsConfig.IsValidAbilityId(abilityId: any): boolean
	return type(abilityId) == "string" and PetsConfig.Definitions[abilityId] ~= nil
end

function PetsConfig.IsValidEquippedSlot(slot: any): boolean
	local n = tonumber(slot)
	return n ~= nil and n % 1 == 0 and n >= 1 and n <= PetsConfig.EquippedSlotCount
end

function PetsConfig.IsValidSlot(slotType: string): boolean
	return PetsConfig.IsValidEquippedSlot(slotType) or PetsConfig.SlotTypes[slotType] ~= nil
end

return PetsConfig
