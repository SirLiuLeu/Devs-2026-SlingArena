--!strict
local ExpBonus = {}
function ExpBonus.OnInit(context)
	local passive = context.definition.passiveAbility
	context.expBonus = passive and (passive.value or (passive.params and passive.params.expBonus)) or 0
end
return ExpBonus
