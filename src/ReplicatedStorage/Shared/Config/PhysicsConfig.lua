--!strict

-- Shared physics tuning. Server is authoritative for collision/damage, while clients may
-- read this module for prediction/UI so visible feel stays in sync with server physics.
local PhysicsConfig = {
	PhysicalProperties = {
		Density = 0.7,
		Friction = 0.02,
		Elasticity = 0.8,
		FrictionWeight = 0,
		ElasticityWeight = 0.1,
	},

	Movement = {
		MoveSpeed = 15,
		MaxForce = 1000,
		InputDeadzone = 0.001,
		AimDeadzone = 0.01,
		MoveRequestCooldown = 0.03,
		MoveSendInterval = 0.05,
		MobileDeadzone = 0.15,
		SlowPerStack = 0.25,
		PreservedMomentumScale = 0.25,
	},

	World = {
		MaxArenaRadius = 300,
		ArenaWallPadding = 6,
		-- Drag only applies to non-Launching players (normal movement).
		-- Launch has its own dedicated VectorForce drag; see Launch.*Drag* below.
		LinearDragPerSecond = 0.08,
		StopSpeed = 0.35,
		WallRestitution = 0.78,
		WallTangentialDamping = 0.98,
		WallCollisionCooldown = 0.2,
	},

	Charge = {
		MaxSeconds = 1.4,
		MinWindowSeconds = 0.001,
		MaxChargeRatioThreshold = 0.999,
	},

	Launch = {
		DirectionDeadzone = 0.01,
		SpeedMin = 2,
		SpeedMax = 170,
		InitialVelocityCap = 170,
		EnergyMin = 18,
		EnergyMax = 120,

		-- Physical resistance applied by SlingService through a VectorForce during launch.
		-- LinearDragPerSecond is acceleration lost per stud/sec of planar speed;
		-- QuadraticDragPerSecond adds stronger resistance at high launch speeds.
		LinearDragPerSecond = 0.002,
		QuadraticDragPerSecond = 0.00012,
		DragMaxForce = 6000,
		DecayPerSecond = 0.1, -- Decay of currentSpeed in LaunchMotionModel.Sample; kept at 0 since we rely on drag to reduce speed.
		-- Launch enters recovery once horizontal speed reaches this threshold.
		StopSpeed = 1,

		-- Kept for damage / force-transfer math; no longer drives movement.
		PassiveEnergyDecayPerSecond = 0.035,

		-- Fixed recovery duration after launch stops.
		RecoveryDuration = 0.4,
		ValidationGraceSeconds = 0.15,
	},

	Collision = {
		Range = 0.75,
		ValidationTolerance = 10.75,
		YTolerance = 10,
		MaxAllowedSpeed = 450,
		ReportCooldown = 0.05,
		MinReportSpeed = 1,
		FoodHitMinHorizontalSpeed = 1,
		SphereCastRadiusPadding = 0.75,
		SphereCastDistancePadding = 2.5,
		CandidateDistanceFactor = 0.25,
		CandidateExtraPadding = 0.35,
		Cooldown = 0.28,
		TrapCooldown = 0.25,
		RealHitMinClosingSpeed = 5.5,
		MinLaunchEnergy = 5,

		-- Kept near 1 for natural elastic bounce feel.
		Restitution = 0.92,
		TangentialDamping = 0.94,
		EnergyTransferRatio = 0.82,
		CollisionEnergyLossRatio = 0.16,
		ChainHitEnergyRetention = 0.78,
		MinTransferEnergy = 7,
		MinPostCollisionSpeed = 1.25,
		MaxPostCollisionSpeed = 125,
		MinMass = 0.001,
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