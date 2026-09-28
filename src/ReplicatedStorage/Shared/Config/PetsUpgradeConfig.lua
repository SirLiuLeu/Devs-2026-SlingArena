--!strict

local PetsUpgradeConfig = {}

PetsUpgradeConfig.BaseCost = 100
PetsUpgradeConfig.Growth = 1.35
PetsUpgradeConfig.MaxLevel = 50

-- Each pet stat is worth its configured value at level 1. Every later
-- level adds this fraction of that level-1 value to the displayed stat.
-- TODO: Adjust balancing formula later. Designers can tune this value without
-- changing the inventory UI or individual pet definitions.
PetsUpgradeConfig.StatGrowthPerLevel = 0.10

function PetsUpgradeConfig.LateGameMultiplier(level: number): number
	local safeLevel = math.max(1, math.floor(level))
	if safeLevel >= 40 then
		return 2
	elseif safeLevel >= 25 then
		return 1.5
	end
	return 1
end

function PetsUpgradeConfig.GetUpgradeCost(level: number, baseCost: number?): number
	local safeLevel = math.max(1, math.floor(level))
	local costBase = math.max(0, math.floor(baseCost or PetsUpgradeConfig.BaseCost))
	return math.floor((costBase * (PetsUpgradeConfig.Growth ^ (safeLevel - 1)) * PetsUpgradeConfig.LateGameMultiplier(safeLevel)) + 0.5)
end

function PetsUpgradeConfig.GetStatAtLevel(baseValue: number, level: number): number
	local safeLevel = math.max(1, math.floor(level))
	-- TODO: Adjust balancing formula later. `baseValue` is the level-1 stat and
	-- `StatGrowthPerLevel` is the linear growth applied for each level after it.
	return baseValue * (1 + PetsUpgradeConfig.StatGrowthPerLevel * (safeLevel - 1))
end

return PetsUpgradeConfig
