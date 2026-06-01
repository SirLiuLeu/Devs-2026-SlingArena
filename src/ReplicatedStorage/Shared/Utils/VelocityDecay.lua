--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

export type DecayParams = {
	Brake: number?,
	Threshold: number?,
	StopSpeed: number?,
	HeavyBrakeMultiplier: number?,
}

export type CollisionParams = {
	DefenderVelocityTransferScale: number?,
	AttackerNormalVelocityRetention: number?,
	AttackerTangentialVelocityRetention: number?,
	AngleReductionExponent: number?,
	EnergyLossRatio: number?,
	MinSpeed: number?,
	MaxSpeed: number?,
}

export type CollisionResult = {
	AttackerVelocity: Vector3,
	DefenderVelocity: Vector3,
	ClosingSpeed: number,
	AngleFactor: number,
	NormalSpeed: number,
	TangentialSpeed: number,
	RemainingEnergyScale: number,
	TransferredEnergyScale: number,
}

local VelocityDecay = {}

local EPSILON = 1e-5

local function flattenXZ(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeUnit(vector: Vector3, fallback: Vector3): Vector3
	local flat = flattenXZ(vector)
	if flat.Magnitude > EPSILON then
		return flat.Unit
	end
	local fallbackFlat = flattenXZ(fallback)
	if fallbackFlat.Magnitude > EPSILON then
		return fallbackFlat.Unit
	end
	return Vector3.new(0, 0, -1)
end

local function resolveDecayParams(params: DecayParams?): (number, number, number, number)
	local launchConfig = PhysicsConfig.Launch
	local brake = math.max(0, (params and params.Brake) or launchConfig.Brake or 0)
	local threshold = math.max(0, (params and params.Threshold) or launchConfig.Threshold or 0)
	local stopSpeed = math.max(0, (params and params.StopSpeed) or launchConfig.StopSpeed or 0)
	local heavyBrakeMultiplier = math.max(1, (params and params.HeavyBrakeMultiplier) or launchConfig.HeavyBrakeMultiplier or 1)
	return brake, threshold, stopSpeed, heavyBrakeMultiplier
end

function VelocityDecay.FlattenXZ(vector: Vector3): Vector3
	return flattenXZ(vector)
end

function VelocityDecay.DecayFactor(brake: number, dt: number): number
	return math.exp(-math.max(0, brake) * math.max(0, dt))
end

function VelocityDecay.StepVelocity(velocity: Vector3, dt: number, params: DecayParams?): Vector3
	local planar = flattenXZ(velocity)
	local speed = planar.Magnitude
	local brake, threshold, stopSpeed, heavyBrakeMultiplier = resolveDecayParams(params)
	if speed <= stopSpeed then
		return Vector3.zero
	end

	local activeBrake = if threshold > 0 and speed <= threshold then brake * heavyBrakeMultiplier else brake
	local decayed = planar * VelocityDecay.DecayFactor(activeBrake, dt)
	if decayed.Magnitude <= stopSpeed then
		return Vector3.zero
	end
	return decayed
end

function VelocityDecay.StepSpeed(speed: number, dt: number, params: DecayParams?): number
	local initial = math.max(0, speed)
	if initial <= 0 then
		return 0
	end
	return VelocityDecay.StepVelocity(Vector3.new(initial, 0, 0), dt, params).Magnitude
end

function VelocityDecay.ResolvePlayerCollision(
	attackerVelocity: Vector3,
	defenderVelocity: Vector3,
	impactNormal: Vector3,
	params: CollisionParams?
): CollisionResult
	local planarAttacker = flattenXZ(attackerVelocity)
	local planarDefender = flattenXZ(defenderVelocity)
	local speed = planarAttacker.Magnitude
	local minSpeed = math.max(0, (params and params.MinSpeed) or PhysicsConfig.Collision.MinPostCollisionSpeed)
	local normal = safeUnit(impactNormal, planarAttacker)
	local maxSpeed = math.max(0, (params and params.MaxSpeed) or PhysicsConfig.Collision.MaxPostCollisionSpeed)

	local emptyResult = {
		AttackerVelocity = Vector3.zero,
		DefenderVelocity = Vector3.zero,
		ClosingSpeed = 0,
		AngleFactor = 0,
		NormalSpeed = 0,
		TangentialSpeed = 0,
		RemainingEnergyScale = 0,
		TransferredEnergyScale = 0,
	}
	if speed <= minSpeed then
		return emptyResult
	end

	local relativeVelocity = planarAttacker - planarDefender
	local closingSpeed = math.max(0, relativeVelocity:Dot(normal))
	if closingSpeed <= minSpeed then
		return emptyResult
	end

	local attackerNormalSpeed = planarAttacker:Dot(normal)
	local attackerNormal = normal * attackerNormalSpeed
	local attackerTangential = planarAttacker - attackerNormal
	local angleFactor = math.clamp(closingSpeed / math.max(relativeVelocity.Magnitude, speed, EPSILON), 0, 1)
	local angleExponent = math.max(0, (params and params.AngleReductionExponent)
		or PhysicsConfig.Collision.CollisionAngleReductionExponent or 1)
	local angleScale = angleFactor ^ angleExponent

	local defenderTransferScale = math.clamp(
		(params and params.DefenderVelocityTransferScale) or PhysicsConfig.Collision.DefenderVelocityTransferScale,
		0,
		2
	)
	local transferSpeed = math.clamp(closingSpeed * defenderTransferScale * angleScale, 0, maxSpeed)

	local normalRetention = math.clamp(
		(params and params.AttackerNormalVelocityRetention) or PhysicsConfig.Collision.AttackerNormalVelocityRetention,
		0,
		1
	)
	local tangentialRetention = math.clamp(
		(params and params.AttackerTangentialVelocityRetention) or PhysicsConfig.Collision.AttackerTangentialVelocityRetention,
		0,
		1.25
	)
	local retainedNormal = if attackerNormalSpeed > 0
		then normal * (attackerNormalSpeed * normalRetention)
		else attackerNormal
	local attackerOut = (attackerTangential * tangentialRetention) + retainedNormal
	if maxSpeed > 0 and attackerOut.Magnitude > maxSpeed then
		attackerOut = attackerOut.Unit * maxSpeed
	end
	if attackerOut.Magnitude <= minSpeed then
		attackerOut = Vector3.zero
	end

	local energyLossRatio = math.clamp(
		(params and params.EnergyLossRatio) or PhysicsConfig.Collision.CollisionEnergyLossRatio,
		0,
		1
	)
	local transferredEnergyScale = if speed > EPSILON then math.clamp(transferSpeed / speed, 0, 1) else 0
	return {
		AttackerVelocity = attackerOut,
		DefenderVelocity = normal * transferSpeed,
		ClosingSpeed = closingSpeed,
		AngleFactor = angleFactor,
		NormalSpeed = math.max(0, attackerNormalSpeed),
		TangentialSpeed = attackerTangential.Magnitude,
		RemainingEnergyScale = 1 - (energyLossRatio * angleScale),
		TransferredEnergyScale = transferredEnergyScale,
	}
end

return VelocityDecay
