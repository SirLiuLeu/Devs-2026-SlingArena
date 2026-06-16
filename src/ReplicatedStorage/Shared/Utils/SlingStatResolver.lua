--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local SlingStatResolver = {}

export type ResolvedSlingStats = {
	maxHP: number,
	baseDamage: number,
	armor: number,
	regen: number,
	speed: number,
	launchPower: number,
	control: number,
	weight: number,
	launchSpeed: number,
	launchRange: number,
	moveSpeed: number,
	damageMultiplier: number,
	reflectDamage: number,
	expBonus: number,
}

local STAR_MULTIPLIER_PER_RANK = 0.08
local LEVEL_MULTIPLIER_PER_LEVEL = 0.03

local function readPassiveValue(passiveAbility: any?, key: string): number?
	if type(passiveAbility) ~= "table" then
		return nil
	end
	local directValue = passiveAbility[key]
	if type(directValue) == "number" then
		return directValue
	end
	local params = passiveAbility.params
	if type(params) == "table" and type(params[key]) == "number" then
		return params[key]
	end
	return nil
end

local function readPassiveMultiplier(passiveAbility: any?, key: string): number
	return readPassiveValue(passiveAbility, key) or 1
end

local function readPassiveAdd(passiveAbility: any?, key: string): number
	return readPassiveValue(passiveAbility, key) or 0
end

local function resolveExpBonus(passiveAbility: any?): number
	if type(passiveAbility) == "table" and passiveAbility.type == "ExpBonus" then
		return math.max(0, readPassiveValue(passiveAbility, "value") or 0)
	end
	return readPassiveAdd(passiveAbility, "expBonus")
end

function SlingStatResolver.Resolve(definitionId: string, star: number?, level: number?): ResolvedSlingStats
	local sling = SlingConfig.GetById(definitionId) or SlingConfig.GetById(SlingConfig.DefaultSlingId)
	local base = SlingConfig.BaseStats
	local slingStats = sling and sling.stats or {}
	local safeStar = math.max(1, math.floor(star or 1))
	local safeLevel = math.max(1, math.floor(level or 1))
	local starMultiplier = 1 + ((safeStar - 1) * STAR_MULTIPLIER_PER_RANK)
	local levelMultiplier = 1 + ((safeLevel - 1) * LEVEL_MULTIPLIER_PER_LEVEL)
	local growthMultiplier = starMultiplier * levelMultiplier
	local passive = sling and sling.passiveAbility or nil

	local maxHP = (slingStats.maxHP or base.maxHP) * growthMultiplier * readPassiveMultiplier(passive, "maxHpMultiplier")
	local baseDamage = (slingStats.baseDamage or base.baseDamage) * growthMultiplier * readPassiveMultiplier(passive, "damageMultiplier")
	local regen = (slingStats.regen or base.regenPerSecond) * growthMultiplier * readPassiveMultiplier(passive, "regenMultiplier")
	local launchPower = (slingStats.launchPower or 1) * growthMultiplier
	local control = (slingStats.control or 1) * growthMultiplier
	local speed = (slingStats.speed or PhysicsConfig.Movement.MoveSpeed) * readPassiveMultiplier(passive, "moveSpeedMultiplier")

	return {
		maxHP = maxHP,
		baseDamage = baseDamage,
		armor = math.clamp((slingStats.armor or 0) + readPassiveAdd(passive, "armor"), 0, 0.8),
		regen = regen,
		speed = speed,
		launchPower = launchPower,
		control = control,
		weight = slingStats.weight or 1,
		launchSpeed = PhysicsConfig.Launch.SpeedMax * launchPower,
		launchRange = base.maxShootRange * control,
		moveSpeed = speed,
		damageMultiplier = readPassiveMultiplier(passive, "finalDamageMultiplier"),
		reflectDamage = math.max(base.reflectDamagePercent, readPassiveAdd(passive, "reflectDamage")),
		expBonus = resolveExpBonus(passive),
	}
end

return SlingStatResolver
