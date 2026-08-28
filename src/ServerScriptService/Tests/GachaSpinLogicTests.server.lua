-- --!strict

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local GachaRewardConfig = require(ReplicatedStorage.Shared.Config.GachaRewardConfig)
-- local GachaSpinLogic = require(ReplicatedStorage.Shared.Utils.GachaSpinLogic)

-- local function runTest(name: string, fn)
-- 	local ok, err = pcall(fn)
-- 	if not ok then
-- 		warn(string.format("[GachaSpinLogicTests] FAIL %s :: %s", name, tostring(err)))
-- 		error(err)
-- 	end
-- 	print(string.format("[GachaSpinLogicTests] PASS %s", name))
-- end

-- local function getWeightMap()
-- 	local map = {}
-- 	for _, reward in ipairs(GachaRewardConfig.GetRewards()) do
-- 		map[reward.id] = reward.weight
-- 	end
-- 	return map
-- end

-- local function testWeightedDistribution()
-- 	local rewards = GachaRewardConfig.GetRewards()
-- 	local rng = Random.new(99)
-- 	local counts = {}
-- 	local total = 6000
-- 	for i = 1, total do
-- 		local selected = GachaSpinLogic.SelectReward(rng, rewards)
-- 		if not selected then
-- 			error("SelectReward must return reward")
-- 		end
-- 		counts[selected.id] = (counts[selected.id] or 0) + 1
-- 	end

-- 	local weights = getWeightMap()
-- 	local sorted = {}
-- 	for id, weight in pairs(weights) do
-- 		table.insert(sorted, { id = id, weight = weight, count = counts[id] or 0 })
-- 	end
-- 	table.sort(sorted, function(a, b)
-- 		return a.weight > b.weight
-- 	end)
-- 	if sorted[1].count <= sorted[#sorted].count then
-- 		error("Higher weighted reward should appear more than lowest weighted reward")
-- 	end
-- end

-- local function testSelectionCorrectness()
-- 	local rewards = GachaRewardConfig.GetRewards()
-- 	for i = 1, 200 do
-- 		local selected = GachaSpinLogic.SelectReward(Random.new(i), rewards)
-- 		if not selected then
-- 			error("Selected reward must not be nil")
-- 		end
-- 		if type(selected.id) ~= "string" or selected.id == "" then
-- 			error("Selected reward id must be valid string")
-- 		end
-- 	end
-- end

-- local function testAngleMappingConsistency()
-- 	local rewards = GachaRewardConfig.GetRewards()
-- 	local slices = GachaSpinLogic.BuildSlices(rewards)
-- 	for _, reward in ipairs(rewards) do
-- 		local center = GachaSpinLogic.GetCenterAngleForReward(reward.id, slices)
-- 		local resolved = GachaSpinLogic.ResolveRewardAtAngle(slices, center)
-- 		if not resolved or resolved.id ~= reward.id then
-- 			error(string.format("Angle mapping mismatch for reward=%s", reward.id))
-- 		end
-- 	end
-- end

-- local function testUiSyncRewardEqualsPointer()
-- 	local rewards = GachaRewardConfig.GetRewards()
-- 	local slices = GachaSpinLogic.BuildSlices(rewards)
-- 	for _, reward in ipairs(rewards) do
-- 		local rotation = GachaSpinLogic.ComputeLandingRotation(reward.id, 5)
-- 		local pointerAngle = (360 - (rotation % 360)) % 360
-- 		local visual = GachaSpinLogic.ResolveRewardAtAngle(slices, pointerAngle)
-- 		if not visual or visual.id ~= reward.id then
-- 			error(string.format("UI sync mismatch logic=%s visual=%s", reward.id, visual and visual.id or "nil"))
-- 		end
-- 	end
-- end

-- runTest("weighted random distribution", testWeightedDistribution)
-- runTest("reward selection correctness", testSelectionCorrectness)
-- runTest("angle mapping consistency", testAngleMappingConsistency)
-- runTest("ui sync reward equals arrow result", testUiSyncRewardEqualsPointer)
