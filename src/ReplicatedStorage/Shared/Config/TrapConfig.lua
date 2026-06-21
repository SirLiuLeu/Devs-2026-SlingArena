--!strict

return {
	Types = {
		SpikeTrap = {
			Behavior = "HitCooldown",
			Damage = 1500,
			Cooldown = 1.5,
			ExpPenaltyOnHit = 40,
			PopupText = "Spike hit! -1500 HP",
			Knockback = 55,
			UpwardBoost = 10,
			KnockbackDirection = "AwayFromTrap",
		},
		LavaTrap = {
			Behavior = "ContactDot",
			Flag = "LavaTrap",
			TickInterval = 0.5,
			DamagePerTick = 0.1,
			ExpPenaltyOnHit = 40,
			ContactSlowAmount = 0.25,
			ContactSlowDuration = 0.75,
			MaxStack = 1,
			PopupText = "Lava burn!",
		},
	},
}
