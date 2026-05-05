--!strict

return {
	Charge = {
		MinSeconds = 0.15,
		MaxSeconds = 1.4,
	},
	Duration = {
		Min = 1.0,
		Max = 3.0,
		FullSpeedRatio = 0.6,
		DecayRatio = 0.4,
	},
	Speed = {
		Min = 36,
		Max = 108,
		StopThreshold = 3.5,
	},
	Energy = {
		Min = 28,
		Max = 120,
		PassiveDecayPerSecond = 0.12,
		CollisionLossRatio = 0.28,
		TransferRatio = 0.58,
		ChainHitDecayMultiplier = 0.82,
		MinTransferEnergy = 8,
	},
	Collision = {
		MinImpactSpeed = 6,
		NormalBounce = 0.78,
		TangentialRetention = 0.92,
		MaxTransferSpeed = 90,
	},
	Damage = {
		BaseMultiplier = 1.0,
		LaunchTimeBias = 0.55,
		CollisionIntensityMultiplier = 1.4,
		ChainDecayPerHit = 0.22,
		Max = 420,
	},
}
