--!strict

local Stun = {}

function Stun.OnLaunch(_player: Player, _context)
	return nil
end

function Stun.OnCollision(_player: Player, context)
	if not context.TargetPlayer then
		return nil
	end
	return {
		ApplyStunTo = context.TargetPlayer,
		Duration = 1,
	}
end

function Stun.Passive(_player: Player, _context)
	return nil
end

return Stun
