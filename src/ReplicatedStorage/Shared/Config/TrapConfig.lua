--!strict

return {
	ExpPenalty = 40,
	TriggerCooldown = 1.5,
	SpikeTriggerCooldown = 1.5,
	Types = {
		SpikeTrap = {
			PartNames = { "Core", "Spike" },
			ImpactDamage = 1500,
			TriggerCooldown = 1.5,
			PopupText = "Spike hit! -1500 HP",
			Knockback = 55,
			UpwardBoost = 10,
		},
		LavaTrap = {
			Enabled = true,
			PartNames = { "LavaFloor", "Lava" },
			Flag = "LavaTrap",
			UsesDot = true,
			PopupText = "Lava burn!",
			Knockback = 0,
			UpwardBoost = 0,
		},
	},
}
