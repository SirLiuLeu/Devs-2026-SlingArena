--!strict

return {
	ExpPenalty = 40,
	TriggerCooldown = 1.5,
	Types = {
		SpikeTrap = {
			Flag = "PoisonTrap",
			Duration = 5,
			TickInterval = 1,
			DamagePerTick = 150,
			MaxStack = 5,
			ImmediateTick = false,
		},
		LavaBase = {
			Flag = "LavaTrap",
			Duration = 10,
			TickInterval = 0.5,
			DamagePerTick = { Mode = "MaxHPPercent", Percent = 0.2, Fallback = 2000 },
			MaxStack = 10,
			ImmediateTick = true,
		},
	},
}
