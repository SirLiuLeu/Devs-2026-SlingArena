--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local LobbyClientService = {}
LobbyClientService.__index = LobbyClientService

local CACHE_KEYS = {
	StateUpdate = "StateUpdate",
	UIStateUpdate = "UIStateUpdate",
	RoundResult = "RoundResult",
	MatchScoreboardUpdate = "MatchScoreboardUpdate",
	MatchSummaryUpdate = "MatchSummaryUpdate",
	GlobalTop100Update = "GlobalTop100Update",
}

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

export type LobbyClientService = {
	RemotesRoot: Instance?,
	JoinArenaRemote: RemoteEvent?,
	LeaveArenaRemote: RemoteEvent?,
	StartSafeZoneRemote: RemoteEvent?,
	Plus1MinuteRemote: RemoteEvent?,
	EndRoundRemote: RemoteEvent?,
	MatchSummaryUpdateRemote: RemoteEvent?,
	StateUpdateRemote: RemoteEvent?,
	UIStateUpdateRemote: RemoteEvent?,
	RoundResultRemote: RemoteEvent?,
	MatchScoreboardUpdateRemote: RemoteEvent?,
	GlobalTop100UpdateRemote: RemoteEvent?,
	TeleportRemote: RemoteEvent?,
	DebugSpawnFoodRemote: RemoteEvent?,
	DebugResetLauncherRemote: RemoteEvent?,
	AttributeUpgradeRemote: RemoteEvent?,
	ConsumeHpPotionRemote: RemoteEvent?,
	RequestJoinArena: (self: LobbyClientService) -> (),
	RequestLeaveArena: (self: LobbyClientService) -> (),
	RequestTeleport: (self: LobbyClientService, mapName: string, spawnName: string) -> (),
	RequestStartSafeZone: (self: LobbyClientService) -> (),
	RequestPlus1Minute: (self: LobbyClientService) -> (),
	RequestEndRound: (self: LobbyClientService) -> (),
	RequestDebugSpawnFood: (self: LobbyClientService, mapName: string) -> (),
	RequestDebugResetLauncher: (self: LobbyClientService) -> (),
	RequestAttributeUpgrade: (self: LobbyClientService, attributeName: string) -> (),
	RequestConsumeHpPotion: (self: LobbyClientService) -> (),
	BindStateUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindUIStateUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindRoundResult: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindMatchScoreboardUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindMatchSummaryUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindGlobalTop100Update: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	GetLastSnapshot: (self: LobbyClientService) -> { [string]: any },
}

local function resolveRemote(path: string): RemoteEvent?
	local resolved = PathResolver.resolvePath(ReplicatedStorage, path)
	if resolved and resolved:IsA("RemoteEvent") then
		return resolved
	end
	return nil
end

function LobbyClientService.new(): LobbyClientService
	local self = setmetatable({}, LobbyClientService)
	self.RemotesRoot = PathResolver.resolvePath(ReplicatedStorage, ProjectTreeSpec.Remotes.Folder)
	self.JoinArenaRemote = resolveRemote(ProjectTreeSpec.Remotes.JoinArena)
	self.LeaveArenaRemote = resolveRemote(ProjectTreeSpec.Remotes.LeaveArena)
	self.StartSafeZoneRemote = resolveRemote(ProjectTreeSpec.Remotes.StartSafeZone)
	self.Plus1MinuteRemote = resolveRemote(ProjectTreeSpec.Remotes.Plus1Minute)
	self.EndRoundRemote = resolveRemote(ProjectTreeSpec.Remotes.EndRound)
	self.StateUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.StateUpdate)
	self.UIStateUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.UIStateUpdate)
	self.RoundResultRemote = resolveRemote(ProjectTreeSpec.Remotes.RoundResult)
	self.MatchScoreboardUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.MatchScoreboardUpdate)
	self.GlobalTop100UpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.GlobalTop100Update)
	self.MatchSummaryUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.MatchSummaryUpdate)
	self.AttributeUpgradeRemote = resolveRemote(ProjectTreeSpec.Remotes.AttributeUpgrade)
	self.ConsumeHpPotionRemote = resolveRemote(ProjectTreeSpec.Remotes.ConsumeHpPotion)
	self._lastPayloads = {}
	self._cacheEvents = {}
	self._remoteConnections = {}
	for _, cacheKey in pairs(CACHE_KEYS) do
		self._cacheEvents[cacheKey] = Instance.new("BindableEvent")
	end
	if self.RemotesRoot then
		local teleport = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.TeleportRequest)
		if teleport and teleport:IsA("RemoteEvent") then
			self.TeleportRemote = teleport
		end
		local spawnFood = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.DebugSpawnFood)
		if spawnFood and spawnFood:IsA("RemoteEvent") then
			self.DebugSpawnFoodRemote = spawnFood
		end
		local resetLauncher = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.DebugResetLauncher)
		if resetLauncher and resetLauncher:IsA("RemoteEvent") then
			self.DebugResetLauncherRemote = resetLauncher
		end
	end
	self:_bindCacheRemote(CACHE_KEYS.StateUpdate, self.StateUpdateRemote)
	self:_bindCacheRemote(CACHE_KEYS.UIStateUpdate, self.UIStateUpdateRemote)
	self:_bindCacheRemote(CACHE_KEYS.RoundResult, self.RoundResultRemote)
	self:_bindCacheRemote(CACHE_KEYS.MatchScoreboardUpdate, self.MatchScoreboardUpdateRemote)
	self:_bindCacheRemote(CACHE_KEYS.MatchSummaryUpdate, self.MatchSummaryUpdateRemote)
	self:_bindCacheRemote(CACHE_KEYS.GlobalTop100Update, self.GlobalTop100UpdateRemote)
	return self
