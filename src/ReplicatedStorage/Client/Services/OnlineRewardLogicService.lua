--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local OnlineRewardLogicService = {}
OnlineRewardLogicService.__index = OnlineRewardLogicService

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

function OnlineRewardLogicService.new()
	local self = setmetatable({}, OnlineRewardLogicService)
	self._changed = Instance.new("BindableEvent")
	self._snapshot = {
		CycleId = 0,
		RewardSetId = "",
		ElapsedSeconds = 0,
		CycleDurationSeconds = 1800,
		ReadyCount = 0,
		slots = {},
		columns = 3,
		rows = 5,
	}
	self._pendingClaims = {}

	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._requestRemote = remotes:WaitForChild(RemoteContracts.Names.OnlineRewardRequest) :: RemoteEvent
	self._updateRemote = remotes:WaitForChild(RemoteContracts.Names.OnlineRewardUpdate) :: RemoteEvent
	self._debugResetRemote = remotes:WaitForChild(RemoteContracts.Names.ResetTimeOnlineReward) :: RemoteEvent
	self._updateConnection = self._updateRemote.OnClientEvent:Connect(function(payload)
		self:_handleServerUpdate(payload)
	end)
	return self
end

function OnlineRewardLogicService:Destroy()
	if self._updateConnection then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end
	if self._changed then
		self._changed:Destroy()
	end
	table.clear(self._pendingClaims)
end

function OnlineRewardLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function OnlineRewardLogicService:GetSnapshot()
	return deepCopy(self._snapshot)
end

function OnlineRewardLogicService:_handleServerUpdate(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local result = payload.Result
	if type(result) == "table" then
		if type(result.RewardId) == "string" then
			self._pendingClaims[result.RewardId] = nil
		elseif result.Action == "Claim" then
			table.clear(self._pendingClaims)
		end
	end

	if type(payload.Snapshot) == "table" then
		self._snapshot = deepCopy(payload.Snapshot)
		self._changed:Fire(self:GetSnapshot())
	end
end

function OnlineRewardLogicService:RequestSnapshot()
	if self._requestRemote then
		self._requestRemote:FireServer({ Action = "Snapshot" })
	end
end

function OnlineRewardLogicService:ClaimReward(rewardId: string): boolean
	if type(rewardId) ~= "string" or rewardId == "" then
		return false
	end
	local now = os.clock()
	local pendingAt = self._pendingClaims[rewardId]
	if pendingAt and now - pendingAt < 8 then
		return false
	end
	if self._snapshot.CycleId < 1 then
		return false
	end

	self._pendingClaims[rewardId] = now
	self._requestRemote:FireServer({
		Action = "Claim",
		RewardId = rewardId,
		CycleId = self._snapshot.CycleId,
	})
	return true
end

function OnlineRewardLogicService:RequestDebugReset()
	if RunService:IsStudio() and self._debugResetRemote then
		self._debugResetRemote:FireServer()
	end
end

local defaultInstance = nil

function OnlineRewardLogicService.GetDefault()
	if not defaultInstance then
		defaultInstance = OnlineRewardLogicService.new()
	end
	return defaultInstance
end

return OnlineRewardLogicService
