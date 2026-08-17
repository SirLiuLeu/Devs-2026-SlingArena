--!strict

local SIZE_MULTIPLIER_ATTRIBUTE = "EquipmentTitanSizeMultiplier"
local INCOMING_KNOCKBACK_ATTRIBUTE = "EquipmentIncomingKnockbackMultiplier"
local OUTGOING_KNOCKBACK_ATTRIBUTE = "EquipmentOutgoingKnockbackMultiplier"

local SIZE_MULTIPLIER = 1.2
local INCOMING_KNOCKBACK_MULTIPLIER = 0.75
local OUTGOING_KNOCKBACK_MULTIPLIER = 1.25

local Titan = {}

function Titan.OnLaunch(_context, _payload) end
function Titan.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function Titan.OnTick(_context, _dt: number) end
function Titan.OnAttack(_context, _payload: any) end

function Titan.OnInit(context)
	context.player:SetAttribute(SIZE_MULTIPLIER_ATTRIBUTE, SIZE_MULTIPLIER)
	context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, INCOMING_KNOCKBACK_MULTIPLIER)
	context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, OUTGOING_KNOCKBACK_MULTIPLIER)
end

function Titan.OnDestroy(context)
	if context.player:GetAttribute(SIZE_MULTIPLIER_ATTRIBUTE) == SIZE_MULTIPLIER then
		context.player:SetAttribute(SIZE_MULTIPLIER_ATTRIBUTE, nil)
	end
	if context.player:GetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE) == INCOMING_KNOCKBACK_MULTIPLIER then
		context.player:SetAttribute(INCOMING_KNOCKBACK_ATTRIBUTE, nil)
	end
	if context.player:GetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE) == OUTGOING_KNOCKBACK_MULTIPLIER then
		context.player:SetAttribute(OUTGOING_KNOCKBACK_ATTRIBUTE, nil)
	end
end

return Titan
