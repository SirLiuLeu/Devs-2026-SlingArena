--!strict

-- Daily Login rewards are intentionally one reward per bundle:
-- either Diamonds or one ItemId/Quantity pair. This keeps slot UI simple.
local DailyLoginConfig = {}

DailyLoginConfig.SchemaVersion = 1
DailyLoginConfig.DaysPerCycle = 7
DailyLoginConfig.ResetUtcOffsetHours = 7 -- Vietnam local midnight (UTC+7)

DailyLoginConfig.DayTiers = {
	"Basic",
	"Basic",
	"Medium",
	"Medium",
	"Premium",
	"Premium",
}

DailyLoginConfig.BundlePools = {
	Basic = {
		{ Id = "basic_diamonds_200", Kind = "Diamonds", Amount = 200, Weight = 1 },
		{ Id = "basic_hp_potion_5", Kind = "Item", ItemId = "hp_potion", Quantity = 5, Weight = 1 },
		{ Id = "basic_exp_buff_3", Kind = "Item", ItemId = "exp_buff_30", Quantity = 3, Weight = 1 },
		{ Id = "basic_gift_box_2", Kind = "Item", ItemId = "gift_box", Quantity = 2, Weight = 1 },
		{ Id = "basic_bomb_2", Kind = "Item", ItemId = "bomb", Quantity = 2, Weight = 1 },
		{ Id = "basic_clover_2", Kind = "Item", ItemId = "luck_buff_clover", Quantity = 2, Weight = 1 },
	},
	Medium = {
		{ Id = "medium_diamonds_400", Kind = "Diamonds", Amount = 400, Weight = 1 },
		{ Id = "medium_hp_potion_10", Kind = "Item", ItemId = "hp_potion", Quantity = 10, Weight = 1 },
		{ Id = "medium_exp_buff_5", Kind = "Item", ItemId = "exp_buff_30", Quantity = 5, Weight = 1 },
		{ Id = "medium_gift_box_4", Kind = "Item", ItemId = "gift_box", Quantity = 4, Weight = 1 },
		{ Id = "medium_bomb_4", Kind = "Item", ItemId = "bomb", Quantity = 4, Weight = 1 },
		{ Id = "medium_exp_card_4", Kind = "Item", ItemId = "exp_card_500", Quantity = 4, Weight = 1 },
		{ Id = "medium_clover_4", Kind = "Item", ItemId = "luck_buff_clover", Quantity = 4, Weight = 1 },
	},
	Premium = {
		{ Id = "premium_diamonds_800", Kind = "Diamonds", Amount = 800, Weight = 1 },
		{ Id = "premium_diamonds_1200", Kind = "Diamonds", Amount = 1200, Weight = 0.75 },
		{ Id = "premium_hp_potion_20", Kind = "Item", ItemId = "hp_potion", Quantity = 20, Weight = 1 },
		{ Id = "premium_exp_buff_10", Kind = "Item", ItemId = "exp_buff_30", Quantity = 10, Weight = 1 },
		{ Id = "premium_gift_box_8", Kind = "Item", ItemId = "gift_box", Quantity = 8, Weight = 1 },
		{ Id = "premium_bomb_8", Kind = "Item", ItemId = "bomb", Quantity = 8, Weight = 1 },
		{ Id = "premium_exp_card_10", Kind = "Item", ItemId = "exp_card_500", Quantity = 10, Weight = 1 },
	},
}

DailyLoginConfig.PetDropWeights = {
	Rare = 65,
	Epic = 30,
	Legendary = 5,
}

local bundleById = {}
local bundleCountByTier = {}
for tier, pool in pairs(DailyLoginConfig.BundlePools) do
	bundleCountByTier[tier] = #pool
	for _, bundle in ipairs(pool) do
		bundleById[bundle.Id] = bundle
	end
end

function DailyLoginConfig.GetBundle(bundleId: string): { [string]: any }?
	return bundleById[bundleId]
end

function DailyLoginConfig.GetPool(tier: string): { any }
	return DailyLoginConfig.BundlePools[tier] or {}
end

function DailyLoginConfig.GetTierForDay(day: number): string?
	return DailyLoginConfig.DayTiers[day]
end

function DailyLoginConfig.GetBundleCount(tier: string): number
	return bundleCountByTier[tier] or 0
end

return DailyLoginConfig
