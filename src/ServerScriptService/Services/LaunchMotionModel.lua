--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local VelocityDecay = require(ReplicatedStorage.Shared.Utils.VelocityDecay)

local LaunchMotionModel = {}

function LaunchMotionModel.DecayFactor(brake: number, dt: number): number
	return VelocityDecay.DecayFactor(brake, dt)
end

function LaunchMotionModel.ComputeChargeRatio(startedAt: number, now: number): number
	local elapsed = math.max(0, now - startedAt)
	local chargeWindow = math.max(PhysicsConfig.Charge.MinWindowSeconds, PhysicsConfig.Charge.MaxSeconds)
	return math.clamp(elapsed / chargeWindow, 0, 1)
end

function LaunchMotionModel.BuildState(direction: Vector3, chargeRatio: number, now: number, sourcePlayer: Player?): any
	local d = if direction.Magnitude > PhysicsConfig.Launch.DirectionDeadzone then direction.Unit else Vector3.new(0, 0, -1)
	local uncappedSpeed = PhysicsConfig.Launch.SpeedMin
		+ ((PhysicsConfig.Launch.SpeedMax - PhysicsConfig.Launch.SpeedMin) * chargeRatio)
	local speed = math.min(uncappedSpeed, PhysicsConfig.Launch.InitialVelocityCap or PhysicsConfig.Launch.SpeedMax)
	local energy = PhysicsConfig.Launch.EnergyMin
		+ ((PhysicsConfig.Launch.EnergyMax - PhysicsConfig.Launch.EnergyMin) * chargeRatio)
	return {
		direction = d,
		initialSpeed = speed,
		currentSpeed = speed,
		energy = energy,
		startTime = now,
		lastSampleTime = now,
		chargeRatio = chargeRatio,
		collisions = 0,
		sourcePlayer = sourcePlayer,
	}
end

-- Returns decayed speed/energy for callers that need the shared launch model.
function LaunchMotionModel.Sample(state: any, now: number, currentVelocity: Vector3?): (number, number, number)
	local lastSampleTime = state.lastSampleTime or state.startTime or now
	local dt = math.max(0, now - lastSampleTime)
	state.lastSampleTime = now

	local elapsed = math.max(0, now - (state.startTime or now))

	local fallbackVelocitySpeed = if currentVelocity then currentVelocity.Magnitude else 0
	local rawSpeed = math.max(0, state.currentSpeed or state.initialSpeed or fallbackVelocitySpeed)
	local speed = VelocityDecay.StepSpeed(rawSpeed, dt)

	local energyDecayFactor = LaunchMotionModel.DecayFactor(PhysicsConfig.Launch.PassiveEnergyDecayPerSecond, dt)
	local energy = math.max(0, (state.energy or 0) * energyDecayFactor)

	return speed, energy, elapsed
end

return LaunchMotionModel