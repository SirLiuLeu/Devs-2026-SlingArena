--!strict

local SlingUiState = {}

function SlingUiState.ClampRatio(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(value, 0, 1)
end

function SlingUiState.ComputeChargeRatio(elapsedTime: number, maxChargeTime: number): number
	local safeDuration = math.max(maxChargeTime, 0.001)
	return SlingUiState.ClampRatio(elapsedTime / safeDuration)
end

function SlingUiState.ComputeCooldownRatio(elapsedTime: number, cooldownDuration: number): number
	local safeDuration = math.max(cooldownDuration, 0.001)
	return SlingUiState.ClampRatio(elapsedTime / safeDuration)
end

function SlingUiState.ComputeDirectionRotation(delta: Vector2): number?
	if delta.Magnitude <= 0.001 then
		return nil
	end
	return math.deg(math.atan2(delta.Y, delta.X))
end

return SlingUiState
