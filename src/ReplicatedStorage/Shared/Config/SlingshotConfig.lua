--!strict

local SlingshotConfig = {
	MAX_CHARGE_TIME = 2.0,
	MIN_LAUNCH_FORCE = 45,
	MAX_LAUNCH_FORCE = 240,
	RECOVER_TIME = 0.35,
	MAX_AIM_DISTANCE = 500,
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
