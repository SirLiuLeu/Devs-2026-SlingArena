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
	if type(petOrDefinition.abilityId) == "string" then
		return PetsConfig.GetByAbilityId(petOrDefinition.abilityId)
	end
	return nil
end

-- Rarity-based base HP/Damage use the +5% / +3% two-stage curve. Ability
-- values preserve levels 1-20 milestones, then interpolate to level-50 targets.
function PetProgression.Resolve(petOrDefinition: any, petOrLevel: any?): { [string]: any }?
	local definition = PetProgression.GetDefinition(petOrDefinition)
	if not definition then return nil end
	local level = PetProgression.GetLevel(if petOrLevel == nil then petOrDefinition else petOrLevel)
	local rarityStats = PetRarityStatsConfig.Get(definition.rarity)
	-- Every Pet definition and progression row share the same AbilityID.
	local abilityId = definition.abilityId
	return {
		definition = definition,
		level = level,
		baseStats = {
			maxHP = PetsUpgradeConfig.GetStatAtLevel(rarityStats.BaseHP, level),
			baseDamage = PetsUpgradeConfig.GetStatAtLevel(rarityStats.BaseDamage, level),
		},
		abilityParams = PetAbilityProgressionConfig.GetParams(abilityId, level),
	}
end

return PetProgression
