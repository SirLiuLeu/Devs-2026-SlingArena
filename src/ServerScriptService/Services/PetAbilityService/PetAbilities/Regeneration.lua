--!strict

local Regeneration = {}

function Regeneration.OnInit(context)
	local params = context.progression and context.progression.abilityParams or {}
	context._regenAmount = math.max(0, tonumber(params.healAmount) or 0)
	context._regenInterval = math.max(0.1, tonumber(params.tickInterval) or 5)
	context._regenElapsed = 0
end

function Regeneration.OnTick(context, dt: number)
	context._regenElapsed = (context._regenElapsed or 0) + dt
	if context._regenElapsed < (context._regenInterval or 5) then return end
	context._regenElapsed = 0
	local stateService = context.PlayerStateService
	if stateService and typeof(stateService.Heal) == "function" then
		stateService:Heal(context.player, context._regenAmount or 0)
	end
end

return Regeneration
