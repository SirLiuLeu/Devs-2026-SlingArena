--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)
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

local function testRandomSlingRewardForPlayer()
	local validSlings = {}
	for _, id in ipairs(SlingConfig.GetAllIds()) do
		validSlings[id] = true
	end

	local fakePlayer = {
		Name = "RewardTestPlayer",
		UserId = 999001,
		OwnedSlings = {},
	}

	for i = 1, 100 do
		local slingId = RewardRoller.RollRandomSlingId()
		if not slingId or not validSlings[slingId] then
			error(string.format("Invalid sling id generated at iteration %d: %s", i, tostring(slingId)))
		end
		table.insert(fakePlayer.OwnedSlings, slingId)
	end

	if #fakePlayer.OwnedSlings ~= 100 then
		error("Fake player should receive exactly 100 sling rewards")
	end

	print(string.format(
		"[RewardGenerationTests] Player %s received %d valid sling rewards",
		fakePlayer.Name,
		#fakePlayer.OwnedSlings
	))
end

runTest("Random item generation", testRandomItemGeneration)
runTest("Random sling reward for player", testRandomSlingRewardForPlayer)
