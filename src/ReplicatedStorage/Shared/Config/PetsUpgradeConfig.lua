--!strict

local PetsUpgradeConfig = {}

PetsUpgradeConfig.BaseCost = 100
PetsUpgradeConfig.Growth = 1.35
PetsUpgradeConfig.MaxLevel = 20
PetsUpgradeConfig.StatGrowthPerLevel = 0.10
PetsUpgradeConfig.AbilityTierLevels = { 1, 5, 10, 15, 20 }

function PetsUpgradeConfig.NormalizeLevel(level: number): number
	return math.clamp(math.floor(tonumber(level) or 1), 1, PetsUpgradeConfig.MaxLevel)
end

function PetsUpgradeConfig.GetUpgradeCost(level: number, baseCost: number?): number
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	local costBase = math.max(0, math.floor(baseCost or PetsUpgradeConfig.BaseCost))
	return math.floor((costBase * (PetsUpgradeConfig.Growth ^ (safeLevel - 1))) + 0.5)
end

function PetsUpgradeConfig.GetStatAtLevel(baseValue: number, level: number): number
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	return baseValue * (1 + PetsUpgradeConfig.StatGrowthPerLevel * (safeLevel - 1))
end

function PetsUpgradeConfig.GetAbilityTier(level: number): number
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	local tier = 1
	for index, tierStartLevel in ipairs(PetsUpgradeConfig.AbilityTierLevels) do
		if safeLevel >= tierStartLevel then
			tier = index
		else
			break
		end
	end
	return tier
end

return PetsUpgradeConfig
