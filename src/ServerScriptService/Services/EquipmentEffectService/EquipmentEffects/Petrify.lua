--!strict
local EffectUtil = require(script.Parent.EffectUtil)
local Petrify = {}
function Petrify.OnCollision(context, collisionType: string, target: any, payload: any)
	if collisionType ~= "Player" or not target then return end
	if not EffectUtil.CanAffectPlayers(context, context.player, target) then return end
	local dataService = context.PlayerDataService
	local equipped = dataService and dataService:GetEquippedEquipment(target) or {}
	local immune = (context.definition.combatEffect or {}).cannotPetrifyEquipmentIds or {}
	local ownedEquipment = dataService and dataService:GetOwnedEquipment(target) or {}
	for _, instanceId in pairs(equipped) do
		local owned = ownedEquipment[instanceId]
		if owned and immune[tostring(owned.definitionId)] then return end
	end
	EffectUtil.ApplyCollisionFlag(context, target, payload)
end
return Petrify
