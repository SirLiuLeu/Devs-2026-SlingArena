--!strict

local Vacuum = {}

function Vacuum.OnLaunch(_player: Player, context)
	return {
		Event = "AbilityVacuumPulse",
		Payload = {
			Center = context.RootPosition,
			Radius = 22,
		},
	}
end

function Vacuum.OnCollision(_player: Player, _context)
	return nil
end

function Vacuum.Passive(_player: Player, _context)
	return nil
end

return Vacuum
