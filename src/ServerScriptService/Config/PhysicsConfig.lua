--!strict

local PhysicsConfig = {
	PhysicalProperties = {
		Density = 0.7,
		Friction = 0,
		Elasticity = 0.8,
		FrictionWeight = 0,
		ElasticityWeight = 1,
	},

	Movement = {
		MoveSpeed = 20,
		MaxForce = 3000,
	},

	Charge = {
		MaxChargeTime = 1.4,
		ChargeForceMultiplier = 1,
		MinForce = 30,
		MaxForce = 85,
	},
	LaunchModel = {
		MinDuration = 0.35,
		MaxDuration = 1.35,
		StablePhaseRatio = 0.28,
		SustainPhaseRatio = 0.44,
		Phase2Decay = 0.28,
		Phase3Decay = 1.55,
		HitEnergyFloor = 0.09,
		MinTransferRatio = 0.45,
		MaxTransferRatio = 0.7,
		RepeatedTargetCooldown = 0.2,
	},

	Stability = {
		UseInfiniteForce = true,
		ZeroElasticity = true,
	},

	Collision = {
		MinImpulse = 500,
		MaxImpulse = 9000,
		PlayerImpulseScale = 45,
		MinCollisionSpeed = 20,
		HitstopSeconds = 0.05,
		ImpactAbsorption = 0.6,
		BounceRetention = 0.7,
	},
}

return PhysicsConfig
