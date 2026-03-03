--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local LobbyClientService = {}
LobbyClientService.__index = LobbyClientService

export type LobbyClientService = {
	RemotesRoot: Instance?,
	JoinArenaRemote: RemoteEvent?,
	LeaveArenaRemote: RemoteEvent?,
	StateUpdateRemote: RemoteEvent?,
	UIStateUpdateRemote: RemoteEvent?,
	RoundResultRemote: RemoteEvent?,
	RequestJoinArena: (self: LobbyClientService) -> (),
	RequestLeaveArena: (self: LobbyClientService) -> (),
	BindStateUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindUIStateUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindRoundResult: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
}

local function resolveRemote(path: string): RemoteEvent?
	local resolved = PathResolver.resolvePath(ReplicatedStorage, path)
	if resolved and resolved:IsA("RemoteEvent") then
		return resolved
	end
	if resolved ~= nil then
		warn("[ProjectTreeSpec] Missing:", path)
	end
	return nil
end

function LobbyClientService.new(): LobbyClientService
	local self = setmetatable({}, LobbyClientService)
	self.RemotesRoot = PathResolver.resolvePath(ReplicatedStorage, ProjectTreeSpec.Remotes.Folder)
	self.JoinArenaRemote = resolveRemote(ProjectTreeSpec.Remotes.JoinArena)
	self.LeaveArenaRemote = resolveRemote(ProjectTreeSpec.Remotes.LeaveArena)
	self.StateUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.StateUpdate)
	self.UIStateUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.UIStateUpdate)
	self.RoundResultRemote = resolveRemote(ProjectTreeSpec.Remotes.RoundResult)
	return self
end

function LobbyClientService:RequestJoinArena()
	local remote = self.JoinArenaRemote
	if remote == nil then
		return
	end
	if not RemoteContracts.Validate(RemoteContracts.Names.JoinArena) then
		warn("[RemoteContracts] Validation failed for JoinArena")
		return
	end
	remote:FireServer()
end

function LobbyClientService:RequestLeaveArena()
	local remote = self.LeaveArenaRemote
	if remote == nil then
		return
	end
	if not RemoteContracts.Validate(RemoteContracts.Names.LeaveArena) then
		warn("[RemoteContracts] Validation failed for LeaveArena")
		return
	end
	remote:FireServer()
end

function LobbyClientService:BindStateUpdate(handler: (any) -> ()): RBXScriptConnection?
	local remote = self.StateUpdateRemote
	if remote == nil then
		return nil
	end
	return remote.OnClientEvent:Connect(handler)
end

function LobbyClientService:BindUIStateUpdate(handler: (any) -> ()): RBXScriptConnection?
	local remote = self.UIStateUpdateRemote
	if remote == nil then
		return nil
	end
	return remote.OnClientEvent:Connect(handler)
end

function LobbyClientService:BindRoundResult(handler: (any) -> ()): RBXScriptConnection?
	local remote = self.RoundResultRemote
	if remote == nil then
		return nil
	end
	return remote.OnClientEvent:Connect(handler)
end

return LobbyClientService
