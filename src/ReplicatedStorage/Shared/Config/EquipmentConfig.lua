--!strict

local EquipmentConfig = {}

export type StatModifiers = {
	Add: { [string]: number }?,
	Multiply: { [string]: number }?,
}

export type CombatEffect = {
	collisionFlag: string?,
	collisionExtraDuration: number?,
	dotFlag: string?,
	cannotPetrifyEquipmentIds: { [string]: boolean }?,
}

export type PassiveAbility = {
	type: string,
	percent: number?,
	value: number?,
	params: { [string]: any }?,
}

export type EquipmentDefinition = {
	id: string,
	EquipmentId: string,
	name: string,
	Name: string,
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
	modelName: string,
	modelPath: string,
}

EquipmentConfig.EquippedSlotCount = 3
EquipmentConfig.SlotTypes = { Universal = "Universal", Core = "Core", Module = "Module", Charm = "Charm" }
EquipmentConfig.Rarities = { Common = "Common", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }
EquipmentConfig.RarityMaxLevel = {
	[EquipmentConfig.Rarities.Common] = 5,
	[EquipmentConfig.Rarities.Rare] = 10,
	[EquipmentConfig.Rarities.Epic] = 15,
	[EquipmentConfig.Rarities.Legendary] = 20,
}
EquipmentConfig.Categories = {
	ActiveAttack = "Active Attack",
	CrowdControl = "Crowd Control",
	DamageOverTime = "Damage Over Time",
	PassiveStatModifier = "Passive Stat Modifier",
	RegenerationHealing = "Regeneration / Healing",
	ConditionalEffect = "Conditional Effect",
	UtilityAreaEffect = "Utility / Area Effect",
}

local function equipment(id: string, name: string, rarity: string, category: string, abilityId: string?, combatEffect: CombatEffect?, passiveAbility: PassiveAbility?, statModifiers: StatModifiers?): EquipmentDefinition
	return {
		id = id,
		EquipmentId = id,
		name = name,
		Name = name,
		slotType = EquipmentConfig.SlotTypes.Universal,
		category = category,
		rarity = rarity,
		abilityId = abilityId,
		effectId = abilityId or "NoOp",
		combatEffect = combatEffect,
		passiveAbility = passiveAbility,
		statModifiers = statModifiers or { Add = {}, Multiply = {} },
		metadata = { inventoryCapacityCost = 1 },
		iconId = "rbxassetid://0",
		modelName = id,
		modelPath = "ReplicatedStorage.Assets.Equipment." .. id,
	}
end

