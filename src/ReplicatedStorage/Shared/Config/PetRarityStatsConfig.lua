--!strict

-- Base combat stats granted by every equipped pet. These are intentionally
-- independent from an individual pet's active/passive ability.
local PetRarityStatsConfig = {
	Common = { BaseHP = 100, BaseDamage = 10 },
	Rare = { BaseHP = 250, BaseDamage = 25 },
	Epic = { BaseHP = 500, BaseDamage = 50 },
	Legendary = { BaseHP = 1000, BaseDamage = 100 },
}

function PetRarityStatsConfig.Get(rarity: string): { BaseHP: number, BaseDamage: number }
	return PetRarityStatsConfig[rarity] or PetRarityStatsConfig.Common
end

return PetRarityStatsConfig
