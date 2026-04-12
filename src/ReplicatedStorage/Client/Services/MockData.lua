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

local function cloneStats(stats)
	return {
		damage = stats.damage,
		hp = stats.hp,
		range = stats.range,
		regen = stats.regen,
	}
end

local function cloneSlings(slings: { any }): { any }
	local result = {}
	for _, slingEntry in ipairs(slings) do
		table.insert(result, {
			id = slingEntry.id,
			level = slingEntry.level,
			equipped = slingEntry.equipped,
			name = slingEntry.name,
			icon = slingEntry.icon,
			stats = cloneStats(slingEntry.stats),
		})
	end
	return result
end

local function getDefaultOwnedSlings(): { any }
	local desired = { "Sling_01", "Sling_02", "Sling_03", "Sling_04", "Sling_05" }
	local slings = {}
	for index, slingId in ipairs(desired) do
		local slingDef = SlingConfig.GetById(slingId)
		if slingDef then
			table.insert(slings, {
				id = slingId,
				level = 1,
				equipped = index == 1,
				name = slingDef.name,
				icon = slingDef.icon,
				stats = {
					damage = slingDef.stats.launchPower,
					hp = 100 + (index * 5),
					range = slingDef.stats.control,
					regen = 1 + (index * 0.15),
				},
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
