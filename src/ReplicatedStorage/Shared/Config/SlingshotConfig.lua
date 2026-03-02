--!strict

local SlingshotConfig = {
	MaxChargeTime = 2.0,
	BaseLaunchForce = 90,
	LaunchPowerPerPoint = 0.01,
	ChargeSpeedPerPoint = 0.02,
	SlingshotModifiers = {
		Default = 1.0,
		Heavy = 1.2,
		Swift = 0.9,
	},
	SlingConfig = {
		MaxHP = 100,
		BaseDamage = 20,
		ReflectDamagePercent = 0.05,
		RegenPerSecond = 2,
		MaxPullDistance = 30,
		ForceMultiplier = 6,
		MaxShootRange = 120,
		Size = 1,
	},
}

return SlingshotConfig
