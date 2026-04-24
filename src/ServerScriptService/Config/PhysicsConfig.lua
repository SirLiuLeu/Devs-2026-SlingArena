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
		MoveSpeed = 36,
		MaxForce = 30000,
	},

	Charge = {
		MaxChargeTime = 1.4,
		ChargeForceMultiplier = 1,
		MinForce = 35,
		MaxForce = 1400,
	},

	Stability = {
		UseInfiniteForce = true,
		ZeroElasticity = true,
	},
}

return PhysicsConfig
