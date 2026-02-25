--!strict

export type AttributesState = {
	Speed: number,
	HPBonus: number,
	LaunchPower: number,
	ChargeSpeed: number,
	ReflectDamage: number,
}

export type PlayerState = {
	UserId: number,

	Level: number,
	Exp: number,
	Size: number,
	MaxHP: number,
	CurrentHP: number,

	BaseDamage: number,
	DamageMultiplier: number,
	KnockbackResistance: number,

	SlingshotType: string,
	ChargeValue: number,
	CurrentVelocity: Vector3,

	InvulnerableUntil: number,
	InvulCooldownUntil: number,

	Diamonds: number,
	RespawnCountThisMatch: number,

	AttributePoints: number,

	Attributes: AttributesState,

	IsAlive: boolean,
	IsCharging: boolean,
}

return {}
