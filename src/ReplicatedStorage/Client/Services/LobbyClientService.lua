--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local LobbyClientService = {}
LobbyClientService.__index = LobbyClientService

type Handler = (any) -> ()
type CachedRemoteName = "StateUpdate" | "UIStateUpdate" | "RoundResult" | "MatchScoreboardUpdate" | "MatchSummaryUpdate" | "GlobalTop100Update"

export type LobbyClientService = {
	RemotesRoot: Instance?,
	JoinArenaRemote: RemoteEvent?, LeaveArenaRemote: RemoteEvent?, StartSafeZoneRemote: RemoteEvent?, Plus1MinuteRemote: RemoteEvent?, EndRoundRemote: RemoteEvent?,
	MatchSummaryUpdateRemote: RemoteEvent?, StateUpdateRemote: RemoteEvent?, UIStateUpdateRemote: RemoteEvent?, RoundResultRemote: RemoteEvent?, MatchScoreboardUpdateRemote: RemoteEvent?, GlobalTop100UpdateRemote: RemoteEvent?,
	TeleportRemote: RemoteEvent?, DebugSpawnFoodRemote: RemoteEvent?, DebugResetLauncherRemote: RemoteEvent?, AttributeUpgradeRemote: RemoteEvent?, ConsumeHpPotionRemote: RemoteEvent?,
	RequestJoinArena: (self: LobbyClientService) -> (), RequestLeaveArena: (self: LobbyClientService) -> (), RequestTeleport: (self: LobbyClientService, mapName: string, spawnName: string) -> (),
	RequestStartSafeZone: (self: LobbyClientService) -> (), RequestPlus1Minute: (self: LobbyClientService) -> (), RequestEndRound: (self: LobbyClientService) -> (),
	RequestDebugSpawnFood: (self: LobbyClientService, mapName: string) -> (), RequestDebugResetLauncher: (self: LobbyClientService) -> (), RequestAttributeUpgrade: (self: LobbyClientService, attributeName: string) -> (), RequestConsumeHpPotion: (self: LobbyClientService) -> (),
	GetLastSnapshot: (self: LobbyClientService, remoteName: CachedRemoteName?) -> any,
	BindStateUpdate: (self: LobbyClientService, handler: Handler) -> RBXScriptConnection?, BindUIStateUpdate: (self: LobbyClientService, handler: Handler) -> RBXScriptConnection?, BindRoundResult: (self: LobbyClientService, handler: Handler) -> RBXScriptConnection?,
	BindMatchScoreboardUpdate: (self: LobbyClientService, handler: Handler) -> RBXScriptConnection?, BindMatchSummaryUpdate: (self: LobbyClientService, handler: Handler) -> RBXScriptConnection?, BindGlobalTop100Update: (self: LobbyClientService, handler: Handler) -> RBXScriptConnection?,
}

local REMOTE_FIELDS = {
	StateUpdate = "StateUpdateRemote", UIStateUpdate = "UIStateUpdateRemote", RoundResult = "RoundResultRemote",
	MatchScoreboardUpdate = "MatchScoreboardUpdateRemote", MatchSummaryUpdate = "MatchSummaryUpdateRemote", GlobalTop100Update = "GlobalTop100UpdateRemote",
}

local function resolveRemote(path: string): RemoteEvent?
	local resolved = PathResolver.resolvePath(ReplicatedStorage, path)
	if resolved and resolved:IsA("RemoteEvent") then return resolved end
	return nil
end


local function makeReplayConnection(disconnect: () -> ()): RBXScriptConnection
	return ({ Disconnect = disconnect, disconnect = disconnect } :: any) :: RBXScriptConnection
end

function LobbyClientService.new(): LobbyClientService
	local self = setmetatable({}, LobbyClientService)
	self._lastSnapshots = {}
	self._events = {}
	self._remoteConnections = {}
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
	if self.RemotesRoot then
		local teleport = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.TeleportRequest); if teleport and teleport:IsA("RemoteEvent") then self.TeleportRemote = teleport end
		local spawnFood = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.DebugSpawnFood); if spawnFood and spawnFood:IsA("RemoteEvent") then self.DebugSpawnFoodRemote = spawnFood end
		local resetLauncher = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.DebugResetLauncher); if resetLauncher and resetLauncher:IsA("RemoteEvent") then self.DebugResetLauncherRemote = resetLauncher end
	end
	for remoteName in pairs(REMOTE_FIELDS) do self:_ensureCachedRemote(remoteName :: CachedRemoteName) end
	return self
