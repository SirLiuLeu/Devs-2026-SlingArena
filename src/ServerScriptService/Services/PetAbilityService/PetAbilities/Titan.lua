--!strict

local SIZE_MULTIPLIER_ATTRIBUTE = "PetTitanSizeMultiplier"
local INCOMING_KNOCKBACK_ATTRIBUTE = "PetIncomingKnockbackMultiplier"
local OUTGOING_KNOCKBACK_ATTRIBUTE = "PetOutgoingKnockbackMultiplier"

local Titan = {}

function Titan.OnLaunch(_context, _payload) end
function Titan.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function Titan.OnTick(_context, _dt: number) end
function Titan.OnAttack(_context, _payload: any) end

function Titan.OnInit(context)
	local params = context.progression and context.progression.abilityParams or {}
	context._sizeMultiplier = math.max(0, tonumber(params.sizeMultiplier) or 1)
	context._incomingKnockbackMultiplier = math.max(0, tonumber(params.incomingKnockbackMultiplier) or 1)
	context._outgoingKnockbackMultiplier = math.max(0, tonumber(params.outgoingKnockbackMultiplier) or 1)
	context.player:SetAttribute(SIZE_MULTIPLIER_ATTRIBUTE, context._sizeMultiplier)
	context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, context._incomingKnockbackMultiplier)
	context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, context._outgoingKnockbackMultiplier)
end

function Titan.OnDestroy(context)
	if context.player:GetAttribute(SIZE_MULTIPLIER_ATTRIBUTE) == context._sizeMultiplier then context.player:SetAttribute(SIZE_MULTIPLIER_ATTRIBUTE, nil) end
	if context.player:GetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE) == context._incomingKnockbackMultiplier then context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, nil) end
	if context.player:GetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE) == context._outgoingKnockbackMultiplier then context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, nil) end
end

return Titan
