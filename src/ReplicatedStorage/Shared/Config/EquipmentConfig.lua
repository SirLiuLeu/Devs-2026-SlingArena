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
	training_core = equipment("training_core", "Training Core", EquipmentConfig.Rarities.Common, EquipmentConfig.Categories.PassiveStatModifier, nil, nil, nil, { Add = { maxHP = 100 }, Multiply = {} }),
	damage_module = equipment("damage_module", "Damage Module", EquipmentConfig.Rarities.Common, EquipmentConfig.Categories.PassiveStatModifier, nil, nil, nil, { Add = { baseDamage = 50 }, Multiply = { damageMultiplier = 1.05 } }),
	swift_charm = equipment("swift_charm", "Swift Charm", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.PassiveStatModifier, nil, nil, nil, { Add = {}, Multiply = { moveSpeed = 1.1 } }),
	Poison = equipment("Poison", "Poison", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.DamageOverTime, "Poison", { dotFlag = "Poison" }, nil, { Add = { baseDamage = 25 }, Multiply = {} }),
	GhostFlame = equipment("GhostFlame", "Ghost Flame", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.DamageOverTime, "Fire", { dotFlag = "Burn" }, nil, { Add = { baseDamage = 50 }, Multiply = {} }),
	PowerCore = equipment("PowerCore", "Power Core", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.RegenerationHealing, "Slow", { collisionFlag = "Slow", collisionExtraDuration = 2 }, { type = "HealOnLaunch", percent = 0.05 }, { Add = { maxHP = 100 }, Multiply = {} }),
	BrainBoost = equipment("BrainBoost", "Brain Boost", EquipmentConfig.Rarities.Rare, EquipmentConfig.Categories.ConditionalEffect, "ExpBonus", nil, { type = "ExpBonus", value = 0.5, params = { expBonus = 0.5 } }, { Add = { expBonus = 0.5 }, Multiply = {} }),
	ThunderHammer = equipment("ThunderHammer", "Thunder Hammer", EquipmentConfig.Rarities.Epic, EquipmentConfig.Categories.CrowdControl, "Stun", { collisionFlag = "Stun", collisionExtraDuration = 1.25 }, { type = "ExpBoost", params = { expBonus = 0.1 } }, { Add = {}, Multiply = { damageMultiplier = 1.05 } }),
	Medusa = equipment("Medusa", "Medusa", EquipmentConfig.Rarities.Legendary, EquipmentConfig.Categories.CrowdControl, "Petrify", { collisionFlag = "Petrify", collisionExtraDuration = 1.5, cannotPetrifyEquipmentIds = { GhostFlame = true } }, nil, { Add = {}, Multiply = {} }),
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
