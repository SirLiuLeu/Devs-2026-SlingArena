--!strict

local CollisionResponse = {}

local MIN_NORMAL_MAGNITUDE = 1e-5

local function flattenXZ(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function sanitizeUnit(vector: Vector3, fallback: Vector3): Vector3
	local flat = flattenXZ(vector)
	if flat.Magnitude > MIN_NORMAL_MAGNITUDE then
		return flat.Unit
	end
	local fallbackFlat = flattenXZ(fallback)
	if fallbackFlat.Magnitude > MIN_NORMAL_MAGNITUDE then
		return fallbackFlat.Unit
	end
	return Vector3.new(0, 0, -1)
end

function CollisionResponse.ResolvePlanarBounce(
	velocity: Vector3,
	normal: Vector3,
	params: { Restitution: number?, TangentialDamping: number?, MinSpeed: number?, MaxSpeed: number? }?
): Vector3
	local input = flattenXZ(velocity)
	local speed = input.Magnitude
	if speed <= ((params and params.MinSpeed) or 0) then
		return Vector3.zero
	end

	local unitNormal = sanitizeUnit(normal, -input)
	local restitution = math.max(0, (params and params.Restitution) or 1)
	local tangentialDamping = math.clamp((params and params.TangentialDamping) or 1, 0, 1)
	local normalComponent = unitNormal * input:Dot(unitNormal)
	local tangentialComponent = input - normalComponent
	local output = (tangentialComponent * tangentialDamping) - (normalComponent * restitution)

	local minSpeed = (params and params.MinSpeed) or 0
	if output.Magnitude <= minSpeed then
		return Vector3.zero
	end
	local maxSpeed = params and params.MaxSpeed
	if maxSpeed and maxSpeed > 0 and output.Magnitude > maxSpeed then
		return output.Unit * maxSpeed
	end
	return output
end

return CollisionResponse
