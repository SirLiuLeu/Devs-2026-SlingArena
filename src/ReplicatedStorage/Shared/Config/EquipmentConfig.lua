--!strict

local EquipmentConfig = {}

export type StatModifiers = {
	Add: { [string]: number }?,
	Multiply: { [string]: number }?,
}

export type EquipmentDefinition = {
	id: string,
	name: string,
	slotType: string,
	category: string,
	rarity: string,
	effectId: string?,
	statModifiers: StatModifiers?,
	metadata: { [string]: any }?,
	iconId: string?,
	modelPath: string?,
}

EquipmentConfig.SlotTypes = {
	Core = "Core",
	Module = "Module",
	Charm = "Charm",
}

EquipmentConfig.Rarities = {
	Common = "Common",
	Rare = "Rare",
	Epic = "Epic",
}

EquipmentConfig.Definitions = {
	training_core = {
		id = "training_core",
		name = "Training Core",
		slotType = EquipmentConfig.SlotTypes.Core,
		category = "Core",
		rarity = EquipmentConfig.Rarities.Common,
		effectId = "NoOp",
		statModifiers = { Add = { maxHP = 100 }, Multiply = {} },
		metadata = { phase = "Phase1Placeholder" },
		iconId = "rbxassetid://0",
		modelPath = "",
	},
	damage_module = {
		id = "damage_module",
		name = "Damage Module",
		slotType = EquipmentConfig.SlotTypes.Module,
		category = "Module",
		rarity = EquipmentConfig.Rarities.Common,
		effectId = "NoOp",
		statModifiers = { Add = { baseDamage = 50 }, Multiply = { damageMultiplier = 1.05 } },
		metadata = { phase = "Phase1Placeholder" },
		iconId = "rbxassetid://0",
		modelPath = "",
	},
	swift_charm = {
		id = "swift_charm",
		name = "Swift Charm",
		slotType = EquipmentConfig.SlotTypes.Charm,
		category = "Charm",
		rarity = EquipmentConfig.Rarities.Rare,
		effectId = "NoOp",
		statModifiers = { Add = {}, Multiply = { moveSpeed = 1.1 } },
		metadata = { phase = "Phase1Placeholder" },
		iconId = "rbxassetid://0",
		modelPath = "",
	},
}

function EquipmentConfig.GetById(definitionId: string): EquipmentDefinition?
	return EquipmentConfig.Definitions[definitionId]
end

function EquipmentConfig.IsValidSlot(slotType: string): boolean
	for _, configuredSlot in pairs(EquipmentConfig.SlotTypes) do
		if configuredSlot == slotType then
			return true
		end
	end
	return false
end

return EquipmentConfig
