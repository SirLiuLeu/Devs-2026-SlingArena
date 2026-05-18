--!strict
-- FIX SUMMARY (LaunchMotionModel):
--
-- [FIX] Sample() returns the server-authoritative decay target.
--   Client applies the initial launch impulse locally because the player owns the root.
--   SlingService then uses Sample() to scale down excessive horizontal velocity
--   without increasing speed or changing direction.
--
-- API không thay đổi để tránh breaking changes ở chỗ khác (CollisionService dùng energy).
-- Chỉ thêm comment để làm rõ intent.

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
	Sample() returns decayed speed/energy for the active launch.

	SlingService._stepMovementStates() uses the returned speed as a maximum
	horizontal velocity and scales the physical velocity down when it is above
	the sampled target. It never accelerates the root from this sample.

	Return values giữ nguyên (speed, energy, elapsed) để không break CollisionService
	hay các caller khác.
]]
function LaunchMotionModel.Sample(state: any, now: number, currentVelocity: Vector3?): (number, number, number)
	local lastSampleTime = state.lastSampleTime or state.startTime or now
	local dt = math.max(0, now - lastSampleTime)
	state.lastSampleTime = now

	local elapsed = math.max(0, now - (state.startTime or now))

	-- Speed: target maximum horizontal speed after time-based launch decay.
	local rawSpeed = if currentVelocity then currentVelocity.Magnitude
		else math.max(0, state.currentSpeed or state.initialSpeed or 0)
	local decayFactor = math.max(0, 1 - (PhysicsConfig.Launch.DecayPerSecond * dt))
	local speed = rawSpeed * decayFactor

	-- Energy decay: đây là giá trị quan trọng sau fix.
	-- SlingService dùng energy <= 0 để trigger launch stop.
	-- PassiveEnergyDecayPerSecond nên đủ lớn để launch kết thúc sau thời gian hợp lý.
	local energyDecayFactor = math.max(0, 1 - (PhysicsConfig.Launch.PassiveEnergyDecayPerSecond * dt))
	local energy = math.max(0, (state.energy or 0) * energyDecayFactor)

	return speed, energy, elapsed
end

return LaunchMotionModel