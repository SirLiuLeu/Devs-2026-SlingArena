--!strict

return {
	ExpPenalty = 40,
	Types = {
		SpikeTrap = {
			Behavior = "HitCooldown",
			PartNames = { "Core", "Spike" },
			Damage = 1500,
			Cooldown = 1.5,
			PopupText = "Spike hit! -1500 HP",
			Knockback = 55,
			UpwardBoost = 10,
		},
		LavaTrap = {
			Behavior = "ContactDot",
			Enabled = true,
			PartNames = { "LavaFloor", "Lava" },
			Flag = "LavaTrap",
			TickInterval = 0.5,
			DamagePerTick = { Mode = "MaxHPPercent", Percent = 0.1, Fallback = 1000 },
			Slow = 0.25,
			EffectDuration = 0.75,
			PopupText = "Lava burn!",
		},
	},
}
