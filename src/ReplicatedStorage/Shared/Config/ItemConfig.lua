--!strict

-- Item definitions are shared presentation/balance data. ItemService remains the only
-- authority that mutates quantities or applies these effects.
local ItemConfig = {}

export type ItemEffect = {
	kind: "Flag" | "Experience",
	flagName: string?,
	flagParams: { [string]: any }?,
	experienceAmount: number?,
}

export type ItemDefinition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	itemType: "Consumable" | "Currency",
	stackable: boolean,
	consumeOnUse: boolean,
	useCooldown: number?,
	effect: ItemEffect?,
}

ItemConfig.Items = {
	{
		id = "hp_potion", name = "HP Potion", description = "Restore 500 HP every 0.5 seconds for 3 seconds.", icon = "rbxassetid://138146402871393",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 3,
		effect = { kind = "Flag", flagName = "HPRecovering", flagParams = { Duration = 3, TickInterval = 0.5, HealPerTick = 500 } },
	},
	{
		id = "exp_buff_30", name = "30% EXP Buff", description = "Gain 30% more EXP for 5 minutes. Reuse refreshes duration.", icon = "rbxassetid://16112286685",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "EXPBoosted", flagParams = { Duration = 300, ExpBonusPercent = 30 } },
	},
	{
		id = "damage_buff_20", name = "20% Damage Buff", description = "Deal 20% more damage for 60 seconds. Reuse refreshes duration.", icon = "rbxassetid://0",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "DamageBoosted", flagParams = { Duration = 60, DamageBonusPercent = 20 } },
	},
	{
		id = "hp_buff_30", name = "30% HP Buff", description = "Increase maximum HP by 30% for 5 minutes. Reuse refreshes duration.", icon = "rbxassetid://0",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "HPBoosted", flagParams = { Duration = 300, MaxHPBonusPercent = 30 } },
	},
	{
		id = "exp_card_500", name = "500 EXP Card", description = "Immediately grants 500 EXP.", icon = "rbxassetid://0",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 0.25,
		effect = { kind = "Experience", experienceAmount = 500 },
	},
	{
		id = "luck_buff_clover", name = "3-Leaf Clover", description = "Increase server-side diamond-drop chance by 30% for 5 minutes. Reuse refreshes duration.", icon = "rbxassetid://0",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "LuckBoosted", flagParams = { Duration = 300, DiamondDropChanceBonusPercent = 30 } },
	},
	{ id = "gacha_ticket", name = "Gacha Ticket", description = "A ticket for the gacha.", icon = "rbxassetid://82067391881102", itemType = "Currency", stackable = true, consumeOnUse = false },
	{ id = "shield_tonic", name = "Shield Tonic", description = "Reserved consumable.", icon = "rbxassetid://10000004", itemType = "Consumable", stackable = true, consumeOnUse = false },
	{ id = "regen_boost", name = "Regen Boost", description = "Reserved consumable.", icon = "rbxassetid://10000005", itemType = "Consumable", stackable = true, consumeOnUse = false },
} :: { ItemDefinition }

local byId = {} :: { [string]: ItemDefinition }
for _, item in ipairs(ItemConfig.Items) do byId[item.id] = item end
function ItemConfig.GetById(id: string): ItemDefinition? return byId[id] end
function ItemConfig.GetAllIds(): { string }
	local result = {}
	for _, item in ipairs(ItemConfig.Items) do table.insert(result, item.id) end
	return result
end
return ItemConfig
