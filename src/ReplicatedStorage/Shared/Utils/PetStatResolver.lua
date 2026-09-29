--!strict

local PetProgression = require(game:GetService("ReplicatedStorage").Shared.Utils.PetProgression)

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

function PetStatResolver.GetEquippedProgressions(ownedPets: { [string]: any }?, equippedPets: { [string]: any }?): { any }
	local progressions = {}
	if type(ownedPets) ~= "table" or type(equippedPets) ~= "table" then
		return progressions
	end
	for _, instanceId in pairs(equippedPets) do
		if type(instanceId) == "string" then
			local ownedInstance = ownedPets[instanceId]
			local progression = type(ownedInstance) == "table" and PetProgression.Resolve(ownedInstance)
			if progression then table.insert(progressions, progression) end
		end
	end
	return progressions
end

function PetStatResolver.Apply(baseStats: { [string]: number }, equippedProgressions: { any }?): { [string]: number }
	local result = copyStats(baseStats)
	for _, progression in ipairs(equippedProgressions or {}) do
		local petBaseStats = progression.baseStats
		if type(petBaseStats) == "table" then
			result.maxHP = (result.maxHP or 0) + (tonumber(petBaseStats.maxHP) or 0)
			result.baseDamage = (result.baseDamage or 0) + (tonumber(petBaseStats.baseDamage) or 0)
		end
	end
	return result
end

function PetStatResolver.Resolve(baseStats: { [string]: number }, ownedPets: { [string]: any }?, equippedPets: { [string]: any }?): { [string]: number }
	return PetStatResolver.Apply(baseStats, PetStatResolver.GetEquippedProgressions(ownedPets, equippedPets))
end

return PetStatResolver