end

function LobbyClientService:_ensureCachedRemote(remoteName: CachedRemoteName)
	if self._events[remoteName] then return end
	self._events[remoteName] = Instance.new("BindableEvent")
	local remote = self[REMOTE_FIELDS[remoteName]]
	if remote then
		self._remoteConnections[remoteName] = remote.OnClientEvent:Connect(function(payload)
			self._lastSnapshots[remoteName] = DeepCopy.Copy(payload)
			self._events[remoteName]:Fire(DeepCopy.Copy(payload))
		end)
	end
end

function LobbyClientService:GetLastSnapshot(remoteName: CachedRemoteName?): any
	if remoteName then return DeepCopy.Copy(self._lastSnapshots[remoteName]) end
	return DeepCopy.Copy(self._lastSnapshots)
end

function LobbyClientService:_bindCached(remoteName: CachedRemoteName, handler: Handler): RBXScriptConnection?
	self:_ensureCachedRemote(remoteName)
	local event = self._events[remoteName]
	if not event then return nil end
	local connection = event.Event:Connect(handler)
	local snapshot = self:GetLastSnapshot(remoteName)
	if snapshot ~= nil then task.defer(handler, snapshot) end
	return makeReplayConnection(function() connection:Disconnect() end)
end

function LobbyClientService:RequestJoinArena() if self.JoinArenaRemote then self.JoinArenaRemote:FireServer() end end
function LobbyClientService:RequestLeaveArena() if self.LeaveArenaRemote then self.LeaveArenaRemote:FireServer() end end
function LobbyClientService:RequestStartSafeZone() if self.StartSafeZoneRemote then self.StartSafeZoneRemote:FireServer() end end
function LobbyClientService:RequestPlus1Minute() if RemoteContracts.Validate(RemoteContracts.Names.Plus1Minute) and self.Plus1MinuteRemote then self.Plus1MinuteRemote:FireServer() end end
function LobbyClientService:RequestEndRound()
	local now = os.clock()
	if self._lastEndRoundRequestAt and now - self._lastEndRoundRequestAt < 1 then
		return
	end
	self._lastEndRoundRequestAt = now
	local isValid = RemoteContracts.Validate(RemoteContracts.Names.EndRound)
	if isValid and self.EndRoundRemote then self.EndRoundRemote:FireServer() end
end
function LobbyClientService:RequestTeleport(mapName: string, spawnName: string) if RemoteContracts.Validate(RemoteContracts.Names.TeleportRequest, mapName, spawnName) and self.TeleportRemote then self.TeleportRemote:FireServer(mapName, spawnName) end end
function LobbyClientService:RequestDebugSpawnFood(mapName: string) if self.DebugSpawnFoodRemote then self.DebugSpawnFoodRemote:FireServer(mapName) end end
function LobbyClientService:RequestDebugResetLauncher() if self.DebugResetLauncherRemote then self.DebugResetLauncherRemote:FireServer() end end
function LobbyClientService:RequestAttributeUpgrade(attributeName: string) if RemoteContracts.Validate(RemoteContracts.Names.AttributeUpgrade, attributeName) and self.AttributeUpgradeRemote then self.AttributeUpgradeRemote:FireServer(attributeName) end end
function LobbyClientService:RequestConsumeHpPotion() if RemoteContracts.Validate(RemoteContracts.Names.ConsumeHpPotion) and self.ConsumeHpPotionRemote then self.ConsumeHpPotionRemote:FireServer() end end
function LobbyClientService:BindStateUpdate(handler: Handler): RBXScriptConnection? return self:_bindCached("StateUpdate", handler) end
function LobbyClientService:BindUIStateUpdate(handler: Handler): RBXScriptConnection? return self:_bindCached("UIStateUpdate", handler) end
function LobbyClientService:BindRoundResult(handler: Handler): RBXScriptConnection? return self:_bindCached("RoundResult", handler) end
function LobbyClientService:BindMatchScoreboardUpdate(handler: Handler): RBXScriptConnection? return self:_bindCached("MatchScoreboardUpdate", handler) end
function LobbyClientService:BindGlobalTop100Update(handler: Handler): RBXScriptConnection? return self:_bindCached("GlobalTop100Update", handler) end
function LobbyClientService:BindMatchSummaryUpdate(handler: Handler): RBXScriptConnection? return self:_bindCached("MatchSummaryUpdate", handler) end

return LobbyClientService
