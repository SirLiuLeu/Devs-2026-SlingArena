--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local LauncherStatResolver = {}

export type ResolvedLauncherStats = {
	maxHP: number,
	baseDamage: number,
	armor: number,
	regen: number,
	speed: number,
	launchPower: number,
	launchSpeed: number,
	weight: number,
	moveSpeed: number,
	damageMultiplier: number,
	reflectDamage: number,
	expBonus: number,
}

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

function LauncherStatResolver.Resolve(definitionId: string, star: number?, level: number?, rarityId: string?): ResolvedLauncherStats
	local launcher = LauncherConfig.GetById(definitionId) or LauncherConfig.GetById(LauncherConfig.DefaultLauncherId)
	local base = LauncherConfig.BaseStats
	local launcherStats = launcher and launcher.stats or {}
	local safeStar = math.clamp(math.floor(tonumber(star) or 1), 1, RarityConfig.MaxStar)
	local safeLevel = math.max(1, math.floor(level or 1))
	local rarity = RarityConfig.GetById(rarityId) or RarityConfig.GetByStar(safeStar)
	local rarityMultiplier = rarity.statMultiplier or 1
	local levelMultiplier = 1 + ((safeLevel - 1) * LEVEL_MULTIPLIER_PER_LEVEL)
	-- Rarity growth is restricted to the five agreed Launcher stats.
	-- The pre-existing per-level launchPower growth is preserved independently.
	local rarityAndLevelMultiplier = rarityMultiplier * levelMultiplier
	local passive = launcher and launcher.passiveAbility or nil

	local maxHP = (launcherStats.maxHP or base.maxHP) * rarityAndLevelMultiplier * readPassiveMultiplier(passive, "maxHpMultiplier")
	local baseDamage = (launcherStats.baseDamage or base.baseDamage) * rarityAndLevelMultiplier * readPassiveMultiplier(passive, "damageMultiplier")
	local regen = (launcherStats.regen or base.regenPerSecond) * rarityAndLevelMultiplier * readPassiveMultiplier(passive, "regenMultiplier")
	local launchPower = (launcherStats.launchPower or 1) * levelMultiplier
	local speed = (launcherStats.speed or PhysicsConfig.Movement.MoveSpeed) * readPassiveMultiplier(passive, "moveSpeedMultiplier")
	local armor = math.clamp(
		((launcherStats.armor or 0) + readPassiveAdd(passive, "armor")) * rarityMultiplier,
		0,
		0.8
	)
	local reflectDamage = math.clamp(
		math.max(launcherStats.reflectDamage or base.reflectDamagePercent, readPassiveAdd(passive, "reflectDamage")) * rarityMultiplier,
		0,
		0.5
	)

	return {
		maxHP = maxHP,
		baseDamage = baseDamage,
		armor = armor,
		regen = regen,
		speed = speed,
		launchPower = launchPower,
		launchSpeed = math.clamp(launcherStats.launchSpeed or PhysicsConfig.Launch.SpeedMax, PhysicsConfig.Launch.SpeedMin, PhysicsConfig.Launch.SpeedMax),
		weight = math.max(1, tonumber(launcherStats.weight) or base.weight or 100),
		moveSpeed = speed,
		damageMultiplier = readPassiveMultiplier(passive, "finalDamageMultiplier"),
		reflectDamage = reflectDamage,
		expBonus = resolveExpBonus(passive),
	}
end

return LauncherStatResolver
