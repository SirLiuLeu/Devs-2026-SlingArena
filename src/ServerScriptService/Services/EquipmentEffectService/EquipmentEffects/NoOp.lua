--!strict

local NoOp = {}

function NoOp.OnInit(context) context.initialized = true end
function NoOp.OnLaunch(_context, _payload) end
function NoOp.OnCollision(_context, _collisionType, _target, _payload) end
function NoOp.OnTick(context, dt) context.ticks = (context.ticks or 0) + 1; context.lastDt = dt end
function NoOp.OnAttack(_context, _payload) end
function NoOp.OnDestroy(context) context.destroyed = true end

return NoOp
