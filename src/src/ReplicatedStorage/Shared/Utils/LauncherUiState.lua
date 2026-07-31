--!strict

local LauncherUiState = {}

function LauncherUiState.ClampRatio(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(value, 0, 1)
end

function LauncherUiState.ComputeChargeRatio(elapsedTime: number, maxChargeTime: number): number
	local safeDuration = math.max(maxChargeTime, 0.001)
	return LauncherUiState.ClampRatio(elapsedTime / safeDuration)
end

function LauncherUiState.ComputeCooldownRatio(elapsedTime: number, cooldownDuration: number): number
	local safeDuration = math.max(cooldownDuration, 0.001)
	return LauncherUiState.ClampRatio(elapsedTime / safeDuration)
end

function LauncherUiState.ComputeDirectionRotation(delta: Vector2): number?
	if delta.Magnitude <= 0.001 then
		return nil
	end
	return math.deg(math.atan2(delta.Y, delta.X))
end

function LauncherUiState.ComputeAimDistance(normalizedDistance: number, maxDistance: number): number
	return LauncherUiState.ClampRatio(normalizedDistance) * math.max(0, maxDistance)
end

return LauncherUiState
