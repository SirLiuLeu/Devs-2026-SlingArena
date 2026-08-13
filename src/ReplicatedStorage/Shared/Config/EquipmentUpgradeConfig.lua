--!strict

local EquipmentUpgradeConfig = {}

EquipmentUpgradeConfig.BaseCost = 100
EquipmentUpgradeConfig.Growth = 1.35
EquipmentUpgradeConfig.MaxLevel = 50

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

return EquipmentUpgradeConfig
