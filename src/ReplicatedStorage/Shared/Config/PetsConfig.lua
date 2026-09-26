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
	cannotPetrifyPetIds: { [string]: boolean }?,
}

export type PassiveAbility = {
	type: string,
	percent: number?,
	value: number?,
	params: { [string]: any }?,
}

export type PetDefinition = {
	PetId: string,
	Name: string,
	DisplayName: string,
	slotType: string,
	category: string,
	rarity: string,
	abilityId: string?,
	effectId: string?,
	combatEffect: CombatEffect?,
	passiveAbility: PassiveAbility?,
	statModifiers: StatModifiers?,
	metadata: { [string]: any }?,
	iconId: string?,
}

PetsConfig.EquippedSlotCount = 3
PetsConfig.SlotTypes = { Universal = "Universal", Core = "Core", Module = "Module", Charm = "Charm" }
PetsConfig.Rarities = { Common = "Common", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }
PetsConfig.RarityMaxLevel = {
	[PetsConfig.Rarities.Common] = 5,
	[PetsConfig.Rarities.Rare] = 10,
	[PetsConfig.Rarities.Epic] = 15,
	[PetsConfig.Rarities.Legendary] = 20,
}
PetsConfig.Categories = {
	ActiveAttack = "Active Attack",
	CrowdControl = "Crowd Control",
	DamageOverTime = "Damage Over Time",
	PassiveStatModifier = "Passive Stat Modifier",
	RegenerationHealing = "Regeneration / Healing",
	ConditionalEffect = "Conditional Effect",
	UtilityAreaEffect = "Utility / Area Effect",
}

local function pet(petId: string, name: string, displayName: string, rarity: string, category: string, abilityId: string?, combatEffect: CombatEffect?, passiveAbility: PassiveAbility?, statModifiers: StatModifiers?): PetDefinition
	return {
		PetId = petId,
		Name = name,
		DisplayName = displayName,
		slotType = PetsConfig.SlotTypes.Universal,
		category = category,
		rarity = rarity,
		abilityId = abilityId,
		effectId = abilityId or "NoOp",
		combatEffect = combatEffect,
		passiveAbility = passiveAbility,
		statModifiers = statModifiers or { Add = {}, Multiply = {} },
		metadata = { inventoryCapacityCost = 1 },
		iconId = "rbxassetid://0",
	}
end

