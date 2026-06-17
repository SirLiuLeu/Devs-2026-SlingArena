--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RewardRoller = require(ReplicatedStorage.Shared.Utils.RewardRoller)

local function logPass(message: string)
	print(string.format("[RewardGenerationTests] PASS %s", message))
end

local function runTest(name: string, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn(string.format("[RewardGenerationTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
	logPass(name)
end

local function testRandomItemGeneration()
	local validItems = {}
	for _, id in ipairs(ItemConfig.GetAllIds()) do
		validItems[id] = true
	end

	for i = 1, 100 do
		local itemId = RewardRoller.RollRandomItemId()
		if not itemId or not validItems[itemId] then
			error(string.format("Invalid item id generated at iteration %d: %s", i, tostring(itemId)))
		end
	end

	print("[RewardGenerationTests] Random item generation produced valid config IDs in 100 rolls")
end

local function testRandomLauncherRewardForPlayer()
	local validLaunchers = {}
	for _, id in ipairs(LauncherConfig.GetAllIds()) do
		validLaunchers[id] = true
	end

	local fakePlayer = {
		Name = "RewardTestPlayer",
		UserId = 999001,
		OwnedLaunchers = {},
	}

	for i = 1, 100 do
		local launcherId = RewardRoller.RollRandomLauncherId()
		if not launcherId or not validLaunchers[launcherId] then
			error(string.format("Invalid launcher id generated at iteration %d: %s", i, tostring(launcherId)))
		end
		fakePlayer.OwnedLaunchers[string.format("reward_%03d", i)] = {
			definitionId = launcherId,
			star = 1,
			level = 1,
			acquiredAt = i,
		}
	end

	local ownedLauncherCount = 0
	for _ in pairs(fakePlayer.OwnedLaunchers) do
		ownedLauncherCount += 1
	end
	if ownedLauncherCount ~= 100 then
		error("Fake player should receive exactly 100 launcher rewards")
	end

	print(string.format(
		"[RewardGenerationTests] Player %s received %d valid launcher rewards",
		fakePlayer.Name,
		ownedLauncherCount
	))
end

runTest("Random item generation", testRandomItemGeneration)
runTest("Random launcher reward for player", testRandomLauncherRewardForPlayer)
