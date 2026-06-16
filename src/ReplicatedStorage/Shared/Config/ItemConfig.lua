--!strict

local ItemConfig = {}

export type ItemEffect = {
	flagName: string,
	flagParams: { [string]: any },
}

export type ItemDefinition = {
	id: string,
	name: string,
	icon: string,
	useCooldown: number?,
	effect: ItemEffect?,
}

ItemConfig.Items = {
	{
		id = "hp_potion",
		name = "HP Potion",
		icon = "rbxassetid://138146402871393",
		useCooldown = 5,
		effect = {
			flagName = "HPRecovering",
			flagParams = {
				Duration = 5,
				TickInterval = 1,
				HealPerTick = 100,
			},
		},
	},
	{
		id = "exp_buff_x2",
		name = "x2 EXP Buff",
		icon = "rbxassetid://16112286685",
		useCooldown = 1,
		effect = {
			flagName = "EXPBoosted",
			flagParams = { Duration = 300, ExpBonusPercent = 100 },
		},
	},
	{
		id = "gacha_ticket",
		name = "Gacha Ticket",
		icon = "rbxassetid://82067391881102",
	},
	{
		id = "shield_tonic",
		name = "Shield Tonic",
		icon = "rbxassetid://10000004",
	},
	{
		id = "regen_boost",
		name = "Regen Boost",
		icon = "rbxassetid://10000005",
	},
} :: { ItemDefinition }

local byId = {} :: { [string]: ItemDefinition }
for _, item in ipairs(ItemConfig.Items) do
	byId[item.id] = item
end

function ItemConfig.GetById(id: string): ItemDefinition?
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
