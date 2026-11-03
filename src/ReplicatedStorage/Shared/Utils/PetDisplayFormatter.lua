--!strict

-- Presentation-only Pet detail formatter. Ability descriptions are owned by
-- PetAbilityDisplayConfig; live numeric behavior remains owned by PetProgression.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetProgression = require(ReplicatedStorage.Shared.Utils.PetProgression)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local PetAbilityDisplayConfig = require(ReplicatedStorage.Shared.Config.PetAbilityDisplayConfig)

local PetDisplayFormatter = {}

export type DisplayText = {
	LevelText: string,
	HPText: string,
	DamageText: string,
	ScriptText: string,
}

local function formatNumber(value: number): string
	if math.abs(value - math.floor(value + 0.5)) < 0.001 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.2f", value)
end

local function transition(label: string, currentValue: number, nextValue: number): string
	return string.format("%s: %s <font color=\"#00ff00\">-&gt; %s</font>", label, formatNumber(currentValue), formatNumber(nextValue))
end

local function encodeRichText(value: string): string
	return value:gsub("->", "-&gt;")
end

local function getDescriptionValues(definition: any, progression: any): { [string]: number }
	local abilityParams = progression and progression.abilityParams or {}
	local statModifiers = definition and definition.statModifiers or {}
	local add = statModifiers.Add or {}
	local multiply = statModifiers.Multiply or {}
	local passive = definition and definition.passiveAbility or {}
	local combatEffect = definition and definition.combatEffect or {}

	return {
		damage = tonumber(abilityParams.damage) or 0,
		cooldown = tonumber(abilityParams.cooldown) or tonumber(passive.params and passive.params.cooldown) or 0,
		weight = tonumber(abilityParams.weightMultiplier) or 1,
		hitbox = tonumber(abilityParams.hitboxMultiplier) or 1,
		duration = tonumber(abilityParams.collisionExtraDuration) or tonumber(combatEffect.collisionExtraDuration) or 0,
		slowDuration = tonumber(abilityParams.slowDuration) or tonumber(abilityParams.collisionExtraDuration) or 0,
		baseDamage = tonumber(add.baseDamage) or 0,
		maxHP = tonumber(add.maxHP) or 0,
		damageReduction = math.clamp(1 - (tonumber(abilityParams.damageMultiplier) or 1), 0, 1),
		expBonus = tonumber(abilityParams.expBonus) or tonumber(add.expBonus) or 0,
		moveSpeed = tonumber(add.moveSpeed) or 0,
		launchSpeed = tonumber(multiply.launchSpeed) or 1,
		launchCooldown = math.abs(tonumber(add.launchCooldown) or 0),
		reflectDamage = math.clamp(tonumber(add.reflectDamage) or tonumber(passive.percent) or 0, 0, 1),
		healAmount = tonumber(abilityParams.healAmount) or 0,
		tickInterval = tonumber(abilityParams.tickInterval) or tonumber(passive.params and passive.params.tickInterval) or 5,
	}
end

local PERCENT_KEYS = {
	damageReduction = true,
	expBonus = true,
	reflectDamage = true,
}

local MULTIPLIER_KEYS = {
	weight = true,
	hitbox = true,
	launchSpeed = true,
}

local function formatDescriptionValue(key: string, value: number): string
	if PERCENT_KEYS[key] then
		return string.format("%.0f%%", value * 100)
	end
	if MULTIPLIER_KEYS[key] then
		return string.format("%.2fx", value)
	end
	return formatNumber(value)
end

local function buildScriptText(definition: any, current: any, nextProgression: any, previewNextLevel: boolean, nextLevel: number, languageCode: string?): string
	local petId = definition and definition.PetId
	local template = PetAbilityDisplayConfig.GetTemplate(petId, languageCode)
	if not template then
		return if string.lower(languageCode or "en"):sub(1, 2) == "vi" then "Chưa có mô tả ability." else "Ability description unavailable."
	end

	local currentValues = getDescriptionValues(definition, current)
	local nextValues = getDescriptionValues(definition, nextProgression)
	local useNextValues = previewNextLevel and PetsUpgradeConfig.IsMilestone(nextLevel)

	local rendered = template:gsub("{([%w_]+)}", function(key)
		local currentValue = currentValues[key]
		if currentValue == nil then
			return "?"
		end
		local currentText = formatDescriptionValue(key, currentValue)
		local nextValue = nextValues[key]
		if useNextValues and type(nextValue) == "number" and math.abs(nextValue - currentValue) > 0.0001 then
			return string.format("%s <font color=\"#00ff00\">-&gt; %s</font>", currentText, formatDescriptionValue(key, nextValue))
		end
		return currentText
	end)
	return encodeRichText(rendered)
end

function PetDisplayFormatter.Format(definition: any, level: number, previewNextLevel: boolean, languageCode: string?): DisplayText
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	local isMaxLevel = safeLevel >= PetsUpgradeConfig.MaxLevel
	local current = definition and PetProgression.Resolve(definition, safeLevel) or nil
	local nextLevel = math.min(safeLevel + 1, PetsUpgradeConfig.MaxLevel)
	local nextProgression = definition and PetProgression.Resolve(definition, nextLevel) or nil
	local currentStats = current and current.baseStats or {}
	local nextStats = nextProgression and nextProgression.baseStats or {}
	local hp = tonumber(currentStats.maxHP)
	local damage = tonumber(currentStats.baseDamage)
	local nextHP = tonumber(nextStats.maxHP)
	local nextDamage = tonumber(nextStats.baseDamage)
	local showPreview = previewNextLevel and not isMaxLevel

	return {
		LevelText = if isMaxLevel then "Level: MAX" elseif showPreview then transition("Level", safeLevel, nextLevel) else string.format("Level: %d", safeLevel),
		HPText = hp and (if showPreview and nextHP then transition("HP", hp, nextHP) else "HP: " .. formatNumber(hp)) or "HP: -",
		DamageText = damage and (if showPreview and nextDamage then transition("Damage", damage, nextDamage) else "Damage: " .. formatNumber(damage)) or "Damage: -",
		ScriptText = buildScriptText(definition, current, nextProgression, showPreview, nextLevel, languageCode),
	}
end

return PetDisplayFormatter
