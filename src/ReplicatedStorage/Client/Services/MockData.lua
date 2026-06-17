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

local MOCK_ONLINE_REWARDS = {
	{ id = "reward_01", rewardType = "EXP", amount = 150, icon = "rbxassetid://0", duration = 20, state = "Locked" },
	{ id = "reward_02", rewardType = "Dinamond", amount = 25, icon = "rbxassetid://0", duration = 45, state = "Locked" },
	{ id = "reward_03", rewardType = "Item", amount = 1, icon = "rbxassetid://0", duration = 70, state = "Locked" },
	{ id = "reward_04", rewardType = "EXP", amount = 300, icon = "rbxassetid://0", duration = 100, state = "Locked" },
	{ id = "reward_05", rewardType = "Dinamond", amount = 40, icon = "rbxassetid://0", duration = 125, state = "Locked" },
	{ id = "reward_06", rewardType = "Item", amount = 2, icon = "rbxassetid://0", duration = 165, state = "Locked" },
	{ id = "reward_07", rewardType = "Dinamond", amount = 60, icon = "rbxassetid://0", duration = 15, state = "Locked" },
	{ id = "reward_08", rewardType = "EXP", amount = 500, icon = "rbxassetid://0", duration = 90, state = "Locked" },
	{ id = "reward_09", rewardType = "Item", amount = 3, icon = "rbxassetid://0", duration = 140, state = "Locked" },
	{ id = "reward_10", rewardType = "Dinamond", amount = 100, icon = "rbxassetid://0", duration = 180, state = "Locked" },
	{ id = "reward_11", rewardType = "EXP", amount = 800, icon = "rbxassetid://0", duration = 210, state = "Locked" },
	{ id = "reward_12", rewardType = "Item", amount = 1, icon = "rbxassetid://0", duration = 240, state = "Locked" },
}

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
		{ id = "SupportLauncher", name = "Support Launcher", price = 450, icon = "rbxassetid://0" },
		{ id = "StunLauncher", name = "Stun Launcher", price = 900, icon = "rbxassetid://0" },
		{ id = "NormalLauncher", name = "Normal Launcher", price = 100, icon = "rbxassetid://0" },
		{ id = "VacuumLauncher", name = "Vacuum Launcher", price = 500, icon = "rbxassetid://0" },
		{ id = "StealthLauncher", name = "Stealth Launcher", price = 1800, icon = "rbxassetid://0" },
		{ id = "HealLauncher", name = "Heal Launcher", price = 850, icon = "rbxassetid://0" },
		{ id = "SpeedLauncher", name = "Speed Launcher", price = 1700, icon = "rbxassetid://0" },
		{ id = "BonusBuffLauncher", name = "Bonus Buff Launcher", price = 3500, icon = "rbxassetid://0" },
		{ id = "PetrifyLauncher", name = "Petrify Launcher", price = 1800, icon = "rbxassetid://0" },
		{ id = "FireLauncher", name = "Fire Launcher", price = 900, icon = "rbxassetid://0" },
		{ id = "PoisonLauncher", name = "Poison Launcher", price = 900, icon = "rbxassetid://0" },
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

local function cloneRewardEntry(entry)
	return {
		id = entry.id,
		rewardType = entry.rewardType,
		amount = entry.amount,
		icon = entry.icon,
		duration = entry.duration,
		state = entry.state,
	}
end

local function cloneRewards(entries)
	local result = {}
	for _, entry in ipairs(entries) do
		table.insert(result, cloneRewardEntry(entry))
	end
	return result
end

function MockData.GetInventoryState()
	local playerData = MockPlayerData.GetPlayerData()
	return MockPlayerData.GetInventoryState()
end

function MockData.GetPlayerData()
	return MockPlayerData.GetPlayerData()
end

function MockData.GetOnlineRewardState()
	return {
		rewards = cloneRewards(MOCK_ONLINE_REWARDS),
		columns = 4,
		rows = 3,
	}
end

function MockData.GetShopState()
	return deepClone(MOCK_SHOP_STATE)
end

function MockData.GetDailyLoginState()
	return deepClone(MOCK_DAILY_LOGIN_STATE)
end

return MockData
