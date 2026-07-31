--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local LaunchMotionModel = {}

function LaunchMotionModel.ComputeChargeRatio(startedAt: number, now: number): number
	local elapsed = math.max(0, now - startedAt)
	local chargeWindow = math.max(PhysicsConfig.Charge.MinWindowSeconds, PhysicsConfig.Charge.MaxSeconds)
	return math.clamp(elapsed / chargeWindow, 0, 1)
end

function LaunchMotionModel.ResolveLaunchSpeed(chargeRatio: number, launcherMaxSpeed: number): number
	local safeRatio = math.clamp(chargeRatio, 0, 1)
	local maxLauncherSpeed = math.max(PhysicsConfig.Launch.SpeedMin, launcherMaxSpeed)
	local uncappedSpeed = PhysicsConfig.Launch.SpeedMin
		+ ((maxLauncherSpeed - PhysicsConfig.Launch.SpeedMin) * safeRatio)
	return math.min(uncappedSpeed, PhysicsConfig.Launch.SpeedMax)
end

function LaunchMotionModel.BuildState(direction: Vector3, chargeRatio: number, now: number, sourcePlayer: Player?, launcherMaxSpeed: number): any
	local d = if direction.Magnitude > PhysicsConfig.Launch.DirectionDeadzone then direction.Unit else Vector3.new(0, 0, -1)
	local safeChargeRatio = math.clamp(chargeRatio, 0, 1)
	local speed = LaunchMotionModel.ResolveLaunchSpeed(safeChargeRatio, launcherMaxSpeed)
	local energy = PhysicsConfig.Launch.EnergyMin
		+ ((PhysicsConfig.Launch.EnergyMax - PhysicsConfig.Launch.EnergyMin) * safeChargeRatio)
	return {
		direction = d,
		initialSpeed = speed,
		currentSpeed = speed,
		energy = energy,
		startTime = now,
		chargeRatio = safeChargeRatio,
		collisions = 0,
		sourcePlayer = sourcePlayer,
	}
end

return LaunchMotionModel