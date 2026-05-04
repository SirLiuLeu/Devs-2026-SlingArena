--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsConfig = require(script.Parent.Parent.Config.PhysicsConfig)

local LaunchSessionService = {}
LaunchSessionService.__index = LaunchSessionService

function LaunchSessionService.new(_context)
	local self = setmetatable({}, LaunchSessionService)
	self._sessions = {}
	return self
end

function LaunchSessionService:StartSession(player: Player, launchDirection: Vector3, chargeRatio: number, initialSpeed: number)
	local model = PhysicsConfig.LaunchModel
	local duration = model.MinDuration + ((model.MaxDuration - model.MinDuration) * chargeRatio)
	self._sessions[player] = {
		LaunchStartTime = os.clock(),
		ChargeRatio = chargeRatio,
		LaunchDuration = duration,
		InitialSpeed = initialSpeed,
		MaxSpeed = initialSpeed * (1 + (chargeRatio * 0.25)),
		DecayCurve = { Phase2Decay = model.Phase2Decay, Phase3Decay = model.Phase3Decay },
		EnergyLeft = 1,
		HitCount = 0,
		LastHitTime = 0,
		CurrentDamageMultiplier = 1 + (chargeRatio * 0.2),
		CurrentSpeedMultiplier = 1,
		LastPosition = nil,
		LastDirection = if launchDirection.Magnitude > 0.01 then launchDirection.Unit else Vector3.new(0, 0, -1),
		HitTargets = {},
	}
	return self._sessions[player]
end

function LaunchSessionService:GetSession(player: Player)
	return self._sessions[player]
end

function LaunchSessionService:EndSession(player: Player)
	self._sessions[player] = nil
end

function LaunchSessionService:StepSession(player: Player, position: Vector3?)
	local session = self._sessions[player]
	if not session then
		return nil
	end
	local now = os.clock()
	local age = now - session.LaunchStartTime
	local ratio = math.clamp(age / math.max(session.LaunchDuration, 0.001), 0, 1)
	local model = PhysicsConfig.LaunchModel
	local stableEnd = model.StablePhaseRatio
	local sustainEnd = math.clamp(stableEnd + model.SustainPhaseRatio, stableEnd, 1)
	local speedMultiplier = 1
	if ratio <= stableEnd then
		speedMultiplier = 1
	elseif ratio <= sustainEnd then
		local t = (ratio - stableEnd) / math.max(0.001, sustainEnd - stableEnd)
		speedMultiplier = 1 - (session.DecayCurve.Phase2Decay * t)
	else
		local t = (ratio - sustainEnd) / math.max(0.001, 1 - sustainEnd)
		speedMultiplier = math.max(0, (1 - session.DecayCurve.Phase2Decay) * (1 - (session.DecayCurve.Phase3Decay * t)))
	end
	session.CurrentSpeedMultiplier = math.max(0, speedMultiplier)
	session.EnergyLeft = math.max(0, 1 - ratio)
	session.CurrentDamageMultiplier = (1 + (session.ChargeRatio * 0.2)) * math.max(0.2, session.EnergyLeft)
	if position then
		if session.LastPosition then
			local delta = position - session.LastPosition
			if delta.Magnitude > 0.01 then
				session.LastDirection = delta.Unit
			end
		end
		session.LastPosition = position
	end
	return session
end

function LaunchSessionService:IsHitValid(session): boolean
	if not session then
		return false
	end
	local age = os.clock() - session.LaunchStartTime
	return age <= session.LaunchDuration and session.EnergyLeft >= PhysicsConfig.LaunchModel.HitEnergyFloor
end

return LaunchSessionService
