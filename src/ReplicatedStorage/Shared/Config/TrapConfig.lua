--!strict

return {
	ScanInterval = 0.1,
	Types = {
		LavaTrap = {
			Behavior = "ContactRamp",
			Flag = "LavaTrap",
			DamageInterval = 0.3,
			DamagePerStack = 100,
			MaxDamagePerTick = 2000,
			DetectionPadding = 1,
			ContactSlowAmount = 0.25,
			ContactSlowDuration = 0.75,
			PopupText = "Lava burn!",
		},
	},
}
