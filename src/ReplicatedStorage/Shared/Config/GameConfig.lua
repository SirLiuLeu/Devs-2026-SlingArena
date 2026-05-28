--!strict

local GameConfig = {
	FlagConfig = {
		Ghost = { Duration = 9999, Priority = 90, BlocksCollision = true, BlocksDamage = true },
		Invulnerable = { Duration = 5, Priority = 100, BlocksDamage = true, BlocksDot = true },
		Petrify = { Duration = 1.5, Priority = 80, Stackable = false, InterruptCharge = true },
		Stun = { Duration = 1, Priority = 70, Stackable = false, InterruptCharge = true },
		Slow = { Duration = 3, Priority = 50, Stackable = true, MaxStack = 3, SlowAmount = 0.25 },
		Burn = { Duration = 4, Stackable = true, MaxStack = 3, TickInterval = 1, DamagePerTick = 250 },
		Poison = { Duration = 5, Stackable = true, MaxStack = 5, TickInterval = 1, DamagePerTick = 150, SlowAmount = 0.25, SlowDuration = 3 },
		PoisonSpike = { Duration = 5, Stackable = true, MaxStack = 5, TickInterval = 1, DamagePerTick = 150 },
		Invisible = { Duration = 1, Priority = 10 },
		Recovering = { Duration = 5 },
	},
}

return GameConfig
