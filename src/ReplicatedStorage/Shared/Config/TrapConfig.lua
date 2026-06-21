--!strict

return {
	ExpPenalty = 40,
	TriggerCooldown = 1.5,
	Types = {
		SpikeTrap = {
			PartName = "SpikeTrap",
			Flag = "SpikeTrap",
			ImpactDamage = 15,
			PopupText = "Trap hit! -15 HP",
			Knockback = 55,
			UpwardBoost = 10,
		},
		LavaTrap = {
			PartName = "LavaBase",
			Flag = "LavaTrap",
			ImmediateTick = true,
			PopupText = "Lava burn!",
			Knockback = 0,
			UpwardBoost = 0,
		},
	},
}
