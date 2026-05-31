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
	TransferRatio: number?,
	EnergyLossRatio: number?,
	MinSpeed: number?,
	MaxSpeed: number?,
}

export type CollisionResult = {
	AttackerVelocity: Vector3,
	DefenderVelocity: Vector3,
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
	impactNormal: Vector3,
	params: CollisionParams?
): CollisionResult
	local planarAttacker = flattenXZ(attackerVelocity)
	local speed = planarAttacker.Magnitude
	local minSpeed = math.max(0, (params and params.MinSpeed) or PhysicsConfig.Collision.MinPostCollisionSpeed)
	if speed <= minSpeed then
		return {
			AttackerVelocity = Vector3.zero,
			DefenderVelocity = Vector3.zero,
			RemainingEnergyScale = 0,
			TransferredEnergyScale = 0,
		}
	end

	local transferRatio = math.clamp(
		(params and params.TransferRatio) or PhysicsConfig.Collision.EnergyTransferRatio,
		0,
		1
	)
	local maxSpeed = math.max(0, (params and params.MaxSpeed) or PhysicsConfig.Collision.MaxPostCollisionSpeed)
	local defenderDirection = safeUnit(impactNormal, planarAttacker)
	local transferSpeed = math.clamp(speed * transferRatio, 0, maxSpeed)
	local attackerRetainRatio = math.clamp(1 - transferRatio, 0.15, 0.9)
	local attackerOut = planarAttacker * attackerRetainRatio
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
	return {
		AttackerVelocity = attackerOut,
		DefenderVelocity = defenderDirection * transferSpeed,
		RemainingEnergyScale = 1 - energyLossRatio,
		TransferredEnergyScale = transferRatio,
	}
end

return VelocityDecay
