--!strict
local EffectUtil = require(script.Parent.EffectUtil)
local Petrify = {}
function Petrify.OnCollision(context, collisionType: string, target: any, payload: any)
	print(string.format("[EQUIPMENT_ATTACK_TRACE][Medusa] OnCollision fired attacker=%s type=%s target=%s", context.player.Name, collisionType, target and target.Name or "nil"))
	if collisionType ~= "Player" or not target then
		print("[EQUIPMENT_ATTACK_TRACE][Medusa] OnCollision aborted: expected a player target")
		return
	end
	if not EffectUtil.CanAffectPlayers(context, context.player, target) then
		print("[EQUIPMENT_ATTACK_TRACE][Medusa] OnCollision aborted: target cannot be affected")
		return
	end
	local dataService = context.PlayerDataService
	local equipped = dataService and dataService:GetEquippedEquipment(target) or {}
	local immune = (context.definition.combatEffect or {}).cannotPetrifyEquipmentIds or {}
	local ownedEquipment = dataService and dataService:GetOwnedEquipment(target) or {}
	for _, instanceId in pairs(equipped) do
		local owned = ownedEquipment[instanceId]
		if owned and immune[tostring(owned.definitionId)] then
			print(string.format("[EQUIPMENT_ATTACK_TRACE][Medusa] OnCollision aborted: target=%s has petrify immunity from %s", target.Name, tostring(owned.definitionId)))
			return
		end
	end
	EffectUtil.ApplyCollisionFlag(context, target, payload)
end
return Petrify
