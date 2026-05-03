--!strict

local SlingshotConfig = {
	MAX_CHARGE_TIME = 2.0,
	MIN_LAUNCH_FORCE = 450,
	MAX_LAUNCH_FORCE = 1875,
	RECOVER_TIME = 3.0,
	MAX_AIM_DISTANCE = 500,
	MaxChargeTime = 2.0,
	BaseLaunchForce = 900,
	LaunchPowerPerPoint = 0.01,
	ChargeSpeedPerPoint = 0.02,
	SlingshotModifiers = {
		Default = 1.0,
		Heavy = 1.15,
		Swift = 0.9,
	},
	SlingConfig = {
		MaxHP = 1000,
		BaseDamage = 211000,
		ReflectDamagePercent = 0.05,
		RegenPerSecond = 2,
		MaxPullDistance = 30,
		ForceMultiplier = 6,
		MaxShootRange = 120,
		Size = 1,
	},
}

return SlingshotConfig
