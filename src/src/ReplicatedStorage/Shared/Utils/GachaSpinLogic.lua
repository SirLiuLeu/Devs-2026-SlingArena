--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GachaRewardConfig = require(ReplicatedStorage.Shared.Config.GachaRewardConfig)

local GachaSpinLogic = {}

export type RewardEntry = GachaRewardConfig.RewardEntry

local FULL_CIRCLE = 360

local function normalizeAngle(angle: number): number
	local normalized = angle % FULL_CIRCLE
	if normalized < 0 then
		normalized += FULL_CIRCLE
	end
	return normalized
end

function GachaSpinLogic.BuildSlices(rewards: { RewardEntry }): { { reward: RewardEntry, startAngle: number, endAngle: number } }
	local totalWeight = 0
	for _, reward in ipairs(rewards) do
		totalWeight += math.max(0, reward.weight)
	end
	if totalWeight <= 0 then
		return {}
	end

	local slices = {}
	local cursor = 0
	for _, reward in ipairs(rewards) do
		local ratio = math.max(0, reward.weight) / totalWeight
		local span = ratio * FULL_CIRCLE
		local startAngle = cursor
		local endAngle = cursor + span
		table.insert(slices, {
			reward = reward,
			startAngle = startAngle,
			endAngle = endAngle,
		})
		cursor = endAngle
	end

	if #slices > 0 then
		slices[#slices].endAngle = FULL_CIRCLE
	end
	return slices
end

function GachaSpinLogic.SelectReward(rng: Random?, rewards: { RewardEntry }): RewardEntry?
	local source = rng or Random.new()
	local totalWeight = 0
	for _, reward in ipairs(rewards) do
		totalWeight += math.max(0, reward.weight)
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = source:NextNumber(0, totalWeight)
	local cursor = 0
	for _, reward in ipairs(rewards) do
		cursor += math.max(0, reward.weight)
		if roll <= cursor then
			return reward
		end
	end
	return rewards[#rewards]
end

function GachaSpinLogic.GetCenterAngleForReward(rewardId: string, slices): number
	for _, slice in ipairs(slices) do
		if slice.reward.id == rewardId then
			return normalizeAngle((slice.startAngle + slice.endAngle) * 0.5)
		end
	end
	return 0
end

function GachaSpinLogic.ResolveRewardAtAngle(slices, pointerAngle: number): RewardEntry?
	local normalized = normalizeAngle(pointerAngle)
	for _, slice in ipairs(slices) do
		if normalized >= slice.startAngle and normalized < slice.endAngle then
			return slice.reward
		end
	end
	if #slices > 0 then
		return slices[#slices].reward
	end
	return nil
end

function GachaSpinLogic.ComputeLandingRotation(selectedRewardId: string, fullRotations: number?): number
	local rewards = GachaRewardConfig.GetRewards()
	local slices = GachaSpinLogic.BuildSlices(rewards)
	local center = GachaSpinLogic.GetCenterAngleForReward(selectedRewardId, slices)
	local rotations = math.max(fullRotations or 4, 1)
	return (rotations * FULL_CIRCLE) + (FULL_CIRCLE - center)
end

return GachaSpinLogic
