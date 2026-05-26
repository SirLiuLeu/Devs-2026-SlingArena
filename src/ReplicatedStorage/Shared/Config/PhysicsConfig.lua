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
		MaxForce = 10,
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
		-- Launch speed decay is enforced by SlingService via LaunchMotionModel.Sample().
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
		SpeedMin = 20,
		SpeedMax = 70,
		InitialVelocityCap = 80,
		EnergyMin = 18,
		EnergyMax = 120,

		-- Reserved launch drag knobs for future physical drag tuning. Current active
		-- launch slowdown is DecayPerSecond via LaunchMotionModel.Sample().
		LinearDragPerSecond = 1.2, -- UNUSED (reserved; launch drag now uses DecayPerSecond).
		QuadraticDragPerSecond = 1.12, -- UNUSED (no reader in runtime).
		DragMaxForce = 6000, -- UNUSED (no reader in runtime).
		DecayPerSecond = 0.2, -- Server-enforced speed decay applied from LaunchMotionModel.Sample.
		-- Launch enters recovery once horizontal speed reaches this threshold.
		StopSpeed = 1,

		-- Kept for damage / force-transfer math; no longer drives movement.
		PassiveEnergyDecayPerSecond = 0.035,

		-- Fixed recovery duration after launch stops.
		RecoveryDuration = 0.4,
		ValidationGraceSeconds = 1,

		-- ── Launch state-machine constants (refactor) ──────────────────────────────
		--
		-- GraceWindowSeconds: Duration after launch begins during which physics-based
		-- stop checks are completely ignored. Protects against the server reading
		-- velocity ≈ 0 immediately after a client-authoritative impulse (replication lag).
		-- Must be long enough to survive the worst RTT, but short enough to not mask
		-- real early stops. 0.35 s is ~2× a 150 ms RTT with margin.
		GraceWindowSeconds = 0.35,

		-- StopEvidenceFramesRequired: Number of consecutive Heartbeat frames where the
		-- server-observed horizontal speed stays below StopSpeed before the server
		-- accepts that the Sling has truly stopped. Prevents a single transient low
		-- reading (network spike, brief wall clip) from ending Launch prematurely.
		StopEvidenceFramesRequired = 4,

		-- MaxLaunchDuration: Hard timeout fail-safe. If Launch has been active for
		-- longer than this many seconds, force it to end regardless of decay model or
		-- physics observations. Prevents a stuck Launching state under any edge case.
		MaxLaunchDuration = 12,
	},

	Collision = {
		Range = 0.75,
		ValidationTolerance = 10.75,
		YTolerance = 10,
		MaxAllowedSpeed = 450,
		ReportCooldown = 0.05, -- UNUSED (client/server use local cooldown constants instead).
		MinReportSpeed = 1,
		FoodHitMinHorizontalSpeed = 1,
		SphereCastRadiusPadding = 0.75,
		SphereCastDistancePadding = 2.5,
		CandidateDistanceFactor = 0.25, -- UNUSED (legacy candidate scan tuning).
		CandidateExtraPadding = 0.35, -- UNUSED (legacy candidate scan tuning).
		Cooldown = 0.28,
		TrapCooldown = 0.25,
		RealHitMinClosingSpeed = 5.5,
		MinLaunchEnergy = 5, -- UNUSED (transfer gate uses MinTransferEnergy).

		-- Kept near 1 for natural elastic bounce feel.
		Restitution = 0.92, -- UNUSED (bounce uses World.WallRestitution/collision formulas).
		TangentialDamping = 0.94, -- UNUSED (bounce uses World.WallTangentialDamping).
		EnergyTransferRatio = 0.82,
		CollisionEnergyLossRatio = 0.16,
		ChainHitEnergyRetention = 0.78, -- UNUSED (collision chain retention currently derived from CollisionEnergyLossRatio).
		MinTransferEnergy = 7,
		MinPostCollisionSpeed = 1.25,
		MaxPostCollisionSpeed = 125,
		MinMass = 0.001, -- UNUSED (no mass clamp currently applied).
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