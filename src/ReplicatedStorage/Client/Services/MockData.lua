--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)

local MockData = {}

local function deepClone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, nested in pairs(value) do
		result[key] = deepClone(nested)
	end
	return result
end

local MOCK_SHOP_STATE = {
	balance = 300,
	items = {
		{ id = "item_hp_potion", name = "HP Potion", description = "Heal burst potion", priceX1 = 1, priceX10 = 9, icon = "rbxassetid://0" },
		{ id = "item_buff_exp", name = "Buff EXP", description = "Temporary EXP boost", priceX1 = 4, priceX10 = 36, icon = "rbxassetid://0" },
		{ id = "item_size_up", name = "Size Increase (30s)", description = "Grow bigger for 30s", priceX1 = 5, priceX10 = 45, icon = "rbxassetid://0" },
		{ id = "item_speed_boost", name = "Speed Boost (30%)", description = "Boost speed by 30%", priceX1 = 2, priceX10 = 18, icon = "rbxassetid://0" },
		{ id = "item_invisible", name = "Invisibility (30s)", description = "Invisible for 30s", priceX1 = 3, priceX10 = 27, icon = "rbxassetid://0" },
	},
	launchers = {
		{ id = "Normalduck", name = "Normal Duck", price = 100, icon = "rbxassetid://0" },
		{ id = "Kingduck", name = "King Duck", price = 900, icon = "rbxassetid://0" },
		{ id = "Witchduck", name = "Witch Duck", price = 1200, icon = "rbxassetid://0" },
		{ id = "Drakeduck", name = "Drake Duck", price = 1800, icon = "rbxassetid://0" },
		{ id = "Shielduck", name = "Shield Duck", price = 1500, icon = "rbxassetid://0" },
	},
	dinamondPacks = {
		{ id = "pack_1usd", usd = 1, dinamondAmount = 125, note = "Base rate", icon = "rbxassetid://0" },
		{ id = "pack_10usd", usd = 10, dinamondAmount = 1300, note = "Bonus +50", icon = "rbxassetid://0" },
		{ id = "pack_50usd", usd = 50, dinamondAmount = 7000, note = "Bonus +750", icon = "rbxassetid://0" },
		{ id = "pack_100usd", usd = 100, dinamondAmount = 15000, note = "Bonus +2500", icon = "rbxassetid://0" },
		{ id = "pack_400usd", usd = 400, dinamondAmount = 50000, note = "Best value", icon = "rbxassetid://0" },
	},
}

local MOCK_DAILY_LOGIN_STATE = {
	currentDay = 1,
	entries = {
		{ day = 1, rewardType = "Dinamond", rewardText = "50 Dinamond", icon = "rbxassetid://0", claimed = false, state = "Claimable" },
		{ day = 2, rewardType = "Item", rewardText = "HP Potion x1", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 3, rewardType = "Dinamond", rewardText = "100 Dinamond", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 4, rewardType = "Item", rewardText = "Buff EXP x1", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 5, rewardType = "Dinamond", rewardText = "150 Dinamond", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 6, rewardType = "Launcher", rewardText = "Normal Launcher", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 7, rewardType = "Dinamond", rewardText = "1000 Dinamond (Big Reward)", icon = "rbxassetid://0", claimed = false, state = "Locked" },
	},
}

function MockData.GetInventoryState()
	local playerData = MockPlayerData.GetPlayerData()
	return MockPlayerData.GetInventoryState()
end

function MockData.GetPlayerData()
	return MockPlayerData.GetPlayerData()
end

function MockData.GetShopState()
	return deepClone(MOCK_SHOP_STATE)
end

function MockData.GetDailyLoginState()
	return deepClone(MOCK_DAILY_LOGIN_STATE)
end

function MockData.GetMatchScoreboardState()
	local playerData = MockPlayerData.GetPlayerData()
	return {
		Rows = {
			{ UserId = 1, Name = playerData.DisplayName or playerData.Name or "You", Level = playerData.Level or 1, Points = playerData.RankPoints or 0, Kills = 0, Deaths = 0, State = "Idle" },
			{ UserId = 2, Name = "Mock Rival", Level = 8, Points = 250, Kills = 3, Deaths = 1, State = "Moving" },
			{ UserId = 3, Name = "Mock Guest", Level = 3, Points = 75, Kills = 1, Deaths = 2, State = "Dead" },
		},
		Limit = 100,
	}
end

return MockData
