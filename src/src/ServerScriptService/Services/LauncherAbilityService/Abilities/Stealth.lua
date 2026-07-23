--!strict

local Stealth = {}

function Stealth.OnLaunch(_player: Player, _context)
	return {
		SetVisibility = false,
		VisibilityDuration = 1,
	}
end

function Stealth.OnCollision(_player: Player, _context)
	return nil
end

function Stealth.Passive(_player: Player, _context)
	return nil
end

return Stealth
