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
	local pendingAdd: { [string]: number } = {}
	local pendingMultiply: { [string]: number } = {}

	for _, progression in ipairs(equippedProgressions or {}) do
		local petBaseStats = progression.baseStats
		if type(petBaseStats) == "table" then
			result.maxHP = (result.maxHP or 0) + (tonumber(petBaseStats.maxHP) or 0)
			result.baseDamage = (result.baseDamage or 0) + (tonumber(petBaseStats.baseDamage) or 0)
		end

		local abilityParams = progression.abilityParams
		local abilityExpBonus = type(abilityParams) == "table" and tonumber(abilityParams.expBonus) or nil
		if abilityExpBonus then
			result.expBonus = (result.expBonus or 0) + math.max(0, abilityExpBonus)
		end

		local definition = progression.definition
		local statModifiers = type(definition) == "table" and definition.statModifiers
		local additions = type(statModifiers) == "table" and statModifiers.Add
		local multipliers = type(statModifiers) == "table" and statModifiers.Multiply

		if type(additions) == "table" then
			for statName, value in pairs(additions) do
				if type(value) == "number" then
					local resolvedName = canonical(statName)
					-- BrainBoost's level-scaled ability parameter supersedes the
					-- legacy fixed Add.expBonus value in PetsConfig.
					if resolvedName ~= "expBonus" or abilityExpBonus == nil then
						pendingAdd[resolvedName] = (pendingAdd[resolvedName] or 0) + value
					end
				end
			end
		end

		if type(multipliers) == "table" then
			for statName, value in pairs(multipliers) do
				if type(value) == "number" then
					local resolvedName = canonical(statName)
					pendingMultiply[resolvedName] = (pendingMultiply[resolvedName] or 1) * value
				end
			end
		end
	end

	-- Apply every additive contribution before multiplicative contributions,
	-- independent of equipped-slot iteration order.
	for statName, value in pairs(pendingAdd) do
		result[statName] = (result[statName] or 0) + value
	end
	for statName, value in pairs(pendingMultiply) do
		result[statName] = (result[statName] or 1) * value
	end

	result.reflectDamage = math.clamp(result.reflectDamage or 0, 0, 0.5)
	return result
end

function PetStatResolver.Resolve(baseStats: { [string]: number }, ownedPets: { [string]: any }?, equippedPets: { [string]: any }?): { [string]: number }
	return PetStatResolver.Apply(baseStats, PetStatResolver.GetEquippedProgressions(ownedPets, equippedPets))
end

return PetStatResolver
