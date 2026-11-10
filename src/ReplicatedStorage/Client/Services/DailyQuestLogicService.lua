--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local DailyQuestLogicService = {}
DailyQuestLogicService.__index = DailyQuestLogicService

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

function DailyQuestLogicService.new()
	local self = setmetatable({}, DailyQuestLogicService)
	self._changed = Instance.new("BindableEvent")
	self._claimCompleted = Instance.new("BindableEvent")
	self._skipCompleted = Instance.new("BindableEvent")
	self._snapshot = {
		DailyQuest = {
			CurrentStep = 1,
			CompletedSteps = 0,
			MaxSteps = 5,
			Status = "Preparing",
			NextQuestAt = 0,
			ActiveQuest = nil,
		},
		Weekly = { Points = 0 },
	}
	self._pendingClaim = nil
	self._pendingSkip = nil

	local folder = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._updateRemote = folder:WaitForChild(RemoteContracts.Names.QuestUpdate) :: RemoteEvent
	self._claimRemote = folder:WaitForChild(RemoteContracts.Names.QuestClaim) :: RemoteEvent
	self._skipRemote = folder:WaitForChild(RemoteContracts.Names.QuestSkip) :: RemoteEvent
	self._connection = self._updateRemote.OnClientEvent:Connect(function(payload)
		self:_handleServerUpdate(payload)
	end)
	return self
end

function DailyQuestLogicService:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self._changed:Destroy()
	self._claimCompleted:Destroy()
	self._skipCompleted:Destroy()
end

function DailyQuestLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function DailyQuestLogicService:BindClaimCompleted(callback)
	return self._claimCompleted.Event:Connect(callback)
end

function DailyQuestLogicService:BindSkipCompleted(callback)
	return self._skipCompleted.Event:Connect(callback)
end

function DailyQuestLogicService:GetSnapshot()
	return deepCopy(self._snapshot)
end

function DailyQuestLogicService:_handleServerUpdate(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.Snapshot) == "table" then
		self._snapshot = deepCopy(payload.Snapshot)
		self._changed:Fire(self:GetSnapshot())
	end
	if type(payload.ClaimResult) == "table" then
		local result = deepCopy(payload.ClaimResult)
		if result.AssignmentId == self._pendingClaim then
			self._pendingClaim = nil
		end
		self._claimCompleted:Fire(result)
	end
	if type(payload.SkipResult) == "table" then
		local result = deepCopy(payload.SkipResult)
		if result.AssignmentId == self._pendingSkip then
			self._pendingSkip = nil
		end
		self._skipCompleted:Fire(result)
	end
end

function DailyQuestLogicService:ClaimQuest(assignmentId: string): boolean
	if type(assignmentId) ~= "string" or assignmentId == "" or self._pendingClaim then
		return false
	end
	self._pendingClaim = assignmentId
	self._claimRemote:FireServer(assignmentId)
	return true
end

function DailyQuestLogicService:SkipQuest(assignmentId: string): boolean
	if type(assignmentId) ~= "string" or assignmentId == "" or self._pendingSkip then
		return false
	end
	self._pendingSkip = assignmentId
	self._skipRemote:FireServer(assignmentId)
	return true
end

local defaultInstance = nil
function DailyQuestLogicService.GetDefault()
	if not defaultInstance then
		defaultInstance = DailyQuestLogicService.new()
	end
	return defaultInstance
end

return DailyQuestLogicService
