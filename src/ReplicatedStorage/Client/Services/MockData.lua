--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PurchasePetConfig = require(ReplicatedStorage.Shared.Config.PurchasePetConfig)

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

local MOCK_DIAMOND_PACKS = {
	{ id = "pack_1usd", usd = 1, dinamondAmount = 125, note = "Base rate", icon = "rbxassetid://0" },
	{ id = "pack_10usd", usd = 10, dinamondAmount = 1300, note = "Bonus +50", icon = "rbxassetid://0" },
	{ id = "pack_50usd", usd = 50, dinamondAmount = 7000, note = "Bonus +750", icon = "rbxassetid://0" },
	{ id = "pack_100usd", usd = 100, dinamondAmount = 15000, note = "Bonus +2500", icon = "rbxassetid://0" },
	{ id = "pack_400usd", usd = 400, dinamondAmount = 50000, note = "Best value", icon = "rbxassetid://0" },
}

local MOCK_DAILY_LOGIN_STATE = {
	currentDay = 1,
	entries = {
		{ day = 1, rewardType = "Dinamond", rewardText = "50 Dinamond", icon = "rbxassetid://0", claimed = false, state = "Claimable" },
		{ day = 2, rewardType = "Item", rewardText = "HP Potion x1", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 3, rewardType = "Dinamond", rewardText = "100 Dinamond", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 4, rewardType = "Item", rewardText = "EXP Buff x1", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 5, rewardType = "Dinamond", rewardText = "150 Dinamond", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 6, rewardType = "Launcher", rewardText = "Normal Launcher", icon = "rbxassetid://0", claimed = false, state = "Locked" },
		{ day = 7, rewardType = "Dinamond", rewardText = "1000 Dinamond (Big Reward)", icon = "rbxassetid://0", claimed = false, state = "Locked" },
	},
}

function MockData.GetInventoryState()
	return MockPlayerData.GetInventoryState()
end

function MockData.GetPlayerData()
	return MockPlayerData.GetPlayerData()
end

-- Build the Shop catalog from shared gameplay configs. This prevents client-side
-- mock data from drifting away from IDs, descriptions, and prices validated by the server.
function MockData.GetShopState()
	local items = {}
	for _, itemId in ipairs(ItemConfig.GetAllIds()) do
		local definition = ItemConfig.GetById(itemId)
		if definition then
			table.insert(items, {
				id = definition.id,
				name = definition.name,
				description = definition.description,
				script = definition.script or definition.description,
				priceX1 = definition.shopPriceX1,
				priceX10 = definition.shopPriceX10,
				icon = definition.icon,
			})
		end
	end

	local launchers = {}
	for _, launcherId in ipairs(LauncherConfig.GetAllIds()) do
		local definition = LauncherConfig.GetById(launcherId)
		if definition and type(definition.shopPrice) == "number" then
			table.insert(launchers, {
				id = definition.id,
				name = definition.name,
				description = definition.description,
				script = definition.script or definition.description,
				price = definition.shopPrice,
				icon = definition.iconId,
			})
		end
	end

	local pets = {}
	for _, petId in ipairs(PetsConfig.GetAllIds()) do
		local definition = PetsConfig.GetById(petId)
		local price = PurchasePetConfig.GetPrice(petId)
		if definition and price ~= nil then
			table.insert(pets, {
				id = petId,
				name = definition.DisplayName,
				modelName = definition.Name,
				rarity = definition.rarity,
				category = definition.category,
				script = definition.script,
				price = price,
				icon = definition.iconId,
			})
		end
	end

	return {
		balance = math.max(0, math.floor(MockPlayerData.GetPlayerData().Diamonds or 0)),
		items = items,
		launchers = launchers,
		pets = pets,
		dinamondPacks = deepClone(MOCK_DIAMOND_PACKS),
	}
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
