--!strict

-- [ITEM_DATA_GUIDE]
-- 1) Add each item as a table object in ItemConfig.Items.
-- 2) id must be unique string (data object key for save/load).
-- 3) type must be one of: consumable | buff | currency.
-- 4) icon should point to an existing asset path/id used by UI.
-- 5) stackable controls inventory stacking behavior.

local ItemConfig = {}

ItemConfig.Items = {
	{
		id = "hp_potion",
		name = "HP Potion",
		type = "consumable",
		effect = "Restores HP over 5 seconds; interrupted when damaged.",
		icon = "rbxassetid://10000001",
		stackable = true,
	},
	{
		id = "exp_buff_x2",
		name = "x2 EXP Buff",
		type = "buff",
		effect = "Doubles EXP gain for a limited duration.",
		icon = "rbxassetid://10000002",
		stackable = true,
	},
	{
		id = "gacha_ticket",
		name = "Gacha Ticket",
		type = "currency",
		effect = "Used to roll random sling and item rewards.",
		icon = "rbxassetid://10000003",
		stackable = true,
	},
	{
		id = "shield_tonic",
		name = "Shield Tonic",
		type = "consumable",
		effect = "Adds temporary shield HP for one encounter.",
		icon = "rbxassetid://10000004",
		stackable = true,
	},
	{
		id = "regen_boost",
		name = "Regen Boost",
		type = "buff",
		effect = "Increases passive regen rate for 30 seconds.",
		icon = "rbxassetid://10000005",
		stackable = true,
	},
}

local byId = {}
for _, item in ipairs(ItemConfig.Items) do
	byId[item.id] = item
end

function ItemConfig.GetById(id: string)
	return byId[id]
end

function ItemConfig.GetAllIds(): { string }
	local result = {}
	for _, item in ipairs(ItemConfig.Items) do
		table.insert(result, item.id)
	end
	return result
end

return ItemConfig
