--!strict

local PetsUpgradeConfig = {}

PetsUpgradeConfig.BaseCost = 50
PetsUpgradeConfig.MaxLevel = 50
PetsUpgradeConfig.AbilityMaxLevel = 20
PetsUpgradeConfig.StatGrowthPerLevel = 0.05
PetsUpgradeConfig.MilestoneLevels = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }

local RARITY_COST_MULTIPLIERS = { Common = 1, Rare = 1.25, Epic = 1.6, Legendary = 2 }

function PetsUpgradeConfig.NormalizeLevel(level: number): number
	return math.clamp(math.floor(tonumber(level) or 1), 1, PetsUpgradeConfig.MaxLevel)
end

function PetsUpgradeConfig.GetUpgradeCost(level: number, rarity: string): number
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	if safeLevel >= PetsUpgradeConfig.MaxLevel then return 0 end
	local rarityMultiplier = RARITY_COST_MULTIPLIERS[rarity] or RARITY_COST_MULTIPLIERS.Common
	return math.floor((PetsUpgradeConfig.BaseCost * safeLevel * rarityMultiplier) + 0.5)
end

function PetsUpgradeConfig.IsMilestone(level: number): boolean
	for _, milestone in ipairs(PetsUpgradeConfig.MilestoneLevels) do
		if level == milestone then return true end
	end
	return false
end

function PetsUpgradeConfig.GetNextMilestone(level: number): number?
	for _, milestone in ipairs(PetsUpgradeConfig.MilestoneLevels) do
		if milestone > level then return milestone end
	end
	return nil
end

function PetsUpgradeConfig.GetStatAtLevel(baseValue: number, level: number): number
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	local multiplier = 1 + ((safeLevel - 1) * PetsUpgradeConfig.StatGrowthPerLevel)
	return baseValue * multiplier
end

return PetsUpgradeConfig
