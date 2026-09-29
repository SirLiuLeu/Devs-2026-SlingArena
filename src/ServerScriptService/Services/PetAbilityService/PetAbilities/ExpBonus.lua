--!strict

local ExpBonus = {}

function ExpBonus.OnInit(context)
	local params = context.progression and context.progression.abilityParams or {}
	context.expBonus = math.max(0, tonumber(params.expBonus) or 0)
end

return ExpBonus
