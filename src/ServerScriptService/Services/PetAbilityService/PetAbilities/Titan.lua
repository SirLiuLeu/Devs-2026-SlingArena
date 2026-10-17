--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetAbilityProgressionConfig = require(ReplicatedStorage.Shared.Config.PetAbilityProgressionConfig)

local WEIGHT_MULTIPLIER_ATTRIBUTE = "PetTitanWeightMultiplier"
local HITBOX_MULTIPLIER_ATTRIBUTE = "PetTitanHitboxMultiplier"
local VISUAL_MULTIPLIER_ATTRIBUTE = "PetTitanVisualMultiplier"
local VISUAL_GROWTH_LEVELS_ATTRIBUTE = "PetTitanVisualGrowthLevels"
local INCOMING_KNOCKBACK_ATTRIBUTE = "PetIncomingKnockbackMultiplier"
local OUTGOING_KNOCKBACK_ATTRIBUTE = "PetOutgoingKnockbackMultiplier"

local Titan = {}

function Titan.OnLaunch(_context, _payload) end
function Titan.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function Titan.OnTick(_context, _dt: number) end
function Titan.OnAttack(_context, _payload: any) end

function Titan.OnInit(context)
	local params = context.progression and context.progression.abilityParams or {}
	context._weightMultiplier = math.clamp(tonumber(params.weightMultiplier) or 1, 1, 1.5)
	context._hitboxMultiplier = math.clamp(tonumber(params.hitboxMultiplier) or 1, 1, 1.5)
	-- No credit for player levels gained before Titan became active.
	context._visualMultiplier = 1
	context._visualGrowthLevels = 0
	context._incomingKnockbackMultiplier = math.max(0, tonumber(params.incomingKnockbackMultiplier) or 1)
	context._outgoingKnockbackMultiplier = math.max(0, tonumber(params.outgoingKnockbackMultiplier) or 1)
	context.player:SetAttribute(WEIGHT_MULTIPLIER_ATTRIBUTE, context._weightMultiplier)
	context.player:SetAttribute(HITBOX_MULTIPLIER_ATTRIBUTE, context._hitboxMultiplier)
	context.player:SetAttribute(VISUAL_MULTIPLIER_ATTRIBUTE, context._visualMultiplier)
	context.player:SetAttribute(VISUAL_GROWTH_LEVELS_ATTRIBUTE, context._visualGrowthLevels)
	context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, context._incomingKnockbackMultiplier)
	context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, context._outgoingKnockbackMultiplier)
end

function Titan.OnLevelUp(context, playerLevel: number)
	if typeof(context._visualMultiplier) ~= "number" then return end
	local previousFactor = context._visualMultiplier
	local nextFactor = math.min(
		PetAbilityProgressionConfig.TitanVisualMultiplierCap,
		previousFactor + PetAbilityProgressionConfig.TitanVisualGrowthPerPlayerLevel
	)
	if nextFactor <= previousFactor then return end
	context._visualMultiplier = nextFactor
	context._visualGrowthLevels = (context._visualGrowthLevels or 0) + 1
	context.player:SetAttribute(VISUAL_MULTIPLIER_ATTRIBUTE, nextFactor)
	context.player:SetAttribute(VISUAL_GROWTH_LEVELS_ATTRIBUTE, context._visualGrowthLevels)
	print(string.format(
		"[TITAN_VISUAL_GROWTH_EARNED] player=%s playerLevel=%d factor=%.4fx earnedLevels=%d",
		context.player.Name,
		math.floor(tonumber(playerLevel) or 0),
		nextFactor,
		context._visualGrowthLevels
	))
end

function Titan.OnDestroy(context)
	if context.player:GetAttribute(WEIGHT_MULTIPLIER_ATTRIBUTE) == context._weightMultiplier then context.player:SetAttribute(WEIGHT_MULTIPLIER_ATTRIBUTE, nil) end
	if context.player:GetAttribute(HITBOX_MULTIPLIER_ATTRIBUTE) == context._hitboxMultiplier then context.player:SetAttribute(HITBOX_MULTIPLIER_ATTRIBUTE, nil) end
	if context.player:GetAttribute(VISUAL_MULTIPLIER_ATTRIBUTE) == context._visualMultiplier then context.player:SetAttribute(VISUAL_MULTIPLIER_ATTRIBUTE, nil) end
	if context.player:GetAttribute(VISUAL_GROWTH_LEVELS_ATTRIBUTE) == context._visualGrowthLevels then context.player:SetAttribute(VISUAL_GROWTH_LEVELS_ATTRIBUTE, nil) end
	if context.player:GetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE) == context._incomingKnockbackMultiplier then context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, nil) end
	if context.player:GetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE) == context._outgoingKnockbackMultiplier then context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, nil) end
end

return Titan
