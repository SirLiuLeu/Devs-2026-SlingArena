--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local LaunchMotionModel = {}

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

--[[
	Launch sampling is the single source of launch decay. It uses
	PhysicsConfig.Launch.DecayPerSecond for speed, while energy decays separately
	for combat math and never drives movement directly.
]]
function LaunchMotionModel.Sample(state: any, now: number, currentVelocity: Vector3?): (number, number, number)
	local lastSampleTime = state.lastSampleTime or state.startTime or now
	local dt = math.max(0, now - lastSampleTime)
	state.lastSampleTime = now

	local elapsed = math.max(0, now - (state.startTime or now))

	-- Speed: use the actual physical velocity magnitude if available, then decay it.
	-- This ensures collision-induced speed changes are respected rather than overridden.
	local rawSpeed = if currentVelocity then currentVelocity.Magnitude
		else math.max(0, state.currentSpeed or state.initialSpeed or 0)

	-- Single multiplicative decay: speed *= (1 - DecayPerSecond * dt)
	local decayFactor = math.max(0, 1 - (PhysicsConfig.Launch.DecayPerSecond * dt))
	local speed = rawSpeed * decayFactor

	-- Energy decays separately for combat math; does not affect movement speed.
	local energyDecayFactor = math.max(0, 1 - (PhysicsConfig.Launch.PassiveEnergyDecayPerSecond * dt))
	local energy = math.max(0, (state.energy or 0) * energyDecayFactor)

	return speed, energy, elapsed
end

return LaunchMotionModel