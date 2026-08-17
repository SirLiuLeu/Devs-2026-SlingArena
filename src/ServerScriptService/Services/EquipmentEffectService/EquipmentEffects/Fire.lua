--!strict
local EffectUtil = require(script.Parent.EffectUtil)

local Dot = {}

function Dot.OnCollision(context, collisionType: string, target: any, _payload: any)
	if collisionType == "Player" and target then
		if not EffectUtil.CanAffectPlayers(context, context.player, target) then return end
		EffectUtil.ApplyDotFlag(context, target)
	elseif collisionType == "Food" and target and typeof(target) == "Instance" and target:IsA("Model") then
		local stateService = context.PlayerStateService
		if stateService and stateService:IsHuman(context.player) then return end
		EffectUtil.ApplyFoodDot(context, target)
	end
end

function Dot.OnTick(context, _dt: number)
	EffectUtil.TickFoodDots(context)
end

return Dot
