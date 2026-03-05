--!strict

export type AttributesState = {
	Damage: number,
	MaxHP: number,
	Regen: number,
	Range: number,
	Reflect: number,
}

export type PlayerState = {
	UserId: number,
	MapName: string,
	ArenaStatus: string,
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
	DamageDealt: number,
	IsTeleporting: boolean,
	Attributes: AttributesState,
	IsAlive: boolean,
	IsCharging: boolean,
	MovementState: string,
	ScaleMultiplier: number,
	BonusMaxHP: number,
	BonusDamageMultiplier: number,
}

return {}
