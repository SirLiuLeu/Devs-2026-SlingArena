--!strict

-- Online Reward grants inventory items and Diamonds only. Round EXP is intentionally excluded.
local OnlineRewardConfig = {}

OnlineRewardConfig.CycleDurationSeconds = 30 * 60
OnlineRewardConfig.OfflineResetSeconds = 30 * 60
OnlineRewardConfig.SaveIntervalSeconds = 20
OnlineRewardConfig.SnapshotIntervalSeconds = 1
OnlineRewardConfig.Columns = 3
OnlineRewardConfig.Rows = 5
OnlineRewardConfig.DiamondsIcon = "rbxassetid://0"

OnlineRewardConfig.Slots = {
	{ Id = "reward_01", TimeSeconds = 60, Rarity = "Common" },
	{ Id = "reward_02", TimeSeconds = 120, Rarity = "Common" },
	{ Id = "reward_03", TimeSeconds = 180, Rarity = "Common" },
	{ Id = "reward_04", TimeSeconds = 300, Rarity = "Common" },
	{ Id = "reward_05", TimeSeconds = 420, Rarity = "Common" },
	{ Id = "reward_06", TimeSeconds = 600, Rarity = "Normal" },
	{ Id = "reward_07", TimeSeconds = 780, Rarity = "Normal" },
	{ Id = "reward_08", TimeSeconds = 900, Rarity = "Normal" },
	{ Id = "reward_09", TimeSeconds = 1080, Rarity = "Normal" },
	{ Id = "reward_10", TimeSeconds = 1200, Rarity = "Normal" },
	{ Id = "reward_11", TimeSeconds = 1380, Rarity = "Rare" },
	{ Id = "reward_12", TimeSeconds = 1500, Rarity = "Rare" },
	{ Id = "reward_13", TimeSeconds = 1620, Rarity = "Rare" },
	{ Id = "reward_14", TimeSeconds = 1680, Rarity = "Rare" },
	{ Id = "reward_15", TimeSeconds = 1800, Rarity = "Rare" },
}

OnlineRewardConfig.RewardSetOrder = { "SetA", "SetB", "SetC" }

OnlineRewardConfig.RewardSets = {
	SetA = {
		{ Kind = "Diamonds", Amount = 15 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 1 },
		{ Kind = "Item", ItemId = "exp_buff_30", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 20 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 1 },
		{ Kind = "Item", ItemId = "damage_buff_20", Quantity = 1 },
		{ Kind = "Item", ItemId = "hp_buff_30", Quantity = 1 },
		{ Kind = "Item", ItemId = "bomb", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 60 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 3 },
		{ Kind = "Item", ItemId = "bomb", Quantity = 2 },
		{ Kind = "Item", ItemId = "gift_box", Quantity = 1 },
		{ Kind = "Item", ItemId = "luck_buff_clover", Quantity = 1 },
		{ Kind = "Item", ItemId = "damage_buff_20", Quantity = 2 },
		{ Kind = "Diamonds", Amount = 150 },
	},
	SetB = {
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 15 },
		{ Kind = "Item", ItemId = "exp_buff_30", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 20 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 2 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 3 },
		{ Kind = "Item", ItemId = "damage_buff_20", Quantity = 1 },
		{ Kind = "Item", ItemId = "bomb", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 60 },
		{ Kind = "Item", ItemId = "hp_buff_30", Quantity = 1 },
		{ Kind = "Item", ItemId = "gift_box", Quantity = 1 },
		{ Kind = "Item", ItemId = "bomb", Quantity = 2 },
		{ Kind = "Item", ItemId = "luck_buff_clover", Quantity = 1 },
		{ Kind = "Item", ItemId = "exp_buff_30", Quantity = 2 },
		{ Kind = "Diamonds", Amount = 180 },
	},
	SetC = {
		{ Kind = "Diamonds", Amount = 20 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 1 },
		{ Kind = "Item", ItemId = "hp_buff_30", Quantity = 1 },
		{ Kind = "Item", ItemId = "exp_buff_30", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 25 },
		{ Kind = "Item", ItemId = "damage_buff_20", Quantity = 1 },
		{ Kind = "Item", ItemId = "hp_potion", Quantity = 3 },
		{ Kind = "Item", ItemId = "bomb", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 50 },
		{ Kind = "Item", ItemId = "gift_box", Quantity = 1 },
		{ Kind = "Item", ItemId = "hp_buff_30", Quantity = 2 },
		{ Kind = "Item", ItemId = "bomb", Quantity = 2 },
		{ Kind = "Item", ItemId = "damage_buff_20", Quantity = 2 },
		{ Kind = "Item", ItemId = "luck_buff_clover", Quantity = 1 },
		{ Kind = "Diamonds", Amount = 150 },
	},
}

function OnlineRewardConfig.GetRewardSetIds(): { string }
	return table.clone(OnlineRewardConfig.RewardSetOrder)
end

function OnlineRewardConfig.GetRewardSet(rewardSetId: string): { any }?
	local rewardSet = OnlineRewardConfig.RewardSets[rewardSetId]
	return if rewardSet then table.clone(rewardSet) else nil
end

return OnlineRewardConfig
