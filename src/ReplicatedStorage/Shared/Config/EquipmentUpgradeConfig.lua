--!strict

local EquipmentUpgradeConfig = {}

EquipmentUpgradeConfig.BaseCost = 100
EquipmentUpgradeConfig.Growth = 1.35
EquipmentUpgradeConfig.MaxLevel = 50
-- All equipment stat values scale from their level-one value through this formula.
EquipmentUpgradeConfig.StatGrowth = 0.10

function EquipmentUpgradeConfig.LateGameMultiplier(level: number): number
	local safeLevel = math.max(1, math.floor(level))
	if safeLevel >= 40 then return 2 end
	if safeLevel >= 25 then return 1.5 end
	return 1
end

function EquipmentUpgradeConfig.GetUpgradeCost(level: number, baseCost: number?): number
	local safeLevel = math.max(1, math.floor(level))
	local costBase = math.max(0, math.floor(baseCost or EquipmentUpgradeConfig.BaseCost))
	return math.floor((costBase * (EquipmentUpgradeConfig.Growth ^ (safeLevel - 1)) * EquipmentUpgradeConfig.LateGameMultiplier(safeLevel)) + 0.5)
end

function EquipmentUpgradeConfig.GetStatMultiplier(level: number): number
	return 1 + (math.max(1, math.floor(level)) - 1) * EquipmentUpgradeConfig.StatGrowth
end

function EquipmentUpgradeConfig.GetScaledStat(baseValue: number, level: number): number
	return baseValue * EquipmentUpgradeConfig.GetStatMultiplier(level)
end

return EquipmentUpgradeConfig
