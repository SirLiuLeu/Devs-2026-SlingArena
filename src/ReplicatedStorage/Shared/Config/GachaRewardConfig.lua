--!strict

local GachaRewardConfig = {}

export type RewardEntry = {
	id: string,
	type: string,
	weight: number,
	icon: string,
	name: string,
}

GachaRewardConfig.Rewards = {
	{
		id = "hp_potion",
		type = "Consumable",
		weight = 25,
		icon = "rbxassetid://0",
		name = "HP Potion",
	},
	{
		id = "sling_reward",
		type = "Sling",
		weight = 10,
		icon = "rbxassetid://0",
		name = "Sling",
	},
	{
		id = "exp_buff",
		type = "Buff",
		weight = 16,
		icon = "rbxassetid://0",
		name = "EXP Buff",
	},
	{
		id = "exp_flat",
		type = "Progression",
		weight = 20,
		icon = "rbxassetid://0",
		name = "EXP",
	},
	{
		id = "diamond",
		type = "Currency",
		weight = 14,
		icon = "rbxassetid://0",
		name = "Dinamond",
	},
	{
		id = "team_rage",
		type = "TeamBuff",
		weight = 15,
		icon = "rbxassetid://0",
		name = "Team Rage",
	},
}

function GachaRewardConfig.GetRewards(): { RewardEntry }
	return table.clone(GachaRewardConfig.Rewards)
end

return GachaRewardConfig
