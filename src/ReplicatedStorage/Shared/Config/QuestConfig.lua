--!strict

local QuestConfig = {
	DailyQuestChain = {
		MaxDailySteps = 5,
		SkipCooldownSeconds = 90,
		FoodSelectionPercent = 80, -- Food collection vs. active gameplay task share
		ResetUtcOffsetHours = 7, -- Vietnam local midnight (UTC+7)
		-- Weight is relative only within the Food or gameplay category.
		-- FoodSelectionPercent controls the category split for every step.
		Steps = {
			{
				Reward = { Diamonds = 50 }, -- 10x previous reward
				QuestPool = {
					-- Food tasks account for 80% of the selection weight in every step.
					{ Id = "DQ1_CommonFood_30", Type = "CollectFoodRarity", MetricKey = "Food_Common", Rarity = "Common", Target = 30, Weight = 1, Desc = "Thu thập 30 Common Food" },
					{ Id = "DQ1_CommonRed_20", Type = "CollectFoodType", MetricKey = "FoodType_CommonRed", FoodType = "CommonRed", Target = 20, Weight = 1, Desc = "Thu thập 20 CommonRed Food" },
					{ Id = "DQ1_CommonGreen_20", Type = "CollectFoodType", MetricKey = "FoodType_CommonGreen", FoodType = "CommonGreen", Target = 20, Weight = 1, Desc = "Thu thập 20 CommonGreen Food" },
					{ Id = "DQ1_CommonBlue_20", Type = "CollectFoodType", MetricKey = "FoodType_CommonBlue", FoodType = "CommonBlue", Target = 20, Weight = 1, Desc = "Thu thập 20 CommonBlue Food" },
					{ Id = "DQ1_Kill_1", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 1, Weight = 1, Desc = "Hạ gục 1 người chơi" },
					{ Id = "DQ1_Round_1", Type = "CompleteRounds", MetricKey = "CompletedRounds", Target = 1, Weight = 1, Desc = "Hoàn thành 1 round" },
					{ Id = "DQ1_HpPotion_1", Type = "UseHpPotion", MetricKey = "HpPotionUses", Target = 1, Weight = 1, Desc = "Sử dụng 1 HP Potion" },
					{ Id = "DQ1_Bomb_1", Type = "BombPlayersDamaged", MetricKey = "BombPlayersDamaged", Target = 1, Weight = 1, Desc = "Dùng Bomb gây sát thương cho 1 người chơi" },
				},
			},
			{
				Reward = { Diamonds = 80 }, -- 10x previous reward
				QuestPool = {
					{ Id = "DQ2_CommonFood_60", Type = "CollectFoodRarity", MetricKey = "Food_Common", Rarity = "Common", Target = 60, Weight = 1, Desc = "Thu thập 60 Common Food" },
					{ Id = "DQ2_UncommonFood_12", Type = "CollectFoodRarity", MetricKey = "Food_Uncommon", Rarity = "Uncommon", Target = 12, Weight = 1, Desc = "Thu thập 12 Uncommon Food" },
					{ Id = "DQ2_CommonRed_30", Type = "CollectFoodType", MetricKey = "FoodType_CommonRed", FoodType = "CommonRed", Target = 30, Weight = 1, Desc = "Thu thập 30 CommonRed Food" },
					{ Id = "DQ2_UncommonIce_10", Type = "CollectFoodType", MetricKey = "FoodType_UncommonIce", FoodType = "UncommonIce", Target = 10, Weight = 1, Desc = "Thu thập 10 Uncommon Ice Food" },
					{ Id = "DQ2_Kill_1", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 1, Weight = 1, Desc = "Hạ gục 1 người chơi" },
					{ Id = "DQ2_Round_1", Type = "CompleteRounds", MetricKey = "CompletedRounds", Target = 1, Weight = 1, Desc = "Hoàn thành 1 round" },
					{ Id = "DQ2_HpPotion_2", Type = "UseHpPotion", MetricKey = "HpPotionUses", Target = 2, Weight = 1, Desc = "Sử dụng 2 HP Potion" },
					{ Id = "DQ2_Bomb_1", Type = "BombPlayersDamaged", MetricKey = "BombPlayersDamaged", Target = 1, Weight = 1, Desc = "Dùng Bomb gây sát thương cho 1 người chơi" },
				},
			},
			{
				Reward = { Diamonds = 120 }, -- 10x previous reward
				QuestPool = {
					{ Id = "DQ3_UncommonFood_30", Type = "CollectFoodRarity", MetricKey = "Food_Uncommon", Rarity = "Uncommon", Target = 30, Weight = 1, Desc = "Thu thập 30 Uncommon Food" },
					{ Id = "DQ3_RareFood_10", Type = "CollectFoodRarity", MetricKey = "Food_Rare", Rarity = "Rare", Target = 10, Weight = 1, Desc = "Thu thập 10 Rare Food" },
					{ Id = "DQ3_UncommonIce_18", Type = "CollectFoodType", MetricKey = "FoodType_UncommonIce", FoodType = "UncommonIce", Target = 18, Weight = 1, Desc = "Thu thập 18 Uncommon Ice Food" },
					{ Id = "DQ3_RareAmber_7", Type = "CollectFoodType", MetricKey = "FoodType_RareAmber", FoodType = "RareAmber", Target = 7, Weight = 1, Desc = "Thu thập 7 Rare Amber Food" },
					{ Id = "DQ3_Kill_2", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 2, Weight = 1, Desc = "Hạ gục 2 người chơi" },
					{ Id = "DQ3_Round_2", Type = "CompleteRounds", MetricKey = "CompletedRounds", Target = 2, Weight = 1, Desc = "Hoàn thành 2 round" },
					{ Id = "DQ3_HpPotion_2", Type = "UseHpPotion", MetricKey = "HpPotionUses", Target = 2, Weight = 1, Desc = "Sử dụng 2 HP Potion" },
					{ Id = "DQ3_Bomb_2", Type = "BombPlayersDamaged", MetricKey = "BombPlayersDamaged", Target = 2, Weight = 1, Desc = "Dùng Bomb gây sát thương cho 2 người chơi" },
				},
			},
			{
				Reward = { Diamonds = 180 }, -- 10x previous reward
				QuestPool = {
					{ Id = "DQ4_RareFood_25", Type = "CollectFoodRarity", MetricKey = "Food_Rare", Rarity = "Rare", Target = 25, Weight = 1, Desc = "Thu thập 25 Rare Food" },
					{ Id = "DQ4_EpicFood_8", Type = "CollectFoodRarity", MetricKey = "Food_Epic", Rarity = "Epic", Target = 8, Weight = 1, Desc = "Thu thập 8 Epic Food" },
					{ Id = "DQ4_RareAmber_12", Type = "CollectFoodType", MetricKey = "FoodType_RareAmber", FoodType = "RareAmber", Target = 12, Weight = 1, Desc = "Thu thập 12 Rare Amber Food" },
					{ Id = "DQ4_EpicViolet_4", Type = "CollectFoodType", MetricKey = "FoodType_EpicViolet", FoodType = "EpicViolet", Target = 4, Weight = 1, Desc = "Thu thập 4 Epic Violet Food" },
					{ Id = "DQ4_Kill_2", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 2, Weight = 1, Desc = "Hạ gục 2 người chơi" },
					{ Id = "DQ4_Round_2", Type = "CompleteRounds", MetricKey = "CompletedRounds", Target = 2, Weight = 1, Desc = "Hoàn thành 2 round" },
					{ Id = "DQ4_HpPotion_3", Type = "UseHpPotion", MetricKey = "HpPotionUses", Target = 3, Weight = 1, Desc = "Sử dụng 3 HP Potion" },
					{ Id = "DQ4_Bomb_2", Type = "BombPlayersDamaged", MetricKey = "BombPlayersDamaged", Target = 2, Weight = 1, Desc = "Dùng Bomb gây sát thương cho 2 người chơi" },
				},
			},
			{
				Reward = { Diamonds = 250 }, -- 10x previous reward
				QuestPool = {
					{ Id = "DQ5_EpicFood_15", Type = "CollectFoodRarity", MetricKey = "Food_Epic", Rarity = "Epic", Target = 15, Weight = 1, Desc = "Thu thập 15 Epic Food" },
					{ Id = "DQ5_LegendaryFood_4", Type = "CollectFoodRarity", MetricKey = "Food_Legendary", Rarity = "Legendary", Target = 4, Weight = 1, Desc = "Thu thập 4 Legendary Food" },
					{ Id = "DQ5_EpicViolet_12", Type = "CollectFoodType", MetricKey = "FoodType_EpicViolet", FoodType = "EpicViolet", Target = 12, Weight = 1, Desc = "Thu thập 12 Epic Violet Food" },
					{ Id = "DQ5_LegendaryGold_2", Type = "CollectFoodType", MetricKey = "FoodType_LegendaryGold", FoodType = "LegendaryGold", Target = 2, Weight = 1, Desc = "Thu thập 2 Legendary Gold Food" },
					{ Id = "DQ5_Kill_3", Type = "KillPlayers", MetricKey = "PlayerKills", Target = 3, Weight = 1, Desc = "Hạ gục 3 người chơi" },
					{ Id = "DQ5_Round_3", Type = "CompleteRounds", MetricKey = "CompletedRounds", Target = 3, Weight = 1, Desc = "Hoàn thành 3 round" },
					{ Id = "DQ5_HpPotion_4", Type = "UseHpPotion", MetricKey = "HpPotionUses", Target = 4, Weight = 1, Desc = "Sử dụng 4 HP Potion" },
					{ Id = "DQ5_Bomb_3", Type = "BombPlayersDamaged", MetricKey = "BombPlayersDamaged", Target = 3, Weight = 1, Desc = "Dùng Bomb gây sát thương cho 3 người chơi" },
				},
			},
		},
	},
}

return QuestConfig
