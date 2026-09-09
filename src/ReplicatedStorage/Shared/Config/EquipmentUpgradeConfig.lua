--!strict

local EquipmentUpgradeConfig = {}

EquipmentUpgradeConfig.BaseCost = 100
EquipmentUpgradeConfig.Growth = 1.35
EquipmentUpgradeConfig.MaxLevel = 50

-- Each equipment stat is worth its configured value at level 1. Every later
-- level adds this fraction of that level-1 value to the displayed stat.
-- TODO: Adjust balancing formula later. Designers can tune this value without
-- changing the inventory UI or individual equipment definitions.
EquipmentUpgradeConfig.StatGrowthPerLevel = 0.10

function EquipmentUpgradeConfig.LateGameMultiplier(level: number): number
	local safeLevel = math.max(1, math.floor(level))
	if safeLevel >= 40 then
		return 2
	elseif safeLevel >= 25 then
		return 1.5
	end
	return 1
end

function EquipmentUpgradeConfig.GetUpgradeCost(level: number, baseCost: number?): number
	local safeLevel = math.max(1, math.floor(level))
	local costBase = math.max(0, math.floor(baseCost or EquipmentUpgradeConfig.BaseCost))
	return math.floor((costBase * (EquipmentUpgradeConfig.Growth ^ (safeLevel - 1)) * EquipmentUpgradeConfig.LateGameMultiplier(safeLevel)) + 0.5)
end

function EquipmentUpgradeConfig.GetStatAtLevel(baseValue: number, level: number): number
	local safeLevel = math.max(1, math.floor(level))
	-- TODO: Adjust balancing formula later. `baseValue` is the level-1 stat and
	-- `StatGrowthPerLevel` is the linear growth applied for each level after it.
	return baseValue * (1 + EquipmentUpgradeConfig.StatGrowthPerLevel * (safeLevel - 1))
end

return EquipmentUpgradeConfig
