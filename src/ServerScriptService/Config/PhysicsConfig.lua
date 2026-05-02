--!strict

local PhysicsConfig = {
	PhysicalProperties = {
		Density = 1.05,
		Friction = 0.85,
		Elasticity = 0,
		FrictionWeight = 1,
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
	},
}

return PhysicsConfig
