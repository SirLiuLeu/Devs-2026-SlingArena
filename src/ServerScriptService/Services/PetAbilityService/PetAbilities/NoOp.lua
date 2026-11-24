--!strict

local NoOp = {}

local function diagnostic(context, lifecycle: string)
	local params = context.definition and context.definition.effectParams
	local message = type(params) == "table" and params.diagnostic or nil
	if type(message) == "string" and message ~= "" then
		warn(string.format("[PET_EFFECT][%s] %s (%s)", lifecycle, message, tostring(context.definition.type)))
	end
end

function NoOp.OnInit(context)
	context.initialized = true
	diagnostic(context, "OnInit")
end
function NoOp.OnLaunch(context, _payload) diagnostic(context, "OnLaunch") end
function NoOp.OnCollision(context, _collisionType, _target, _payload) diagnostic(context, "OnCollision") end
function NoOp.OnTick(context, dt) context.ticks = (context.ticks or 0) + 1; context.lastDt = dt end
function NoOp.OnAttack(context, _payload) diagnostic(context, "OnAttack") end
function NoOp.OnDestroy(context) context.destroyed = true end

return NoOp
