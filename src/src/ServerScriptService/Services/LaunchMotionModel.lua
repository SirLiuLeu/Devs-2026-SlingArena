--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local LaunchMotionModel = {}

function LaunchMotionModel.ComputeChargeRatio(startedAt: number, now: number): number
	local elapsed = math.max(0, now - startedAt)
	local chargeWindow = math.max(PhysicsConfig.Charge.MinWindowSeconds, PhysicsConfig.Charge.MaxSeconds)
	return math.clamp(elapsed / chargeWindow, 0, 1)
end

function LaunchMotionModel.BuildState(direction: Vector3, chargeRatio: number, now: number, sourcePlayer: Player?, launchSpeed: number): any
	local d = if direction.Magnitude > PhysicsConfig.Launch.DirectionDeadzone then direction.Unit else Vector3.new(0, 0, -1)
	local speed = math.clamp(launchSpeed, PhysicsConfig.Launch.SpeedMin, PhysicsConfig.Launch.SpeedMax)
	local energy = PhysicsConfig.Launch.EnergyMin
		+ ((PhysicsConfig.Launch.EnergyMax - PhysicsConfig.Launch.EnergyMin) * chargeRatio)
	return {
		direction = d,
		initialSpeed = speed,
		currentSpeed = speed,
		energy = energy,
		startTime = now,
		chargeRatio = chargeRatio,
		collisions = 0,
		sourcePlayer = sourcePlayer,
	}
end

return LaunchMotionModel