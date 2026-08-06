--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local QuestLogicService = {}
QuestLogicService.__index = QuestLogicService

local function deepCopy(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do copy[deepCopy(key)] = deepCopy(child) end
	return copy
end

function QuestLogicService.new()
	local self = setmetatable({}, QuestLogicService)
	self._changed = Instance.new("BindableEvent")
	self._claimCompleted = Instance.new("BindableEvent")
	self._snapshot = { Daily = {}, Main = {}, Weekly = { Points = 0 } }
	self._pendingClaims = {}
	local folder = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._updateRemote = folder:WaitForChild(RemoteContracts.Names.QuestUpdate) :: RemoteEvent
	self._claimRemote = folder:WaitForChild(RemoteContracts.Names.QuestClaim) :: RemoteEvent
	self._connection = self._updateRemote.OnClientEvent:Connect(function(payload)
		self:_handleServerUpdate(payload)
	end)
	return self
end

function QuestLogicService:Destroy()
	if self._connection then self._connection:Disconnect() end
	self._changed:Destroy()
	self._claimCompleted:Destroy()
end

function QuestLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function QuestLogicService:BindClaimCompleted(callback)
	return self._claimCompleted.Event:Connect(callback)
end

function QuestLogicService:GetSnapshot()
	return deepCopy(self._snapshot)
end

function QuestLogicService:_emitChanged()
	self._changed:Fire(self:GetSnapshot())
end

function QuestLogicService:_handleServerUpdate(payload: any)
	if type(payload) ~= "table" then return end
	if type(payload.Snapshot) == "table" then
		self._snapshot = payload.Snapshot
		self:_emitChanged()
	end
	if type(payload.ClaimResult) == "table" then
		self._pendingClaims[payload.ClaimResult.QuestId] = nil
		self._claimCompleted:Fire(deepCopy(payload.ClaimResult))
	end
end

function QuestLogicService:ClaimQuest(questId: string): boolean
	if self._pendingClaims[questId] then return false end
	self._pendingClaims[questId] = true
	self._claimRemote:FireServer(questId)
	return true
end

local defaultInstance = nil
function QuestLogicService.GetDefault()
	if not defaultInstance then defaultInstance = QuestLogicService.new() end
	return defaultInstance
end

return QuestLogicService
