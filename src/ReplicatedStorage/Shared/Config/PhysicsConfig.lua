--!strict

-- Shared physics tuning. Server is authoritative for collision/damage, while clients may
-- read this module for prediction/UI so visible feel stays in sync with server physics.
local PhysicsConfig = {
	PhysicalProperties = {
		Density = 0.7,
		Friction = 0.3,
		Elasticity = 0.5,
		FrictionWeight = 1,
		ElasticityWeight = 1,
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
		-- Launching players rely on native physics friction/bounce after the client impulse.
		LinearDragPerSecond = 0.08,
		StopSpeed = 0.5,
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
		SpeedMin = 15,
		SpeedMax = 70,
		InitialVelocityCap = 60,
		EnergyMin = 18,
		EnergyMax = 120,

		-- Launch enters recovery once the client observes native physics below this threshold.
		StopSpeed = 1,

		-- Fixed recovery duration after launch stops.
		RecoveryDuration = 0.4,
		ValidationGraceSeconds = 1,

		-- StopEvidenceFramesRequired: Number of consecutive client frames where native
		-- horizontal speed stays below StopSpeed before reporting a natural stop.
		StopEvidenceFramesRequired = 4,

		-- MaxLaunchDuration: Server hard timeout fail-safe if the stop report is lost.
		MaxLaunchDuration = 3,
		SpeedCeilingMultiplier = 1.15,
		SpeedCeilingPadding = 5,
		MaxDamageTargetsPerLaunch = 3,
		MaxKnockbackTargetsPerLaunch = 5,
	},

	Collision = {
		Range = 0.5,
		ValidationTolerance = 3.5,
		YTolerance = 10,
		MaxAllowedSpeed = 200,
		MinReportSpeed = 1,
		FoodHitMinHorizontalSpeed = 1,
		SphereCastRadiusPadding = 0.75,
		SphereCastDistancePadding = 2.5,
		Cooldown = 0.28,
		TrapCooldown = 0.25,
		RealHitMinClosingSpeed = 5.5,

		-- Substepping parameters
		SubstepAngleThreshold = math.rad(30),
		SubstepSpeedDeltaRatio = 0.4,
		SubstepDistanceFactor = 2.0,
		MaxSubstepSegments = 4,

		-- Server validation parameters
		PositionHistoryWindow = 0.5,

		-- Launcher-vs-Launcher collision response is based on normal closing speed,
		-- not a fixed percentage of the attacker's full travel velocity.
		-- Direct hits use most of the normal component; glancing hits are reduced
		-- by the collision angle before any defender knockback is emitted.
		DefenderVelocityTransferScale = 0.7,
		AttackerNormalVelocityRetention = 0.35,
		AttackerTangentialVelocityRetention = 0.92,
		CollisionAngleReductionExponent = 1.35,
		CollisionEnergyLossRatio = 0.16,
		KnockbackImpulseDuration = 0.1,

		-- Food collision response uses the same single-step model on client and server.
		FoodRestitution = 0.55,
		FoodTangentialDamping = 0.92,

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