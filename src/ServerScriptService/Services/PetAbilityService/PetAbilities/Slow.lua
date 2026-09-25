--!strict
local EffectUtil = require(script.Parent.EffectUtil)
local CollisionFlag = {}
function CollisionFlag.OnCollision(context, collisionType: string, target: any, payload: any)
	if collisionType ~= "Player" or not target then return end
	if not EffectUtil.CanAffectPlayers(context, context.player, target) then return end
	EffectUtil.ApplyCollisionFlag(context, target, payload)
end
return CollisionFlag
