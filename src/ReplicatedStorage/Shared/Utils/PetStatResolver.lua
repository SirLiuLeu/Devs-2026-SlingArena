--!strict

local PetsConfig = require(game:GetService("ReplicatedStorage").Shared.Config.PetsConfig)

local PetStatResolver = {}

local STAT_ALIASES = {
	maxHP = "maxHP",
	MaxHP = "maxHP",
	baseDamage = "baseDamage",
	BaseDamage = "baseDamage",
	regen = "regen",
	RegenerationRate = "regen",
	launchSpeed = "launchSpeed",
	LaunchSpeed = "launchSpeed",
	launchRange = "launchRange",
	LaunchRange = "launchRange",
	moveSpeed = "moveSpeed",
	MoveSpeed = "moveSpeed",
	damageMultiplier = "damageMultiplier",
	DamageMultiplier = "damageMultiplier",
	reflectDamage = "reflectDamage",
	ReflectDamage = "reflectDamage",
	armor = "armor",
	Armor = "armor",
	expBonus = "expBonus",
	ExpBonus = "expBonus",
	launchCooldown = "launchCooldown",
	LaunchCooldown = "launchCooldown",
}

local function canonical(statName: string): string
	return STAT_ALIASES[statName] or statName
end

local function copyStats(baseStats: { [string]: number }): { [string]: number }
	local result = {}
	for key, value in pairs(baseStats) do
		if type(value) == "number" then
			result[canonical(key)] = value
		end
	end
	return result
end

function PetStatResolver.GetEquippedDefinitions(ownedPets: { [string]: any }?, equippedPets: { [string]: any }?): { any }
	local definitions = {}
	if type(ownedPets) ~= "table" or type(equippedPets) ~= "table" then
		return definitions
	end
	for _, instanceId in pairs(equippedPets) do
		if type(instanceId) == "string" then
			local ownedInstance = ownedPets[instanceId]
			local definition = ownedInstance and PetsConfig.GetById(tostring(ownedInstance.definitionId or ""))
			if definition then
				table.insert(definitions, definition)
			end
		end
	end
	return definitions
end

function PetStatResolver.Apply(baseStats: { [string]: number }, equippedDefinitions: { any }?): { [string]: number }
	local result = copyStats(baseStats)
	local multipliers = {}
	for _, definition in ipairs(equippedDefinitions or {}) do
		local modifiers = definition.statModifiers
		local add = type(modifiers) == "table" and modifiers.Add or nil
		if type(add) == "table" then
			for statName, amount in pairs(add) do
				if type(amount) == "number" then
					local key = canonical(statName)
					result[key] = (result[key] or 0) + amount
				end
			end
		end
		local multiply = type(modifiers) == "table" and modifiers.Multiply or nil
		if type(multiply) == "table" then
			for statName, multiplier in pairs(multiply) do
				if type(multiplier) == "number" then
					local key = canonical(statName)
					multipliers[key] = (multipliers[key] or 1) * multiplier
				end
			end
		end
	end
	for statName, multiplier in pairs(multipliers) do
		result[statName] = (result[statName] or 0) * multiplier
	end
	return result
end

function PetStatResolver.Resolve(baseStats: { [string]: number }, ownedPets: { [string]: any }?, equippedPets: { [string]: any }?): { [string]: number }
	return PetStatResolver.Apply(baseStats, PetStatResolver.GetEquippedDefinitions(ownedPets, equippedPets))
end

return PetStatResolver
