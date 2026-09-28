--!strict

local DAMAGE_MULTIPLIER_ATTRIBUTE = "PetShieldDamageMultiplier"

local Shield = {}

function Shield.OnLaunch(_context, _payload) end
function Shield.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function Shield.OnTick(_context, _dt: number) end
function Shield.OnAttack(_context, _payload: any) end

function Shield.OnInit(context)
	local params = context.progression and context.progression.abilityParams or {}
	context._damageMultiplier = math.clamp(tonumber(params.damageMultiplier) or 1, 0, 1)
	context.player:SetAttribute(DAMAGE_MULTIPLIER_ATTRIBUTE, context._damageMultiplier)
end

function Shield.OnDestroy(context)
	if context.player:GetAttribute(DAMAGE_MULTIPLIER_ATTRIBUTE) == context._damageMultiplier then
		context.player:SetAttribute(DAMAGE_MULTIPLIER_ATTRIBUTE, nil)
	end
end

return Shield
