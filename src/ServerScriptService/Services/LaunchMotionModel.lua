--!strict
-- FIX SUMMARY (LaunchMotionModel):
--
-- [FIX] Sample() không còn được dùng để drive movement speed.
--   Trước: SlingService đọc targetSpeed từ Sample() rồi stamp lên velocity mỗi frame.
--   Sau:   Sample() chỉ track energy decay để SlingService biết khi nào launch "hết lực".
--          Speed decay (DecayPerSecond) không còn ý nghĩa cho movement — giữ = 0 trong PhysicsConfig
--          hoặc để physics engine tự lo.
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
	Sample() — chỉ track energy decay. Không còn drive movement speed.

	Sau FIX: SlingService._stepMovementStates() gọi Sample() chỉ để:
	  1. Lấy sampledEnergy → detect khi energy <= 0 → trigger stop.
	  2. Không dùng returned speed để stamp velocity.

	Speed decay (DecayPerSecond) trong PhysicsConfig nên = 0 (đã là 0).
	Nếu muốn có drag trong launch, config LinearDragPerSecond và để physics engine apply.

	Return values giữ nguyên (speed, energy, elapsed) để không break CollisionService
	hay các caller khác.
]]
function LaunchMotionModel.Sample(state: any, now: number, currentVelocity: Vector3?): (number, number, number)
	local lastSampleTime = state.lastSampleTime or state.startTime or now
	local dt = math.max(0, now - lastSampleTime)
	state.lastSampleTime = now

	local elapsed = math.max(0, now - (state.startTime or now))

	-- Speed: vẫn trả về để caller có thể dùng nếu cần,
	-- nhưng SlingService sau fix KHÔNG dùng giá trị này để stamp velocity.
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