--!strict

local SIZE_MULTIPLIER_ATTRIBUTE = "PetTitanSizeMultiplier"
local HITBOX_MULTIPLIER_ATTRIBUTE = "PetTitanHitboxMultiplier"
local WEIGHT_MULTIPLIER_ATTRIBUTE = "PetTitanWeightMultiplier"
local INCOMING_KNOCKBACK_ATTRIBUTE = "PetIncomingKnockbackMultiplier"
local OUTGOING_KNOCKBACK_ATTRIBUTE = "PetOutgoingKnockbackMultiplier"

local Titan = {}

function Titan.OnLaunch(_context, _payload) end
function Titan.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function Titan.OnTick(_context, _dt: number) end
function Titan.OnAttack(_context, _payload: any) end

function Titan.OnInit(context)
	local params = context.progression and context.progression.abilityParams or {}
	context._sizeMultiplier = math.clamp(tonumber(params.visualMultiplier or params.sizeMultiplier) or 1, 1, 2)
	context._hitboxMultiplier = math.clamp(tonumber(params.hitboxMultiplier) or 1, 1, 1.5)
	context._weightMultiplier = math.clamp(tonumber(params.weightMultiplier) or 1, 1, 1.5)
	context._incomingKnockbackMultiplier = math.clamp(tonumber(params.incomingKnockbackMultiplier) or 1, 0, 1)
	context._outgoingKnockbackMultiplier = math.clamp(tonumber(params.outgoingKnockbackMultiplier) or 1, 0, 2)
	context.player:SetAttribute(SIZE_MULTIPLIER_ATTRIBUTE, context._sizeMultiplier)
	context.player:SetAttribute(HITBOX_MULTIPLIER_ATTRIBUTE, context._hitboxMultiplier)
	context.player:SetAttribute(WEIGHT_MULTIPLIER_ATTRIBUTE, context._weightMultiplier)
	context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, context._incomingKnockbackMultiplier)
	context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, context._outgoingKnockbackMultiplier)
	if context.PlayerService and typeof(context.PlayerService.RefreshPetScaling) == "function" then
		context.PlayerService:RefreshPetScaling(context.player)
	end
end

function Titan.OnDestroy(context)
	local attributes = {
		{ NAME = SIZE_MULTIPLIER_ATTRIBUTE, VALUE = context._sizeMultiplier },
		{ NAME = HITBOX_MULTIPLIER_ATTRIBUTE, VALUE = context._hitboxMultiplier },
		{ NAME = WEIGHT_MULTIPLIER_ATTRIBUTE, VALUE = context._weightMultiplier },
		{ NAME = INCOMING_KNOCKBACK_ATTRIBUTE, VALUE = context._incomingKnockbackMultiplier },
		{ NAME = OUTGOING_KNOCKBACK_ATTRIBUTE, VALUE = context._outgoingKnockbackMultiplier },
	}
	for _, entry in ipairs(attributes) do
		if context.player:GetAttribute(entry.NAME) == entry.VALUE then
			context.player:SetAttribute(entry.NAME, nil)
		end
	end
	if context.PlayerService and typeof(context.PlayerService.RefreshPetScaling) == "function" then
		context.PlayerService:RefreshPetScaling(context.player)
	end
end

return Titan