EquipmentConfig.Definitions = {

    -- Active Attack
    PlasmaCannon = equipment("PlasmaCannon", "Plasma Cannon", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.ActiveAttack, "NoOp", nil,
        { type = "ActiveAttack", value = 1000, params = { cooldown = 10, diagnostic = "Plasma Cannon active attack is not yet implemented" } },
        { Add = {}, Multiply = {} }),

    SlowBlaster = equipment("SlowBlaster", "Slow Blaster", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.ActiveAttack, "Slow",
        { collisionFlag = "Slow", collisionExtraDuration = 3 },
        { type = "ProjectileSlow", params = { cooldown = 3, diagnostic = "Slow Blaster projectile is not yet implemented; collision slow uses the shared Slow effect" } },
        { Add = {}, Multiply = {} }),

    -- Crowd Control
    ThunderHammer = equipment("ThunderHammer", "Thunder Hammer", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.CrowdControl, "Stun",
        { collisionFlag = "Stun", collisionExtraDuration = 1.25 }, nil,
        { Add = {}, Multiply = { damageMultiplier = 1.05 } }),

    Medusa = equipment("Medusa", "Medusa", EquipmentConfig.Rarities.Legendary, EquipmentConfig.Categories.CrowdControl, "Petrify",
        { collisionFlag = "Petrify", collisionExtraDuration = 5, cannotPetrifyEquipmentIds = { GhostFlame = true } }, nil,
        { Add = {}, Multiply = {} }),

    IceCrystal = equipment("IceCrystal", "Ice Crystal", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.CrowdControl, "Freeze",
        { collisionFlag = "Freeze", collisionExtraDuration = 3 },
        { type = "Freeze", params = { diagnostic = "Freeze flag dispatch is configured; full freeze rules depend on PlayerStateService flag support" } },
        { Add = {}, Multiply = {} }),

    -- Damage Over Time
    GhostFlame = equipment("GhostFlame", "Ghost Flame", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.DamageOverTime, "Fire",
        { dotFlag = "Burn" }, nil,
        { Add = { baseDamage = 50 }, Multiply = {} }),

    Poison = equipment("Poison", "Poison", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.DamageOverTime, "Poison",
        { dotFlag = "Poison" }, nil,
        { Add = { baseDamage = 25 }, Multiply = {} }),

    -- Passive Stat Modifier
    HealthCore = equipment("HealthCore", "Health Core", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = {}, Multiply = { maxHP = 1.3 } }),

    PowerCore = equipment("PowerCore", "Power Core", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = {}, Multiply = { baseDamage = 1.2 } }),

    Shield = equipment("Shield", "Shield", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier, "Shield",
        nil, { type = "DamageReduction", percent = 0.2 }, { Add = {}, Multiply = {} }),

    BrainBoost = equipment("BrainBoost", "Brain Boost", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier, "ExpBonus",
        nil, { type = "ExpBonus", value = 0.3, params = { expBonus = 0.3 } },
        { Add = { expBonus = 0.3 }, Multiply = {} }),

    TurboModule = equipment("TurboModule", "Turbo Module", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = {}, Multiply = { moveSpeed = 1.2 } }),

    LaunchBooster = equipment("LaunchBooster", "Launch Booster", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = {}, Multiply = { launchSpeed = 1.2 } }),

    TitanCore = equipment("TitanCore", "Titan Core", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.PassiveStatModifier, "Titan",
        nil, { type = "Titan", params = { sizeMultiplier = 1.2, incomingKnockbackMultiplier = 0.75, outgoingKnockbackMultiplier = 1.25 } },
        { Add = {}, Multiply = {} }),

    QuickReload = equipment("QuickReload", "Quick Reload", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier,
        nil, nil, nil, { Add = { launchCooldown = -1 }, Multiply = {} }),

    ThornArmor = equipment("ThornArmor", "Thorn Armor", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.PassiveStatModifier, "NoOp",
        nil, { type = "ReflectDamage", percent = 0.2, params = { diagnostic = "Thorn Armor damage reflection is not yet wired into DamagePipelineService" } },
        { Add = { reflectDamage = 0.2 }, Multiply = {} }),

    -- Regeneration / Healing
    RegenBooster = equipment("RegenBooster", "Regen Booster", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.RegenerationHealing, "Regen",
        nil, { type = "Regeneration", value = 500, params = { tickInterval = 5 } },
        { Add = {}, Multiply = {} }),

    -- Conditional Effect
    ShadowCloak = equipment("ShadowCloak", "Shadow Cloak", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.ConditionalEffect, "ShadowCloak",
        nil, { type = "IdleStealth", params = { idleSeconds = 5, revealOn = { "Launch", "Movement", "Knockback" } } },
        { Add = {}, Multiply = {} }),

    SmokeBomb = equipment("SmokeBomb", "Smoke Bomb", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.ConditionalEffect, "SmokeBomb",
        nil, { type = "SmokeOnLaunch" }, { Add = {}, Multiply = {} }),

    -- Utility / Area Effect
    MagnetCore = equipment("MagnetCore", "Magnet Core", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.UtilityAreaEffect, "Magnet",
        nil, { type = "Magnet", value = 6 }, { Add = {}, Multiply = {} }),
}

function EquipmentConfig.GetMaxLevelForRarity(rarity: string): number
	return EquipmentConfig.RarityMaxLevel[rarity] or EquipmentConfig.RarityMaxLevel[EquipmentConfig.Rarities.Common]
end

function EquipmentConfig.GetById(definitionId: string): EquipmentDefinition?
	return EquipmentConfig.Definitions[definitionId]
end

function EquipmentConfig.GetAllIds(): { string }
	local ids = {}
	for id in pairs(EquipmentConfig.Definitions) do table.insert(ids, id) end
	table.sort(ids)
	return ids
end

function EquipmentConfig.IsValidEquippedSlot(slot: any): boolean
	local n = tonumber(slot)
	return n ~= nil and n % 1 == 0 and n >= 1 and n <= EquipmentConfig.EquippedSlotCount
end

function EquipmentConfig.IsValidSlot(slotType: string): boolean
	return EquipmentConfig.IsValidEquippedSlot(slotType) or EquipmentConfig.SlotTypes[slotType] ~= nil
end

return EquipmentConfig
