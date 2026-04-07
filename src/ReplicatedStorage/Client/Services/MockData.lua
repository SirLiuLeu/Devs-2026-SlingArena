--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)

local MockData = {}

local function cloneItems(items: { [string]: number }): { [string]: number }
	local result = {}
	for itemId, quantity in pairs(items) do
		result[itemId] = quantity
	end
	return result
end

local function cloneSlings(slings: { { id: string, level: number, equipped: boolean } }): { { id: string, level: number, equipped: boolean } }
	local result = {}
	for _, slingEntry in ipairs(slings) do
		table.insert(result, {
			id = slingEntry.id,
			level = slingEntry.level,
			equipped = slingEntry.equipped,
		})
	end
	return result
end

local function getDefaultOwnedSlings(): { { id: string, level: number, equipped: boolean } }
	local desired = { "Sling_01", "Sling_02", "Sling_03", "Sling_04", "Sling_05" }
	local slings = {}
	for index, slingId in ipairs(desired) do
		if SlingConfig.GetById(slingId) then
			table.insert(slings, {
				id = slingId,
				level = 1,
				equipped = index == 1,
			})
		else
			warn(string.format("[MOCK_DATA] Sling id missing in SlingConfig: %s", slingId))
		end
	end
	return slings
end

local MOCK_PLAYER_STATE = {
	OwnedItems = {
		hp_potion = 25,
		exp_buff_x2 = 25,
		gacha_ticket = 100,
	},
	OwnedSlings = getDefaultOwnedSlings(),
	SlingCapacity = 40,
}

function MockData.GetInventoryState()
	return {
		OwnedItems = cloneItems(MOCK_PLAYER_STATE.OwnedItems),
		OwnedSlings = cloneSlings(MOCK_PLAYER_STATE.OwnedSlings),
		SlingCapacity = MOCK_PLAYER_STATE.SlingCapacity,
	}
end

return MockData
