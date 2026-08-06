local QuestConfig = {

    DailyQuests = {
        OnlineTime_15 = { Id = "D_Online_15", Type = "OnlineTime", Target = 15 * 60, Reward = { Diamonds = 5 }, Desc = "Online trong 15 phút" },
        OnlineTime_30 = { Id = "D_Online_30", Type = "OnlineTime", Target = 30 * 60, Reward = { Diamonds = 10 }, Desc = "Online trong 30 phút" },
        CollectFoodPoints = { Id = "D_Points_500", Type = "CollectPoints", Target = 500, Reward = { Diamonds = 10 }, Desc = "Thu thập 500 điểm từ Food" },
        DealDamage = { Id = "D_Damage_50k", Type = "DealDamage", Target = 50000, Reward = { Diamonds = 10 }, Desc = "Gây 50k sát thương" },
        -- Random hệ thống chọn 1 trong các quest thu thập food sau mỗi ngày:
        CollectSpecificFood = {
            Legendary = { Id = "D_Food_Leg", Type = "CollectFoodRarity", Rarity = "Legendary", Target = 2, Reward = { Diamonds = 15 } },
            Epic = { Id = "D_Food_Epi", Type = "CollectFoodRarity", Rarity = "Epic", Target = 5, Reward = { Diamonds = 15 } },
            Rare = { Id = "D_Food_Rar", Type = "CollectFoodRarity", Rarity = "Rare", Target = 10, Reward = { Diamonds = 15 } },
            Uncommon = { Id = "D_Food_Unc", Type = "CollectFoodRarity", Rarity = "Uncommon", Target = 20, Reward = { Diamonds = 15 } },
            Common = { Id = "D_Food_Com", Type = "CollectFoodRarity", Rarity = "Common", Target = 100, Reward = { Diamonds = 15 } },
        }
    },

    MainQuests = {
        -- Cấu trúc: [Mốc 1, Mốc 2, Mốc 3]
        CollectPoints = {
            Type = "CollectPointsTotal",
            Milestones = {1000, 5000, 25000},
            Rewards = {1000, 5000, 25000}, -- Kim cương tương ứng
            Desc = "Thu thập tổng cộng %d điểm từ thức ăn."
        },
        KillPlayers = {
            Type = "KillPlayersTotal",
            Milestones = {10, 50, 250},
            Rewards = {1000, 5000, 25000},
            Desc = "Hạ gục %d người chơi."
        },
        PlayTime = {
            Type = "PlayTimeTotal",
            Milestones = {3 * 3600, 15 * 3600, 75 * 3600}, -- Lưu theo giây
            Rewards = {1000, 5000, 25000},
            Desc = "Chơi game đủ %d giờ."
        },
        Top1 = {
            Type = "Top1Total",
            Milestones = {5, 25, 75},
            Rewards = {1000, 5000, 25000},
            Desc = "Đạt Top 1 trong round %d lần."
        },
        Launch = {
            Type = "LaunchTotal",
            Milestones = {50, 250, 1250},
            Rewards = {1000, 5000, 25000},
            Desc = "Thực hiện Launch %d lần."
        },
        CompleteDaily = {
            Type = "CompleteDailyTotal",
            Milestones = {7, 35, 175},
            Rewards = {1000, 5000, 25000},
            Desc = "Hoàn thành %d nhiệm vụ hằng ngày."
        }
    }
}
return QuestConfig