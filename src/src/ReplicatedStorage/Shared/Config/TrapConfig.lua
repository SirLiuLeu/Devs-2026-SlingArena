--!strict

return {
	ScanInterval = 0.1,
	Types = {
		SpikeTrap = {
			Behavior = "HitCooldown",
			Damage = 1500,
			Cooldown = 1.5,
			DetectionPadding = 3,
			PopupText = "Spike hit! -1500 HP",
		},
		LavaTrap = {
			Behavior = "ContactDot",
			Flag = "LavaTrap",
			TickInterval = 0.5,
			DamagePerTick = 0.1,
			DetectionPadding = 3,
			ContactSlowAmount = 0.25,
			ContactSlowDuration = 0.75,
			MaxStack = 1,
			PopupText = "Lava burn!",
		},
	},
}
