--!strict

local BalanceConfig = require(script.Parent.BalanceConfig)

local LevelConfig = {
	MaxLevel = 200,
	StartingLevel = 1,
	StartingExp = 0,
	StartingDiamonds = 1000,
	StartingAttributePoints = 0,
	StartingSize = 1,
}

function LevelConfig.RequiredExp(level: number): number
	return BalanceConfig.BaseExp * (math.max(level, 1) ^ BalanceConfig.ExpExponent)
end

return LevelConfig
