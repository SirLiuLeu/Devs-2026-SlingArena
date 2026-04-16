--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MockData = require(ReplicatedStorage.Client.Services.MockData)

local DailyLoginLogicService = {}
DailyLoginLogicService.__index = DailyLoginLogicService

local function cloneEntry(entry)
	local result = {}
	for key, value in pairs(entry) do
		result[key] = value
	end
	return result
end

function DailyLoginLogicService.new()
	local self = setmetatable({}, DailyLoginLogicService)
	self._changed = Instance.new("BindableEvent")
	self._entries = {}
	self._dayCursor = 1
	return self
end

function DailyLoginLogicService:Destroy()
	if self._changed then
		self._changed:Destroy()
	end
end

function DailyLoginLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function DailyLoginLogicService:_emitChanged()
	self._changed:Fire(self:GetSnapshot())
end

function DailyLoginLogicService:GetSnapshot()
	local entries = {}
	for i, entry in ipairs(self._entries) do
		entries[i] = cloneEntry(entry)
	end
	return {
		currentDay = self._dayCursor,
		entries = entries,
	}
end

function DailyLoginLogicService:_refreshStates()
	for _, entry in ipairs(self._entries) do
		if entry.claimed then
			entry.state = "Claimed"
		elseif entry.day == self._dayCursor then
			entry.state = "Claimable"
		else
			entry.state = "Locked"
		end
	end
end

function DailyLoginLogicService:LoadMockData()
	local data = MockData.GetDailyLoginState()
	self._entries = data.entries or {}
	self._dayCursor = math.clamp(math.floor(data.currentDay or 1), 1, 7)
	self:_refreshStates()
	self:_emitChanged()
end

function DailyLoginLogicService:ClaimDay(day: number): (boolean, string)
	local targetDay = math.floor(day)
	for _, entry in ipairs(self._entries) do
		if entry.day == targetDay then
			if entry.claimed then
				return false, "ALREADY_CLAIMED"
			end
			if targetDay ~= self._dayCursor then
				return false, "NOT_CLAIMABLE"
			end

			entry.claimed = true
			if self._dayCursor < 7 then
				self._dayCursor += 1
			end
			self:_refreshStates()
			self:_emitChanged()
			return true, string.format("Claimed day %d", targetDay)
		end
	end
	return false, "DAY_NOT_FOUND"
end

local defaultInstance = nil

function DailyLoginLogicService.GetDefault()
	if not defaultInstance then
		defaultInstance = DailyLoginLogicService.new()
	end
	return defaultInstance
end

return DailyLoginLogicService
