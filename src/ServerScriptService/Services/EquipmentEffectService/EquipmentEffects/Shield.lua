--!strict

local DAMAGE_MULTIPLIER_ATTRIBUTE = "EquipmentShieldDamageMultiplier"
local DAMAGE_MULTIPLIER = 0.8

local Shield = {}

function Shield.OnLaunch(_context, _payload) end
function Shield.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function Shield.OnTick(_context, _dt: number) end
function Shield.OnAttack(_context, _payload: any) end

function Shield.OnInit(context)
	context.player:SetAttribute(DAMAGE_MULTIPLIER_ATTRIBUTE, DAMAGE_MULTIPLIER)
end

function Shield.OnDestroy(context)
	if context.player:GetAttribute(DAMAGE_MULTIPLIER_ATTRIBUTE) == DAMAGE_MULTIPLIER then
		context.player:SetAttribute(DAMAGE_MULTIPLIER_ATTRIBUTE, nil)
	end
end

return Shield