PetsConfig.Definitions = {

    -- Active Attack
    PlasmaCannon = pet("PlasmaCannon", "Octopus", "Octopus", PetsConfig.Rarities.Epic, PetsConfig.Categories.ActiveAttack, "NoOp", nil,
        { type = "ActiveAttack", value = 1000, params = { cooldown = 10, diagnostic = "Plasma Cannon active attack is not yet implemented" } },
        { Add = {}, Multiply = {} }),

    SlowBlaster = pet("SlowBlaster", "Dragon", "Dragon", PetsConfig.Rarities.Rare, PetsConfig.Categories.ActiveAttack, "Slow",
        { collisionFlag = "Slow", collisionExtraDuration = 3 },
        { type = "ProjectileSlow", params = { cooldown = 3, diagnostic = "Slow Blaster projectile is not yet implemented; collision slow uses the shared Slow effect" } },
        { Add = {}, Multiply = {} }),

    -- Crowd Control
    ThunderHammer = pet("ThunderHammer", "Yeti", "Yeti", PetsConfig.Rarities.Epic, PetsConfig.Categories.CrowdControl, "Stun",
        { collisionFlag = "Stun", collisionExtraDuration = 1.25 }, nil,
        { Add = {}, Multiply = { damageMultiplier = 1.05 } }),

    Medusa = pet("Medusa", "Snake", "Snake", PetsConfig.Rarities.Legendary, PetsConfig.Categories.CrowdControl, "Petrify",
        { collisionFlag = "Petrify", collisionExtraDuration = 5, cannotPetrifyPetIds = { GhostFlame = true } }, nil,
        { Add = {}, Multiply = {} }),

    IceCrystal = pet("IceCrystal", "Penguin", "Penguin", PetsConfig.Rarities.Rare, PetsConfig.Categories.CrowdControl, "Slow",
        { collisionFlag = "Slow", collisionExtraDuration = 3 },
        { type = "Slow", params = { diagnostic = "Ice Crystal applies the shared Slow flag." } },
        { Add = {}, Multiply = {} }),

    -- Damage Over Time
    GhostFlame = pet("GhostFlame", "Phoenix", "Phoenix", PetsConfig.Rarities.Epic, PetsConfig.Categories.DamageOverTime, "Burn",
        { dotFlag = "Burn" }, nil,
        { Add = { baseDamage = 50 }, Multiply = {} }),

    Poison = pet("Poison", "Caterpillar", "Caterpillar", PetsConfig.Rarities.Rare, PetsConfig.Categories.DamageOverTime, "Poison",
        { dotFlag = "Poison" }, nil,
        { Add = { baseDamage = 25 }, Multiply = {} }),

    -- Passive Stat Modifier
    HealthCore = pet("HealthCore", "Cow", "Cow", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = { maxHP = 5000 }, Multiply = {} }),

    PowerCore = pet("PowerCore", "Elephant", "Elephant", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = { baseDamage = 500 }, Multiply = {} }),

    Shield = pet("Shield", "Panda", "Panda", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "Shield",
        nil, { type = "DamageReduction", percent = 0.2 }, { Add = {}, Multiply = {} }),

    BrainBoost = pet("BrainBoost", "Monkey", "Monkey", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "ExpBonus",
        nil, { type = "ExpBonus", value = 0.3, params = { expBonus = 0.3 } },
        { Add = { expBonus = 0.3 }, Multiply = {} }),

    TurboModule = pet("TurboModule", "Bunny", "Bunny", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = { moveSpeed = 10 }, Multiply = {} }),

    LaunchBooster = pet("LaunchBooster", "Bee", "Bee", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = {}, Multiply = { launchSpeed = 1.2 } }),

    TitanCore = pet("TitanCore", "Hydra", "Hydra", PetsConfig.Rarities.Epic, PetsConfig.Categories.PassiveStatModifier, "Titan",
        nil, { type = "Titan", params = { sizeMultiplier = 1.2, incomingKnockbackMultiplier = 0.75, outgoingKnockbackMultiplier = 1.25 } },
        { Add = {}, Multiply = {} }),

    QuickReload = pet("QuickReload", "Dog", "Dog", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = { launchCooldown = -1 }, Multiply = {} }),

    ThornArmor = pet("ThornArmor", "Pig", "Pig", PetsConfig.Rarities.Epic, PetsConfig.Categories.PassiveStatModifier, "NoOp",
        nil, { type = "ReflectDamage", percent = 0.2, params = { diagnostic = "Thorn Armor damage reflection is not yet wired into DamagePipelineService" } },
        { Add = { reflectDamage = 0.2 }, Multiply = {} }),

    -- Regeneration / Healing
    RegenBooster = pet("RegenBooster", "Fish", "Fish", PetsConfig.Rarities.Rare, PetsConfig.Categories.RegenerationHealing, "Regeneration",
        nil, { type = "Regeneration", value = 500, params = { tickInterval = 5 } },
        { Add = {}, Multiply = {} }),

    -- Conditional Effect
    ShadowCloak = pet("ShadowCloak", "Unicorn", "Unicorn", PetsConfig.Rarities.Epic, PetsConfig.Categories.ConditionalEffect, "IdleStealth",
        nil, { type = "IdleStealth", params = { idleSeconds = 3, revealOn = { "Launch", "Movement", "Knockback" } } },
        { Add = {}, Multiply = {} }),

}

function PetsConfig.GetMaxLevelForRarity(rarity: string): number
	return PetsConfig.RarityMaxLevel[rarity] or PetsConfig.RarityMaxLevel[PetsConfig.Rarities.Common]
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
