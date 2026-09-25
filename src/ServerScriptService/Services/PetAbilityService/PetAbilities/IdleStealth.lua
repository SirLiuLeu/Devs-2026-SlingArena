--!strict

local IdleStealth = {}

function IdleStealth.OnInit(context)
	local params = (context.definition.passiveAbility and context.definition.passiveAbility.params) or {}
	context._idleSeconds = math.max(0, tonumber(params.idleSeconds) or 5)
	context._idleElapsed = 0
	context._isInvisible = false
end

local function reveal(context)
	if not context._isInvisible then return end
	local stateService = context.PlayerStateService
	if stateService and typeof(stateService.RemoveFlag) == "function" then
		stateService:RemoveFlag(context.player, "Invisible")
	end
	context._isInvisible = false
	context._idleElapsed = 0
end

function IdleStealth.OnLaunch(context, _payload)
	reveal(context)
end

function IdleStealth.OnCollision(context, _collisionType, _target, _payload)
	reveal(context)
end

function IdleStealth.OnAttack(context, _payload)
	reveal(context)
end

function IdleStealth.OnTick(context, dt: number)
	if context._isInvisible then return end
	context._idleElapsed = (context._idleElapsed or 0) + dt
	if context._idleElapsed >= (context._idleSeconds or 5) then
		local stateService = context.PlayerStateService
		if stateService and typeof(stateService.ApplyFlag) == "function" then
			stateService:ApplyFlag(context.player, "Invisible", 9999, context.player)
			context._isInvisible = true
		end
	end
end

function IdleStealth.OnDestroy(context)
	reveal(context)
end

return IdleStealth
