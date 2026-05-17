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
	Launch motion is physics-driven after the initial impulse. Sampling only advances
	combat energy bookkeeping; it never returns a target speed for the server to stamp
	onto AssemblyLinearVelocity.
]]
function LaunchMotionModel.SampleEnergy(state: any, now: number): (number, number)
	local lastSampleTime = state.lastSampleTime or state.startTime or now
	local dt = math.max(0, now - lastSampleTime)
	state.lastSampleTime = now

	local elapsed = math.max(0, now - (state.startTime or now))
	local energyDecayFactor = math.max(0, 1 - (PhysicsConfig.Launch.PassiveEnergyDecayPerSecond * dt))
	local energy = math.max(0, (state.energy or 0) * energyDecayFactor)

	return energy, elapsed
end

function LaunchMotionModel.ComputeDragForce(horizontalVelocity: Vector3, assemblyMass: number): Vector3
	local speed = horizontalVelocity.Magnitude
	if speed <= PhysicsConfig.Movement.InputDeadzone then
		return Vector3.zero
	end

	local linearAcceleration = PhysicsConfig.Launch.LinearDragPerSecond * speed
	local quadraticAcceleration = PhysicsConfig.Launch.QuadraticDragPerSecond * speed * speed
	local forceMagnitude = math.min(
		assemblyMass * (linearAcceleration + quadraticAcceleration),
		PhysicsConfig.Launch.DragMaxForce
	)

	return horizontalVelocity.Unit * -forceMagnitude
end

return LaunchMotionModel