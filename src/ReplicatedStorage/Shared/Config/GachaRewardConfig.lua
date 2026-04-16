--!strict

local GachaRewardConfig = {}

export type RewardEntry = {
	id: string,
	type: string,
	weight: number,
	icon: string,
	name: string,
	teamBonus: {
		TeamRed: number,
		TeamBlue: number,
	},
}

GachaRewardConfig.Rewards = {
	{
		id = "hp_potion",
		type = "Consumable",
		weight = 25,
		icon = "rbxassetid://0",
		name = "HP Potion",
		teamBonus = { TeamRed = 0.05, TeamBlue = 0.05 },
	},
	{
		id = "sling_reward",
		type = "Sling",
		weight = 10,
		icon = "rbxassetid://0",
		name = "Sling",
		teamBonus = { TeamRed = 0.02, TeamBlue = 0.02 },
	},
	{
		id = "exp_buff",
		type = "Buff",
		weight = 16,
		icon = "rbxassetid://0",
		name = "EXP Buff",
		teamBonus = { TeamRed = 0.08, TeamBlue = 0.08 },
	},
	{
		id = "exp_flat",
		type = "Progression",
		weight = 20,
		icon = "rbxassetid://0",
		name = "EXP",
		teamBonus = { TeamRed = 0.06, TeamBlue = 0.06 },
	},
	{
		id = "diamond",
		type = "Currency",
		weight = 14,
		icon = "rbxassetid://0",
		name = "Dinamond",
		teamBonus = { TeamRed = 0.04, TeamBlue = 0.04 },
	},
	{
		id = "team_rage",
		type = "TeamBuff",
		weight = 15,
		icon = "rbxassetid://0",
		name = "Team Rage",
		teamBonus = { TeamRed = 0.1, TeamBlue = 0.1 },
	},
}

function GachaRewardConfig.GetRewards(): { RewardEntry }
	return table.clone(GachaRewardConfig.Rewards)
end

return GachaRewardConfig
