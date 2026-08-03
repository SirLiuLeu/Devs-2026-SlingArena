--!strict

local LauncherCooldownService = {}
LauncherCooldownService.__index = LauncherCooldownService

export type CooldownState = {
	cooldownStartTime: number,
	cooldownEndTime: number,
	cooldownDuration: number,
}

function LauncherCooldownService.new(defaultDuration: number)
	return setmetatable({
		DefaultDuration = math.max(defaultDuration, 0),
		cooldownStartTime = 0,
		cooldownEndTime = 0,
		cooldownDuration = math.max(defaultDuration, 0),
	}, LauncherCooldownService)
end

function LauncherCooldownService.ClampRatio(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(value, 0, 1)
end

function LauncherCooldownService.ComputeCooldownRatio(elapsedTime: number, cooldownDuration: number): number
	local safeDuration = math.max(cooldownDuration, 0.001)
	return LauncherCooldownService.ClampRatio(elapsedTime / safeDuration)
end

function LauncherCooldownService:Begin(duration: number, endTime: number?, now: number?): CooldownState
	local resolvedDuration = math.max(duration, 0)
	self.cooldownDuration = resolvedDuration
	if endTime and endTime > 0 then
		self.cooldownEndTime = endTime
		self.cooldownStartTime = self.cooldownEndTime - resolvedDuration
	else
		local resolvedNow = now or os.clock()
		self.cooldownStartTime = resolvedNow
		self.cooldownEndTime = resolvedNow + resolvedDuration
	end
	return self:GetState()
end

function LauncherCooldownService:Clear(): CooldownState
	self.cooldownStartTime = 0
	self.cooldownEndTime = 0
	self.cooldownDuration = self.DefaultDuration
	return self:GetState()
end

function LauncherCooldownService:IsActive(now: number?): boolean
	return (now or os.clock()) < self.cooldownEndTime and self.cooldownEndTime > self.cooldownStartTime
end

function LauncherCooldownService:GetRemainingTime(now: number?): number
	return math.max(0, self.cooldownEndTime - (now or os.clock()))
end

function LauncherCooldownService:GetRatio(now: number?): number
	if not self:IsActive(now) then
		return 0
	end
	return LauncherCooldownService.ComputeCooldownRatio((now or os.clock()) - self.cooldownStartTime, self.cooldownDuration)
end

function LauncherCooldownService:GetState(): CooldownState
	return {
		cooldownStartTime = self.cooldownStartTime,
		cooldownEndTime = self.cooldownEndTime,
		cooldownDuration = self.cooldownDuration,
	}
end

return LauncherCooldownService
