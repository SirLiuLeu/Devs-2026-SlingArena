--!strict

local EquipmentConfig = require(game:GetService("ReplicatedStorage").Shared.Config.EquipmentConfig)

local EquipmentStatResolver = {}

local STAT_ALIASES = {
	maxHP = "maxHP",
	MaxHP = "maxHP",
	baseDamage = "baseDamage",
	BaseDamage = "baseDamage",
	regen = "regen",
	RegenRate = "regen",
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

function EquipmentStatResolver.GetEquippedDefinitions(ownedEquipment: { [string]: any }?, equippedEquipment: { [string]: any }?): { any }
	local definitions = {}
	if type(ownedEquipment) ~= "table" or type(equippedEquipment) ~= "table" then
		return definitions
	end
	for _, instanceId in pairs(equippedEquipment) do
		if type(instanceId) == "string" then
			local ownedInstance = ownedEquipment[instanceId]
			local definition = ownedInstance and EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
			if definition then
				table.insert(definitions, definition)
			end
		end
	end
	return definitions
end

function EquipmentStatResolver.Apply(baseStats: { [string]: number }, equippedDefinitions: { any }?): { [string]: number }
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

function EquipmentStatResolver.Resolve(baseStats: { [string]: number }, ownedEquipment: { [string]: any }?, equippedEquipment: { [string]: any }?): { [string]: number }
	return EquipmentStatResolver.Apply(baseStats, EquipmentStatResolver.GetEquippedDefinitions(ownedEquipment, equippedEquipment))
end

return EquipmentStatResolver
