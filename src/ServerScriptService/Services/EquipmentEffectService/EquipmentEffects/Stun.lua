--!strict
local EffectUtil = require(script.Parent.EffectUtil)
local CollisionFlag = {}
function CollisionFlag.OnCollision(context, collisionType: string, target: any, payload: any)
	print(string.format("[EQUIPMENT_ATTACK_TRACE][ThunderHammer] OnCollision fired attacker=%s type=%s target=%s", context.player.Name, collisionType, target and target.Name or "nil"))
	if collisionType ~= "Player" or not target then
		print("[EQUIPMENT_ATTACK_TRACE][ThunderHammer] OnCollision aborted: expected a player target")
		return
	end
	if not EffectUtil.CanAffectPlayers(context, context.player, target) then
		print("[EQUIPMENT_ATTACK_TRACE][ThunderHammer] OnCollision aborted: target cannot be affected")
		return
	end
	EffectUtil.ApplyCollisionFlag(context, target, payload)
end
return CollisionFlag
