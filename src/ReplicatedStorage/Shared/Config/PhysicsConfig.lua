--!strict

-- Shared physics tuning. Server is authoritative for collision/damage, while clients may
-- read this module for prediction/UI so visible feel stays in sync with server physics.
local PhysicsConfig = {
	PhysicalProperties = {
		Density = 0.7,
		Friction = 0.02,
		Elasticity = 0.82,
		FrictionWeight = 0,
		ElasticityWeight = 1,
	},

	Movement = {
		MoveSpeed = 20,
		MaxForce = 3000,
	},

	World = {
		MaxArenaRadius = 300,
		ArenaWallPadding = 6,
		LinearDragPerSecond = 0.08,
		StopSpeed = 0.35,
		WallRestitution = 0.78,
		WallTangentialDamping = 0.98,
		WallCollisionCooldown = 0.2,
	},

	Charge = {
		MaxSeconds = 1.4,
	},

	Launch = {
		SpeedMin = 36,
		SpeedMax = 112,
		EnergyMin = 28,
		EnergyMax = 120,
		PassiveEnergyDecayPerSecond = 0.035,
		StopSpeed = 1.1,
	},

	Collision = {
		CandidateDistanceFactor = 0.25,
		CandidateExtraPadding = 0.35,
		Cooldown = 0.28,
		RealHitMinClosingSpeed = 5.5,
		MinLaunchEnergy = 5,
		Restitution = 0.92,
		TangentialDamping = 0.94,
		EnergyTransferRatio = 0.82,
		CollisionEnergyLossRatio = 0.16,
		ChainHitEnergyRetention = 0.78,
		MinTransferEnergy = 7,
		MinPostCollisionSpeed = 1.25,
		MaxPostCollisionSpeed = 125,
	},

	Damage = {
		BaseMultiplier = 1.0,
		LaunchTimeBias = 0.45,
		CollisionIntensityMultiplier = 1.15,
		ChainDecayPerHit = 0.18,
		Max = 420,
	},

	Stability = {
		UseInfiniteForce = true,
	},
}

return PhysicsConfig
