--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)

local PetProgression = {}

local function copyTable(source: { [string]: any }?): { [string]: any }
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = if type(value) == "table" then copyTable(value) else value
	end
	return result
end

function PetProgression.GetLevel(petOrLevel: any): number
	if type(petOrLevel) == "table" then
		return PetsUpgradeConfig.NormalizeLevel(tonumber(petOrLevel.level) or 1)
	end
	return PetsUpgradeConfig.NormalizeLevel(tonumber(petOrLevel) or 1)
end

function PetProgression.GetDefinition(petOrDefinition: any): any?
	if type(petOrDefinition) ~= "table" then return nil end
	if type(petOrDefinition.PetId) == "string" then return petOrDefinition end
	return PetsConfig.GetById(tostring(petOrDefinition.definitionId or ""))
end

-- Returns all level-derived pet values. Stats increase every level; ability
-- parameters advance only at levels 5, 10, 15, and 20.
function PetProgression.Resolve(petOrDefinition: any, petOrLevel: any?): { [string]: any }?
	local definition = PetProgression.GetDefinition(petOrDefinition)
	if not definition then return nil end
	local level = PetProgression.GetLevel(if petOrLevel == nil then petOrDefinition else petOrLevel)
	local tier = PetsUpgradeConfig.GetAbilityTier(level)
	local modifiers = definition.statModifiers or {}
	local add = {}
	for statName, baseValue in pairs(modifiers.Add or {}) do
		if type(baseValue) == "number" then
			add[statName] = PetsUpgradeConfig.GetStatAtLevel(baseValue, level)
		end
	end
	local multiply = {}
	for statName, baseValue in pairs(modifiers.Multiply or {}) do
		if type(baseValue) == "number" then
			multiply[statName] = PetsUpgradeConfig.GetStatAtLevel(baseValue, level)
		end
	end
	local progression = definition.progression or {}
	local abilityTiers = progression.abilityTiers or {}
	local abilityParams = copyTable(abilityTiers[tier] or abilityTiers[#abilityTiers] or {})
	return {
		definition = definition,
		level = level,
		tier = tier,
		statModifiers = { Add = add, Multiply = multiply },
		abilityParams = abilityParams,
	}
end

return PetProgression
