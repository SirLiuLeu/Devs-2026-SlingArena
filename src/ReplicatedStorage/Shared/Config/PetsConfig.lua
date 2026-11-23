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

export type PassiveAbility = {
	type: string,
	percent: number?,
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
	activeAbilityId: string?,
	effectId: string?,
	combatEffect: CombatEffect?,
	passiveAbility: PassiveAbility?,
	statModifiers: StatModifiers?,
	metadata: { [string]: any }?,
	iconId: string?,
	script: string,
}

PetsConfig.EquippedSlotCount = 3
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

local PET_SCRIPTS = {
	PlasmaCannon = "Titan: tăng trọng lượng, hitbox, lực knockback gây ra và giảm knockback nhận vào; đồng thời tăng kích thước Launcher theo cấp người chơi.",
	Hydra = "Last Stand: tăng sát thương va chạm khi HP giảm xuống dưới 80%; đạt mức tối đa khi HP còn 20% hoặc thấp hơn.",
	ThunderHammer = "Tăng 10% các chỉ số cốt lõi của Launcher, không nhân các chỉ số Pet.",
	Medusa = "Va chạm áp dụng Poison lên người chơi hoặc thức ăn; không kèm hiệu ứng làm chậm.",
	IceCrystal = "Nhân đôi phần HP và sát thương cơ bản đến từ rarity và level của các Pet đang trang bị.",
	GhostFlame = "Va chạm áp dụng Burn lên người chơi hoặc thức ăn; đồng thời tăng 50 sát thương cơ bản.",
	Poison = "Lifesteal: hồi 2% sát thương thực tế gây lên người chơi và 1% sát thương gây lên thức ăn; đồng thời tăng 25 sát thương cơ bản.",
	HealthCore = "Tăng phần trăm HP tối đa cuối cùng của Launcher.",
	PowerCore = "Tăng phần trăm sát thương cơ bản cuối cùng của Launcher.",
	Shield = "Hấp thụ tối đa 5.000 sát thương trong mỗi chu kỳ 10 giây; không hấp thụ sát thương Lava hoặc SafeZone.",
	BrainBoost = "Tăng lượng EXP nhận được.",
	TurboModule = "Tăng phần trăm tốc độ di chuyển.",
	LaunchBooster = "Tăng tốc độ phóng tối đa của Launcher.",
	Dragon = "Full Force: tăng sát thương khi HP cao; bonus đạt tối đa khi HP đầy.",
	QuickReload = "Giảm thời gian hồi chiêu phóng.",
	ThornArmor = "Phản lại một phần sát thương nhận vào kẻ tấn công.",
	RegenBooster = "Hồi 10 HP mỗi giây và tăng lượng hồi phục nhận từ các nguồn khác.",
	ShadowCloak = "Tàng hình sau khi đứng yên đủ lâu; tự hiện hình khi hành động.",
}

local function pet(petId: string, name: string, displayName: string, rarity: string, category: string, abilityId: string?, combatEffect: CombatEffect?, passiveAbility: PassiveAbility?, statModifiers: StatModifiers?, activeAbilityId: string?): PetDefinition
	return {
		PetId = petId,
		Name = name,
		DisplayName = displayName,
		slotType = PetsConfig.SlotTypes.Universal,
		category = category,
		rarity = rarity,
		abilityId = abilityId,
		activeAbilityId = activeAbilityId,
		effectId = abilityId or "NoOp",
		combatEffect = combatEffect,
		passiveAbility = passiveAbility,
		statModifiers = statModifiers or { Add = {}, Multiply = {} },
		metadata = { inventoryCapacityCost = 1 },
		iconId = "rbxassetid://0",
		script = PET_SCRIPTS[petId] or "Chưa có mô tả Pet.",
	}
end

