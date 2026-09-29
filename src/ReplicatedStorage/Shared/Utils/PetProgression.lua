--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAbilityProgressionConfig = require(ReplicatedStorage.Shared.Config.PetAbilityProgressionConfig)
local PetRarityStatsConfig = require(ReplicatedStorage.Shared.Config.PetRarityStatsConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)

local PetProgression = {}

function PetProgression.GetLevel(petOrLevel: any): number
	if type(petOrLevel) == "table" then return PetsUpgradeConfig.NormalizeLevel(tonumber(petOrLevel.level) or 1) end
	return PetsUpgradeConfig.NormalizeLevel(tonumber(petOrLevel) or 1)
end

function PetProgression.GetDefinition(petOrDefinition: any): any?
	if type(petOrDefinition) ~= "table" then return nil end
	if type(petOrDefinition.PetId) == "string" then return petOrDefinition end
	return PetsConfig.GetById(tostring(petOrDefinition.definitionId or ""))
end

-- Base rarity stats scale on every level. Ability parameters are discrete and
-- are read only from the ability milestone configuration.
function PetProgression.Resolve(petOrDefinition: any, petOrLevel: any?): { [string]: any }?
	local definition = PetProgression.GetDefinition(petOrDefinition)
	if not definition then return nil end
	local level = PetProgression.GetLevel(if petOrLevel == nil then petOrDefinition else petOrLevel)
	local rarityStats = PetRarityStatsConfig.Get(definition.rarity)
	return {
		definition = definition,
		level = level,
		baseStats = {
			maxHP = PetsUpgradeConfig.GetStatAtLevel(rarityStats.BaseHP, level),
			baseDamage = PetsUpgradeConfig.GetStatAtLevel(rarityStats.BaseDamage, level),
		},
		abilityParams = PetAbilityProgressionConfig.GetParams(definition.abilityId, level),
	}
end

return PetProgression
