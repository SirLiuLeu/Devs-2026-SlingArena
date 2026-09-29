--!strict

-- Pure presentation helper for the Inventory pet details panel. It deliberately
-- returns text only so it can be exercised without creating GuiInstances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAbilityProgressionConfig = require(ReplicatedStorage.Shared.Config.PetAbilityProgressionConfig)
local PetProgression = require(ReplicatedStorage.Shared.Utils.PetProgression)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)

local PetDisplayFormatter = {}

export type DisplayText = {
	LevelText: string,
	HPText: string,
	DamageText: string,
	ScriptText: string,
}

local ABILITY_VALUE_KEYS = {
	ExpBonus = "expBonus",
	Shield = "damageMultiplier",
	Regeneration = "healAmount",
	Slow = "collisionExtraDuration",
	Titan = "sizeMultiplier",
}

local function formatNumber(value: number): string
	if value % 1 == 0 then return string.format("%.0f", value) end
	return string.format("%.2f", value)
end

local function formatAbilityValue(value: number, format: string?): string
	if format == "percent" then return string.format("%.0f%%", value * 100) end
	return formatNumber(value)
end

local function encodeRichText(text: string): string
	-- Templates are config data, but arrows must be encoded when RichText is on.
	local encoded = text:gsub("->", "-&gt;")
	return encoded
end

local function transition(label: string, currentValue: number, nextValue: number): string
	return string.format("%s: %s <font color=\"#00ff00\">-&gt; %s</font>", label, formatNumber(currentValue), formatNumber(nextValue))
end

function PetDisplayFormatter.Format(definition: any, level: number, previewNextLevel: boolean, languageCode: string?): DisplayText
	local safeLevel = PetsUpgradeConfig.NormalizeLevel(level)
	local isMaxLevel = safeLevel >= PetsUpgradeConfig.MaxLevel
	local current = definition and PetProgression.Resolve(definition, safeLevel) or nil
	local nextLevel = math.min(safeLevel + 1, PetsUpgradeConfig.MaxLevel)
	local next = definition and PetProgression.Resolve(definition, nextLevel) or nil
	local currentStats = current and current.baseStats or {}
	local nextStats = next and next.baseStats or {}
	local hp = tonumber(currentStats.maxHP)
	local damage = tonumber(currentStats.baseDamage)
	local nextHP = tonumber(nextStats.maxHP)
	local nextDamage = tonumber(nextStats.baseDamage)
	local showPreview = previewNextLevel and not isMaxLevel

	local result: DisplayText = {
		LevelText = if isMaxLevel then "Level: MAX" elseif showPreview then transition("Level", safeLevel, nextLevel) else string.format("Level: %d", safeLevel),
		HPText = hp and (if showPreview and nextHP then transition("HP", hp, nextHP) else "HP: " .. formatNumber(hp)) or "HP: -",
		DamageText = damage and (if showPreview and nextDamage then transition("Damage", damage, nextDamage) else "Damage: " .. formatNumber(damage)) or "Damage: -",
		ScriptText = "Script: " .. tostring(definition and definition.abilityId or "-"),
	}

	local abilityId = definition and definition.abilityId
	local display = PetAbilityProgressionConfig.GetDisplay(abilityId)
	local statName = abilityId and ABILITY_VALUE_KEYS[abilityId]
	local currentValue = statName and tonumber(current and current.abilityParams[statName]) or nil
	local nextValue = statName and tonumber(next and next.abilityParams[statName]) or nil
	if not display or not currentValue or not nextValue then return result end

	local locale = string.lower(languageCode or "en")
	local template = display.Templates[locale] or display.Templates[string.sub(locale, 1, 2)] or display.Templates.en
	if type(template) ~= "string" then return result end

	-- Ability templates describe their current and next milestone values. During a
	-- normal view, a non-milestone level remains standard text; only a preview
	-- into a milestone is rendered as a changing ability value.
	local useNextValue = showPreview and PetsUpgradeConfig.IsMilestone(nextLevel)
	local renderedNextValue = if useNextValue then nextValue else currentValue
	result.ScriptText = encodeRichText((template
		:gsub("{current}", formatAbilityValue(currentValue, display.Format))
		:gsub("{next}", formatAbilityValue(renderedNextValue, display.Format))))
	return result
end

return PetDisplayFormatter