PetsConfig.Definitions = {
	-- Titan / conditional damage
	PlasmaCannon = pet("PlasmaCannon", "Octopus", "Octopus", PetsConfig.Rarities.Epic, PetsConfig.Categories.PassiveStatModifier, "Titan",
		nil, { type = "Titan" }, { Add = {}, Multiply = {} }),

	Hydra = pet("Hydra", "Hydra", "Hydra", PetsConfig.Rarities.Epic, PetsConfig.Categories.ConditionalEffect, "LastStand",
		nil, { type = "LastStand" }, { Add = {}, Multiply = {} }),

	-- Launcher-wide and status abilities
	ThunderHammer = pet("ThunderHammer", "Yeti", "Yeti", PetsConfig.Rarities.Epic, PetsConfig.Categories.PassiveStatModifier, "LauncherBoost",
		nil, { type = "LauncherBoost" }, { Add = {}, Multiply = {} }),

	Medusa = pet("Medusa", "Snake", "Snake", PetsConfig.Rarities.Rare, PetsConfig.Categories.DamageOverTime, "Poison",
		nil, nil, { Add = {}, Multiply = {} }),

	IceCrystal = pet("IceCrystal", "Penguin", "Penguin", PetsConfig.Rarities.Legendary, PetsConfig.Categories.PassiveStatModifier, "PetBaseBoost",
		nil, { type = "PetBaseBoost" }, { Add = {}, Multiply = {} }),

	-- Damage over time and sustain
	GhostFlame = pet("GhostFlame", "Phoenix", "Phoenix", PetsConfig.Rarities.Rare, PetsConfig.Categories.DamageOverTime, "Burn",
		nil, nil, { Add = { baseDamage = 50 }, Multiply = {} }),

	Poison = pet("Poison", "Caterpillar", "Caterpillar", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "Lifesteal",
		nil, { type = "Lifesteal" }, { Add = { baseDamage = 25 }, Multiply = {} }),

	HealthCore = pet("HealthCore", "Pig", "Pig", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "MaxHPBoost",
		nil, { type = "MaxHPBoost" }, { Add = {}, Multiply = {} }),

	PowerCore = pet("PowerCore", "Panda", "Panda", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "DamageBoost",
		nil, { type = "DamageBoost" }, { Add = {}, Multiply = {} }),

	Shield = pet("Shield", "Elephant", "Elephant", PetsConfig.Rarities.Rare, PetsConfig.Categories.UtilityAreaEffect, "AbsorbShield",
		nil, { type = "AbsorbShield" }, { Add = {}, Multiply = {} }),

	BrainBoost = pet("BrainBoost", "Monkey", "Monkey", PetsConfig.Rarities.Common, PetsConfig.Categories.PassiveStatModifier, "ExpBonus",
		nil, { type = "ExpBonus" }, { Add = { expBonus = 0.3 }, Multiply = {} }),

	TurboModule = pet("TurboModule", "Bunny", "Bunny", PetsConfig.Rarities.Common, PetsConfig.Categories.PassiveStatModifier, "MoveSpeedBoost",
		nil, { type = "MoveSpeedBoost" }, { Add = {}, Multiply = {} }),

	LaunchBooster = pet("LaunchBooster", "Bee", "Bee", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "LaunchBooster",
		nil, { type = "LaunchBooster" }, { Add = {}, Multiply = {} }),

	Dragon = pet("Dragon", "Dragon", "Dragon", PetsConfig.Rarities.Epic, PetsConfig.Categories.ConditionalEffect, "FullForce",
		nil, { type = "FullForce" }, { Add = {}, Multiply = {} }),

	QuickReload = pet("QuickReload", "Dog", "Dog", PetsConfig.Rarities.Rare, PetsConfig.Categories.PassiveStatModifier, "QuickReload",
		nil, { type = "QuickReload" }, { Add = { launchCooldown = -1 }, Multiply = {} }),

	ThornArmor = pet("ThornArmor", "Pufferfish", "Pufferfish", PetsConfig.Rarities.Epic, PetsConfig.Categories.PassiveStatModifier, "ThornArmor",
		nil, { type = "ReflectDamage", percent = 0.2, params = {} }, { Add = { reflectDamage = 0.2 }, Multiply = {} }),

	RegenBooster = pet("RegenBooster", "Fish", "Fish", PetsConfig.Rarities.Rare, PetsConfig.Categories.RegenerationHealing, "Regeneration",
		nil, { type = "Regeneration", params = { tickInterval = 1 } }, { Add = {}, Multiply = {} }),

	ShadowCloak = pet("ShadowCloak", "Unicorn", "Unicorn", PetsConfig.Rarities.Legendary, PetsConfig.Categories.ConditionalEffect, "IdleStealth",
		nil, { type = "IdleStealth", params = { idleSeconds = 3, revealOn = { "Launch", "Movement", "Knockback" } } },
		{ Add = {}, Multiply = {} }),
}

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
