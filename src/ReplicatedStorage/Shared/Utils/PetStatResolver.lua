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
		local abilityAddOverrides = {}
		local abilityMultiplyOverrides = {}

		if abilityExpBonus then
			result.expBonus = (result.expBonus or 0) + math.max(0, abilityExpBonus)
			abilityAddOverrides.expBonus = true
		end

		if type(abilityParams) == "table" then
			local additiveAbilityParams = {
				maxHPBonus = "maxHP",
				baseDamageBonus = "baseDamage",
				moveSpeedBonus = "moveSpeed",
				reflectDamageBonus = "reflectDamage",
			}
			for paramName, statName in pairs(additiveAbilityParams) do
				local amount = tonumber(abilityParams[paramName])
				if amount ~= nil then
					pendingAdd[statName] = (pendingAdd[statName] or 0) + amount
					abilityAddOverrides[statName] = true
				end
			end

			local cooldownReduction = tonumber(abilityParams.launchCooldownReduction)
			if cooldownReduction ~= nil then
				pendingAdd.launchCooldown = (pendingAdd.launchCooldown or 0) - math.max(0, cooldownReduction)
				abilityAddOverrides.launchCooldown = true
			end

			local launchSpeedMultiplier = tonumber(abilityParams.launchSpeedMultiplier)
			if launchSpeedMultiplier ~= nil then
				pendingMultiply.launchSpeed = (pendingMultiply.launchSpeed or 1) * math.max(0, launchSpeedMultiplier)
				abilityMultiplyOverrides.launchSpeed = true
			end
		end

		local definition = progression.definition
		local statModifiers = type(definition) == "table" and definition.statModifiers
		local additions = type(statModifiers) == "table" and statModifiers.Add
		local multipliers = type(statModifiers) == "table" and statModifiers.Multiply

		if type(additions) == "table" then
			for statName, value in pairs(additions) do
				if type(value) == "number" then
					local resolvedName = canonical(statName)
					-- Level-scaled ability values supersede their legacy static
					-- statModifiers entries so a Pet's bonus is never counted twice.
					if not abilityAddOverrides[resolvedName] then
						pendingAdd[resolvedName] = (pendingAdd[resolvedName] or 0) + value
					end
				end
			end
		end

		if type(multipliers) == "table" then
			for statName, value in pairs(multipliers) do
				if type(value) == "number" then
					local resolvedName = canonical(statName)
					if not abilityMultiplyOverrides[resolvedName] then
						pendingMultiply[resolvedName] = (pendingMultiply[resolvedName] or 1) * value
					end
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
