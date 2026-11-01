--!strict

-- Launcher star and rarity are a single progression ladder.
-- Each successful combine advances one tier and increases selected Launcher stats by 20%.
local RarityConfig = {}

RarityConfig.MaxStar = 5

RarityConfig.Types = {
	Common = {
		id = "Common",
		displayName = "Common",
		order = 1,
		star = 1,
		statMultiplier = 1.0,
		color = Color3.fromRGB(190, 190, 190),
		borderColor = Color3.fromRGB(145, 145, 145),
		nextRarity = "Normal",
	},
	Normal = {
		id = "Normal",
		displayName = "Normal",
		order = 2,
		star = 2,
		statMultiplier = 1.2,
		color = Color3.fromRGB(100, 205, 135),
		borderColor = Color3.fromRGB(55, 155, 95),
		nextRarity = "Rare",
	},
	Rare = {
		id = "Rare",
		displayName = "Rare",
		order = 3,
		star = 3,
		statMultiplier = 1.4,
		color = Color3.fromRGB(75, 155, 255),
		borderColor = Color3.fromRGB(45, 115, 220),
		nextRarity = "Epic",
	},
	Epic = {
		id = "Epic",
		displayName = "Epic",
		order = 4,
		star = 4,
		statMultiplier = 1.6,
		color = Color3.fromRGB(180, 95, 255),
		borderColor = Color3.fromRGB(135, 55, 210),
		nextRarity = "Legendary",
	},
	Legendary = {
		id = "Legendary",
		displayName = "Legendary",
		order = 5,
		star = 5,
		statMultiplier = 1.8,
		color = Color3.fromRGB(255, 190, 65),
		borderColor = Color3.fromRGB(220, 135, 35),
		nextRarity = nil,
	},
}

function RarityConfig.GetById(rarityId: string?)
	if type(rarityId) ~= "string" then
		return nil
	end
	return RarityConfig.Types[rarityId]
end

function RarityConfig.GetByStar(star: number?)
	local safeStar = math.clamp(math.floor(tonumber(star) or 1), 1, RarityConfig.MaxStar)
	for _, rarity in pairs(RarityConfig.Types) do
		if rarity.star == safeStar then
			return rarity
		end
	end
	return RarityConfig.Types.Common
end

function RarityConfig.GetNext(rarityId: string?)
	local rarity = RarityConfig.GetById(rarityId)
	if not rarity or not rarity.nextRarity then
		return nil
	end
	return RarityConfig.GetById(rarity.nextRarity)
end

function RarityConfig.GetAllIds(): { string }
	local result = {}
	for rarityId in pairs(RarityConfig.Types) do
		table.insert(result, rarityId)
	end
	table.sort(result, function(left, right)
		return RarityConfig.Types[left].order < RarityConfig.Types[right].order
	end)
	return result
end

return RarityConfig
