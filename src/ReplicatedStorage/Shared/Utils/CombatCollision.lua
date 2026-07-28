--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local VelocityDecay = require(ReplicatedStorage.Shared.Utils.VelocityDecay)

export type BounceResult = VelocityDecay.CollisionResult

local CombatCollision = {}

local EPSILON = 1e-5

function CombatCollision.FlattenXZ(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function CombatCollision.SafeUnit(vector: Vector3, fallback: Vector3): Vector3
	local flat = CombatCollision.FlattenXZ(vector)
	if flat.Magnitude > EPSILON then
		return flat.Unit
	end
	local fallbackFlat = CombatCollision.FlattenXZ(fallback)
	if fallbackFlat.Magnitude > EPSILON then
		return fallbackFlat.Unit
	end
	return Vector3.new(0, 0, -1)
end

function CombatCollision.ResolveAttackerBounce(attackerVelocity: Vector3, targetVelocity: Vector3, impactNormal: Vector3): BounceResult
	return VelocityDecay.ResolvePlayerCollision(attackerVelocity, targetVelocity, impactNormal, {
		MinSpeed = PhysicsConfig.Collision.MinPostCollisionSpeed,
		MaxSpeed = PhysicsConfig.Collision.MaxPostCollisionSpeed,
	})
end

function CombatCollision.ResolvePlanarNormal(attackerPosition: Vector3, targetPosition: Vector3, attackerVelocity: Vector3): Vector3
	local towardAttacker = attackerPosition - targetPosition
	local fallback = -CombatCollision.FlattenXZ(attackerVelocity)
	return CombatCollision.SafeUnit(towardAttacker, fallback)
end

function CombatCollision.ComputeDepenetratedPosition(attackerRoot: BasePart, targetPart: BasePart, normal: Vector3, padding: number?): Vector3?
	local attackerRadius = math.max(attackerRoot.Size.X, attackerRoot.Size.Z) * 0.5
	local targetRadius = math.max(targetPart.Size.X, targetPart.Size.Z) * 0.5
	local requiredDistance = attackerRadius + targetRadius + (padding or PhysicsConfig.Collision.Range)
	local offset = attackerRoot.Position - targetPart.Position
	local planarOffset = CombatCollision.FlattenXZ(offset)
	local distance = planarOffset.Magnitude
	local penetration = requiredDistance - distance
	if penetration <= 0 then
		return nil
	end
	local pushNormal = CombatCollision.SafeUnit(normal, planarOffset)
	local pushOut = pushNormal * (penetration + PhysicsConfig.Collision.DepenetrationSlop)
	return attackerRoot.Position + Vector3.new(pushOut.X, 0, pushOut.Z)
end

return CombatCollision
