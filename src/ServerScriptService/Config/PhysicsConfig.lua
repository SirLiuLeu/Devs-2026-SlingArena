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
		MinForce = 35,
		MaxForce = 100,
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
