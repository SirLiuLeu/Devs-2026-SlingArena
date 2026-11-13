--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local DailyLoginLogicService = {}
DailyLoginLogicService.__index = DailyLoginLogicService

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = deepCopy(child)
	end
	return result
end

local function formatCountdown(seconds: number): string
	local safeSeconds = math.max(0, math.floor(seconds))
	local hours = math.floor(safeSeconds / 3600)
	local minutes = math.floor((safeSeconds % 3600) / 60)
	local remainder = safeSeconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, remainder)
end

function DailyLoginLogicService.new()
	local self = setmetatable({}, DailyLoginLogicService)
	self._changed = Instance.new("BindableEvent")
	self._snapshot = {
		CycleId = 0,
		CurrentDay = 1,
		LastClaimDayKey = 0,
		TodayKey = 0,
		ServerNow = 0,
		NextResetAt = 0,
		CanClaim = false,
		entries = {},
	}
	self._snapshotReceivedAt = 0
	self._pendingClaims = {}

	local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	self._requestRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.DailyLoginRequest) :: RemoteEvent?
	self._updateRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.DailyLoginUpdate) :: RemoteEvent?
	if self._updateRemote and self._updateRemote:IsA("RemoteEvent") then
		self._updateConnection = self._updateRemote.OnClientEvent:Connect(function(payload)
			self:_handleServerUpdate(payload)
		end)
	else
		self._updateRemote = nil
		warn("[DailyLoginLogic] LauncherArenaRemotes.DailyLoginUpdate is missing.")
	end
	if not self._requestRemote or not self._requestRemote:IsA("RemoteEvent") then
		self._requestRemote = nil
		warn("[DailyLoginLogic] LauncherArenaRemotes.DailyLoginRequest is missing.")
	end
	return self
end

function DailyLoginLogicService:Destroy()
	if self._updateConnection then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end
	if self._changed then
		self._changed:Destroy()
	end
	table.clear(self._pendingClaims)
end

function DailyLoginLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function DailyLoginLogicService:_handleServerUpdate(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local result = payload.Result
	if type(result) == "table" then
		if typeof(result.Day) == "number" then
			self._pendingClaims[result.Day] = nil
		elseif result.Action == "Claim" then
			table.clear(self._pendingClaims)
		end
	end

	if type(payload.Snapshot) == "table" then
		self._snapshot = deepCopy(payload.Snapshot)
		self._snapshot.Result = if type(result) == "table" then deepCopy(result) else nil
		self._snapshotReceivedAt = os.clock()
		self._changed:Fire(self:GetSnapshot())
	elseif type(result) == "table" then
		self._snapshot.Result = deepCopy(result)
		self._changed:Fire(self:GetSnapshot())
	end
end

function DailyLoginLogicService:RequestSnapshot(): boolean
	if not self._requestRemote then
		warn("[DailyLoginLogic] Cannot request snapshot because DailyLoginRequest is missing.")
		return false
	end
	self._requestRemote:FireServer({ Action = "Snapshot" })
	return true
end

function DailyLoginLogicService:ClaimDay(day: number): boolean
	local targetDay = math.floor(tonumber(day) or 0)
	if targetDay < 1 or targetDay > 7 or not self._requestRemote then
		return false
	end
	if self._snapshot.CycleId < 1 or targetDay ~= self._snapshot.CurrentDay or self._snapshot.CanClaim ~= true then
		return false
	end
	if self._pendingClaims[targetDay] ~= nil then
		return false
	end

	self._pendingClaims[targetDay] = os.clock()
	self._requestRemote:FireServer({
		Action = "Claim",
		Day = targetDay,
		CycleId = self._snapshot.CycleId,
	})
	return true
end

function DailyLoginLogicService:IsClaimPending(day: number): boolean
	return self._pendingClaims[day] ~= nil
end

function DailyLoginLogicService:RequestDebugAdvance24h(): boolean
	if not RunService:IsStudio() then
		warn("[DailyLoginDebug] Plus24h is only available in Studio.")
		return false
	end
	if not self._requestRemote then
		warn("[DailyLoginDebug] DailyLoginRequest is missing.")
		return false
	end
	self._requestRemote:FireServer({ Action = "DebugAdvance24h" })
	return true
end

function DailyLoginLogicService:GetCountdownSeconds(): number
	if self._snapshotReceivedAt <= 0 or tonumber(self._snapshot.NextResetAt) == nil then
		return 0
	end
	local elapsed = math.max(0, os.clock() - self._snapshotReceivedAt)
	local estimatedServerNow = (tonumber(self._snapshot.ServerNow) or 0) + elapsed
	return math.max(0, math.ceil((tonumber(self._snapshot.NextResetAt) or estimatedServerNow) - estimatedServerNow))
end

function DailyLoginLogicService:GetCountdownText(): string
	return formatCountdown(self:GetCountdownSeconds())
end

function DailyLoginLogicService:GetSnapshot(): any
	local snapshot = deepCopy(self._snapshot)
	snapshot.SecondsUntilReset = self:GetCountdownSeconds()
	snapshot.CountdownText = formatCountdown(snapshot.SecondsUntilReset)
	for _, entry in ipairs(snapshot.entries or {}) do
		if entry.state == "Waiting" then
			entry.timerText = snapshot.CountdownText
		elseif entry.state == "Locked" then
			entry.timerText = "Locked"
		else
			entry.timerText = ""
		end
	end
	return snapshot
end

local defaultInstance = nil

function DailyLoginLogicService.GetDefault()
	if not defaultInstance then
		defaultInstance = DailyLoginLogicService.new()
	end
	return defaultInstance
end

return DailyLoginLogicService
