--!strict

local GameConfig = {
	FlagConfig = {
		Ghost = { Duration = 9999, Priority = 90, BlocksCollision = true, BlocksDamage = true },
		Invulnerable = { Duration = 30, Priority = 100, BlocksDamage = true, BlocksDot = true },

		Petrify = { Duration = 5, Priority = 80, Stackable = false, InterruptCharge = true },
		Stun = { Duration = 5, Priority = 70, Stackable = false, InterruptCharge = true },

		Slow = { Duration = 3, Priority = 50, Stackable = false, MaxStack = 1, SlowAmount = 0.25 },

		Burn = { Duration = 4, Stackable = false, MaxStack = 1, TickInterval = 1, DamagePerTick = 250, KnockbackTailDuration = 1.5 },
		Poison = { Duration = 5, Stackable = false, MaxStack = 1, TickInterval = 1, DamagePerTick = 150, SlowAmount = 0.25, SlowDuration = 3, KnockbackTailDuration = 1 },

		PoisonTrap = { Duration = 5, Stackable = true, MaxStack = 5, TickInterval = 1, DamagePerTick = 150, SourceScoped = true },

		HPRecovering = { Duration = 3, Stackable = false, MaxStack = 1, TickInterval = 0.5, HealPerTick = 500 },
		EXPBoosted = { Duration = 300, Stackable = false, MaxStack = 1, ExpBonusPercent = 100 },
		DamageBoosted = { Duration = 30, Stackable = false, MaxStack = 1, DamageBonusPercent = 100 },

		LavaTrap = {
			Duration = 0.75,
			Stackable = false,
			MaxStack = 1,
			SourceScoped = true,
		},
	},

	FlagVisualConfig = {
		Petrify = { Effect = "Frost", Attachment = "EffectOrigin", Material = Enum.Material.Pebble, MaterialTarget = "DefaultMesh" },
		Stun = { Effect = "Stun", Attachment = "EffectHead" },
		Burn = { Effect = "Burn", Attachment = "EffectOrigin" },
		Poison = { Effect = "Poison", Attachment = "EffectOrigin" },
		PoisonTrap = { Effect = "Poison", Attachment = "EffectOrigin" },
		LavaTrap = { Effect = "Burn", Attachment = "EffectOrigin" },
	},
}

return GameConfig
