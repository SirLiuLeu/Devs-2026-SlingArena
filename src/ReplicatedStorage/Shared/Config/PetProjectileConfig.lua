--!strict

local PetProjectileConfig = {
	PlasmaCannon = {
		Cooldown = 10,
		ProjectileSpeed = 60,
		DamageByLevel = { [1] = 700, [5] = 800, [10] = 900, [15] = 1000, [20] = 1100 },
		TargetRange = 120,
		MaxLifetime = 10,
		GroundRollLifetime = 5,
	},
	SlowBlaster = {
		Cooldown = 8,
		ProjectileSpeed = 15,
		TargetRange = 120,
		MaxLifetime = 10,
		SlowDurationByLevel = { [1] = 3, [5] = 3.5, [10] = 4, [15] = 4.5, [20] = 5 },
		SlowAmount = 0.25,
	},
}

function PetProjectileConfig.GetLevelValue(values: { [number]: number }, level: number): number
	local selectedLevel = 1
	for milestone in pairs(values) do
		if milestone <= level and milestone > selectedLevel then selectedLevel = milestone end
	end
	return values[selectedLevel] or values[1] or 0
end

return PetProjectileConfig