end

function LobbyClientService:_bindCacheRemote(cacheKey: string, remote: RemoteEvent?)
	if remote == nil then
		return
	end

	self._remoteConnections[cacheKey] = remote.OnClientEvent:Connect(function(payload)
		self:_setCachedPayload(cacheKey, payload)
	end)
end

function LobbyClientService:_setCachedPayload(cacheKey: string, payload: any)
	local cachedPayload = deepCopy(payload)
	self._lastPayloads[cacheKey] = cachedPayload
	local changedEvent = self._cacheEvents[cacheKey]
	if changedEvent then
		changedEvent:Fire(deepCopy(cachedPayload))
	end
end

function LobbyClientService:_bindCached(cacheKey: string, handler: (any) -> ()): RBXScriptConnection?
	local changedEvent = self._cacheEvents[cacheKey]
	if changedEvent == nil then
		return nil
	end

	local connection = changedEvent.Event:Connect(handler)
	local lastPayload = self._lastPayloads[cacheKey]
	if lastPayload ~= nil then
		task.defer(function()
			if connection.Connected then
				handler(deepCopy(lastPayload))
			end
		end)
	end
	return connection
end

function LobbyClientService:GetLastSnapshot(): { [string]: any }
	local snapshot = {}
	for cacheKey, payload in pairs(self._lastPayloads) do
		snapshot[cacheKey] = deepCopy(payload)
	end
	return snapshot
end

function LobbyClientService:RequestJoinArena()
	if self.JoinArenaRemote then
		self.JoinArenaRemote:FireServer()
	end
end

function LobbyClientService:RequestLeaveArena()
	if self.LeaveArenaRemote then
		self.LeaveArenaRemote:FireServer()
	end
end

function LobbyClientService:RequestStartSafeZone()
	if self.StartSafeZoneRemote then
		self.StartSafeZoneRemote:FireServer()
	end
end

function LobbyClientService:RequestPlus1Minute()
	if not RemoteContracts.Validate(RemoteContracts.Names.Plus1Minute) then
		return
	end
	if self.Plus1MinuteRemote then
		self.Plus1MinuteRemote:FireServer()
	end
end

function LobbyClientService:RequestEndRound()
	if not RemoteContracts.Validate(RemoteContracts.Names.EndRound) then
		return
	end
	if self.EndRoundRemote then
		self.EndRoundRemote:FireServer()
	end
end

function LobbyClientService:RequestTeleport(mapName: string, spawnName: string)
	if not RemoteContracts.Validate(RemoteContracts.Names.TeleportRequest, mapName, spawnName) then
		return
	end
	if self.TeleportRemote then
		self.TeleportRemote:FireServer(mapName, spawnName)
	end
end

function LobbyClientService:RequestDebugSpawnFood(mapName: string)
		if self.DebugSpawnFoodRemote then
		self.DebugSpawnFoodRemote:FireServer(mapName)
	end
end

function LobbyClientService:RequestDebugResetLauncher()
	if self.DebugResetLauncherRemote then
		self.DebugResetLauncherRemote:FireServer()
	end
end

function LobbyClientService:RequestAttributeUpgrade(attributeName: string)
	if not RemoteContracts.Validate(RemoteContracts.Names.AttributeUpgrade, attributeName) then
		return
	end
	if self.AttributeUpgradeRemote then
		self.AttributeUpgradeRemote:FireServer(attributeName)
	end
end

function LobbyClientService:RequestConsumeHpPotion()
	if not RemoteContracts.Validate(RemoteContracts.Names.ConsumeHpPotion) then
		return
	end
	if self.ConsumeHpPotionRemote then
		self.ConsumeHpPotionRemote:FireServer()
	end
end

function LobbyClientService:BindStateUpdate(handler: (any) -> ()): RBXScriptConnection?
	return self:_bindCached(CACHE_KEYS.StateUpdate, handler)
end

function LobbyClientService:BindUIStateUpdate(handler: (any) -> ()): RBXScriptConnection?
	return self:_bindCached(CACHE_KEYS.UIStateUpdate, handler)
end

function LobbyClientService:BindRoundResult(handler: (any) -> ()): RBXScriptConnection?
	return self:_bindCached(CACHE_KEYS.RoundResult, handler)
end

function LobbyClientService:BindMatchScoreboardUpdate(handler: (any) -> ()): RBXScriptConnection?
	return self:_bindCached(CACHE_KEYS.MatchScoreboardUpdate, handler)
end

function LobbyClientService:BindGlobalTop100Update(handler: (any) -> ()): RBXScriptConnection?
	return self:_bindCached(CACHE_KEYS.GlobalTop100Update, handler)
end

function LobbyClientService:BindMatchSummaryUpdate(handler: (any) -> ()): RBXScriptConnection?
	return self:_bindCached(CACHE_KEYS.MatchSummaryUpdate, handler)
end

return LobbyClientService
