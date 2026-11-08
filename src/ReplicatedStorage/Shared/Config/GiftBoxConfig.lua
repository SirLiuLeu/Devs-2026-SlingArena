--!strict

-- Weighted, server-authoritative Gift Box rewards.
-- Every outcome grants either Diamonds or an item that exists in ItemConfig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)

local GiftBoxConfig = {}

export type GiftBoxReward =
	{ kind: "Diamonds", amount: number, weight: number }
	| { kind: "Item", itemId: string, quantity: number, weight: number }

GiftBoxConfig.Rewards = {
	{ kind = "Diamonds", amount = 20, weight = 28 },
	{ kind = "Diamonds", amount = 50, weight = 18 },
	{ kind = "Diamonds", amount = 100, weight = 4 },
	{ kind = "Item", itemId = "hp_potion", quantity = 1, weight = 18 },
	{ kind = "Item", itemId = "exp_buff_30", quantity = 1, weight = 8 },
	{ kind = "Item", itemId = "damage_buff_20", quantity = 1, weight = 8 },
	{ kind = "Item", itemId = "hp_buff_30", quantity = 1, weight = 6 },
	{ kind = "Item", itemId = "exp_card_500", quantity = 1, weight = 4 },
	{ kind = "Item", itemId = "luck_buff_clover", quantity = 1, weight = 4 },
	{ kind = "Item", itemId = "bomb", quantity = 1, weight = 2 },
} :: { GiftBoxReward }

local totalWeight = 0
for _, reward in ipairs(GiftBoxConfig.Rewards) do
	local weight = math.max(0, math.floor(tonumber(reward.weight) or 0))
	assert(weight > 0, "GiftBox reward weights must be positive integers.")
	totalWeight += weight
	if reward.kind == "Item" then
		assert(ItemConfig.GetById(reward.itemId) ~= nil, "GiftBox reward references an unknown ItemConfig id: " .. reward.itemId)
		assert(reward.quantity >= 1, "GiftBox item quantities must be at least one.")
	elseif reward.kind == "Diamonds" then
		assert(reward.amount >= 1, "GiftBox Diamond rewards must be at least one.")
	end
end
assert(totalWeight == 100, "GiftBox reward weights must total exactly 100.")

function GiftBoxConfig.GetRewards(): { GiftBoxReward }
	local copy: { GiftBoxReward } = {}
	for _, reward in ipairs(GiftBoxConfig.Rewards) do
		table.insert(copy, table.clone(reward))
	end
	return copy
end

function GiftBoxConfig.Roll(rng: Random?): GiftBoxReward?
	local source = rng or Random.new()
	local roll = source:NextNumber(0, totalWeight)
	local cursor = 0
	for _, reward in ipairs(GiftBoxConfig.Rewards) do
		cursor += reward.weight
		if roll < cursor then
			return table.clone(reward)
		end
	end
	return table.clone(GiftBoxConfig.Rewards[#GiftBoxConfig.Rewards])
end

return GiftBoxConfig
