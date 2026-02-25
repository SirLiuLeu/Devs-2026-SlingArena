--!strict

export type CollisionContext = {
	Attacker: Player,
	Defender: Player,
	VelocityMagnitude: number,
	ChargeRatio: number,
	ImpactDirection: Vector3,
}

export type DamageResult = {
	RawDamage: number,
	AppliedDamage: number,
	SelfDamage: number,
	WasKill: boolean,
}

return {}
