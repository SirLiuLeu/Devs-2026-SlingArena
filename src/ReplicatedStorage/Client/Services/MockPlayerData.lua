--!strict

local MockPlayerData = {}

local function cloneItems(items: { [string]: number }): { [string]: number }
	local result = {}
	for itemId, quantity in pairs(items) do
		result[itemId] = quantity
	end
	return result
end

local MOCK_PLAYER_DATA = {
	Diamonds = 300,
	OwnedItems = {
		hp_potion = 25,
		exp_buff_x2 = 25,
		gacha_ticket = 100,
	},
}

function MockPlayerData.GetPlayerData()
	return {
		Diamonds = MOCK_PLAYER_DATA.Diamonds,
		OwnedItems = cloneItems(MOCK_PLAYER_DATA.OwnedItems),
	}
end

return MockPlayerData
