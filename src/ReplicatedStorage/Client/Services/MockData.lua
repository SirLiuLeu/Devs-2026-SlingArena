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

local MOCK_ONLINE_REWARDS = {
	{ id = "reward_01", rewardType = "EXP", amount = 150, icon = "rbxassetid://0", duration = 20, state = "Locked" },
	{ id = "reward_02", rewardType = "Currency", amount = 25, icon = "rbxassetid://0", duration = 45, state = "Locked" },
	{ id = "reward_03", rewardType = "Item", amount = 1, icon = "rbxassetid://0", duration = 70, state = "Locked" },
	{ id = "reward_04", rewardType = "EXP", amount = 300, icon = "rbxassetid://0", duration = 100, state = "Locked" },
	{ id = "reward_05", rewardType = "Currency", amount = 40, icon = "rbxassetid://0", duration = 125, state = "Locked" },
	{ id = "reward_06", rewardType = "Item", amount = 2, icon = "rbxassetid://0", duration = 165, state = "Locked" },
	{ id = "reward_07", rewardType = "Currency", amount = 60, icon = "rbxassetid://0", duration = 15, state = "Locked" },
	{ id = "reward_08", rewardType = "EXP", amount = 500, icon = "rbxassetid://0", duration = 90, state = "Locked" },
	{ id = "reward_09", rewardType = "Item", amount = 3, icon = "rbxassetid://0", duration = 140, state = "Locked" },
	{ id = "reward_10", rewardType = "Currency", amount = 100, icon = "rbxassetid://0", duration = 180, state = "Locked" },
	{ id = "reward_11", rewardType = "EXP", amount = 800, icon = "rbxassetid://0", duration = 210, state = "Locked" },
	{ id = "reward_12", rewardType = "Item", amount = 1, icon = "rbxassetid://0", duration = 240, state = "Locked" },
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
	return {
		OwnedItems = cloneItems(MOCK_PLAYER_STATE.OwnedItems),
		OwnedSlings = cloneSlings(MOCK_PLAYER_STATE.OwnedSlings),
		SlingCapacity = MOCK_PLAYER_STATE.SlingCapacity,
	}
end

function MockData.GetOnlineRewardState()
	return {
		rewards = cloneRewards(MOCK_ONLINE_REWARDS),
		columns = 4,
		rows = 3,
	}
end

return MockData
