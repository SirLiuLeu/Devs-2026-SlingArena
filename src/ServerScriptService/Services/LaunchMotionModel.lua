--!strict

local LaunchConfig = require(script.Parent.Parent.Config.LaunchModelConfig)

local LaunchMotionModel = {}

function LaunchMotionModel.ComputeChargeRatio(startedAt: number, now: number): number
	local elapsed = math.max(0, now - startedAt)
	local chargeWindow = math.max(0.001, LaunchConfig.Charge.MaxSeconds)
	return math.clamp(elapsed / chargeWindow, 0, 1)
end

function LaunchMotionModel.BuildState(direction: Vector3, chargeRatio: number, now: number, sourcePlayer: Player?): any
	local d = if direction.Magnitude > 0.001 then direction.Unit else Vector3.new(0, 0, -1)
	local duration = LaunchConfig.Duration.Min + ((LaunchConfig.Duration.Max - LaunchConfig.Duration.Min) * chargeRatio)
	local speed = LaunchConfig.Speed.Min + ((LaunchConfig.Speed.Max - LaunchConfig.Speed.Min) * chargeRatio)
	local energy = LaunchConfig.Energy.Min + ((LaunchConfig.Energy.Max - LaunchConfig.Energy.Min) * chargeRatio)
	return {
		direction = d,
		initialSpeed = speed,
		currentSpeed = speed,
		energy = energy,
		startTime = now,
		duration = duration,
		chargeRatio = chargeRatio,
		collisions = 0,
		sourcePlayer = sourcePlayer,
	}
end

function LaunchMotionModel.Sample(state: any, now: number)
	local elapsed = math.max(0, now - state.startTime)
	local fullWindow = state.duration * LaunchConfig.Duration.FullSpeedRatio
	local decayWindow = math.max(0.001, state.duration * LaunchConfig.Duration.DecayRatio)
	local decayAlpha = 0
	if elapsed > fullWindow then
		decayAlpha = math.clamp((elapsed - fullWindow) / decayWindow, 0, 1)
	end
	local speed = state.initialSpeed * (1 - (decayAlpha * decayAlpha))
	local passiveDecay = 1 - (LaunchConfig.Energy.PassiveDecayPerSecond * elapsed)
	local energy = math.max(0, state.energy * math.max(0, passiveDecay))
	return speed, energy, elapsed
end

return LaunchMotionModel
