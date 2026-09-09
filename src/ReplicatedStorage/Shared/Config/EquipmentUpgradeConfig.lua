--!strict

local EquipmentUpgradeConfig = {}

EquipmentUpgradeConfig.BaseCost = 100
EquipmentUpgradeConfig.Growth = 1.35
EquipmentUpgradeConfig.MaxLevel = 50
-- TODO: Adjust balancing formula later. Each stat modifier scales by this fraction for every level after level 1.
EquipmentUpgradeConfig.StatGrowthPerLevel = 0.10

function EquipmentUpgradeConfig.LateGameMultiplier(level: number): number
	local safeLevel = math.max(1, math.floor(level))
	if safeLevel >= 40 then return 2 elseif safeLevel >= 25 then return 1.5 end
	return 1
end

function EquipmentUpgradeConfig.GetUpgradeCost(level: number, baseCost: number?): number
	local safeLevel = math.max(1, math.floor(level))
	local costBase = math.max(0, math.floor(baseCost or EquipmentUpgradeConfig.BaseCost))
	return math.floor((costBase * (EquipmentUpgradeConfig.Growth ^ (safeLevel - 1)) * EquipmentUpgradeConfig.LateGameMultiplier(safeLevel)) + 0.5)
end

function EquipmentUpgradeConfig.GetStatAtLevel(baseValue: number, level: number): number
	local safeLevel = math.max(1, math.floor(level))
	-- TODO: Adjust balancing formula later. baseValue is the definition modifier; level 1 preserves it.
	return baseValue * (1 + EquipmentUpgradeConfig.StatGrowthPerLevel * (safeLevel - 1))
end

return EquipmentUpgradeConfig
