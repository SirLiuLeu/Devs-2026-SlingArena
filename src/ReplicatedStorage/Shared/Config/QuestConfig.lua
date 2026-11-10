--!strict

local QuestConfig = {
	DailyQuestChain = {
		MaxDailySteps = 5,
		SkipCooldownSeconds = 90,
		ResetUtcOffsetHours = 7, -- Vietnam local midnight (UTC+7)
		Steps = {
			{
				Reward = { Diamonds = 5 },
				QuestPool = {
					{ Id = "DQ1_Online_5", Type = "OnlineTime", MetricKey = "OnlineTimeSeconds", Target = 300, Desc = "Online trong 5 phút" },
					{ Id = "DQ1_CommonFood_10", Type = "CollectFoodRarity", MetricKey = "Food_Common", Rarity = "Common", Target = 10, Desc = "Thu thập 10 Common Food" },
					{ Id = "DQ1_Launch_5", Type = "LaunchCount", MetricKey = "LaunchCount", Target = 5, Desc = "Thực hiện 5 lần Launch" },
				},
			},
			{
				Reward = { Diamonds = 8 },
				QuestPool = {
					{ Id = "DQ2_Online_10", Type = "OnlineTime", MetricKey = "OnlineTimeSeconds", Target = 600, Desc = "Online thêm 10 phút" },
					{ Id = "DQ2_CommonFood_25", Type = "CollectFoodRarity", MetricKey = "Food_Common", Rarity = "Common", Target = 25, Desc = "Thu thập 25 Common Food" },
					{ Id = "DQ2_Damage_5K", Type = "DealDamage", MetricKey = "DamageDealtToPlayers", Target = 5000, Desc = "Gây 5.000 sát thương lên người chơi khác" },
				},
			},
			{
				Reward = { Diamonds = 12 },
				QuestPool = {
					{ Id = "DQ3_UncommonFood_5", Type = "CollectFoodRarity", MetricKey = "Food_Uncommon", Rarity = "Uncommon", Target = 5, Desc = "Thu thập 5 Uncommon Food" },
					{ Id = "DQ3_Damage_15K", Type = "DealDamage", MetricKey = "DamageDealtToPlayers", Target = 15000, Desc = "Gây 15.000 sát thương lên người chơi khác" },
					{ Id = "DQ3_Kill_1", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 1, Desc = "Hạ gục 1 người chơi" },
				},
			},
			{
				Reward = { Diamonds = 18 },
				QuestPool = {
					{ Id = "DQ4_Damage_30K", Type = "DealDamage", MetricKey = "DamageDealtToPlayers", Target = 30000, Desc = "Gây 30.000 sát thương lên người chơi khác" },
					{ Id = "DQ4_Round_1", Type = "CompleteRounds", MetricKey = "CompletedRounds", Target = 1, Desc = "Hoàn thành 1 round" },
					{ Id = "DQ4_EpicFood_1", Type = "CollectFoodRarity", MetricKey = "Food_Epic", Rarity = "Epic", Target = 1, Desc = "Thu thập 1 Epic Food" },
				},
			},
			{
				Reward = { Diamonds = 25 },
				QuestPool = {
					{ Id = "DQ5_Damage_50K", Type = "DealDamage", MetricKey = "DamageDealtToPlayers", Target = 50000, Desc = "Gây 50.000 sát thương lên người chơi khác" },
					{ Id = "DQ5_Kill_3", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 3, Desc = "Hạ gục 3 người chơi" },
					{ Id = "DQ5_LegendaryFood_1", Type = "CollectFoodRarity", MetricKey = "Food_Legendary", Rarity = "Legendary", Target = 1, Desc = "Thu thập 1 Legendary Food" },
				},
			},
		},
	},
}

return QuestConfig
