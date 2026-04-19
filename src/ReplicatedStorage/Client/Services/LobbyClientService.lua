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
	TeleportRemote: RemoteEvent?,
	DebugSpawnFoodRemote: RemoteEvent?,
	DebugResetSlingRemote: RemoteEvent?,
	ConsumeHpPotionRemote: RemoteEvent?,
	RequestJoinArena: (self: LobbyClientService) -> (),
	RequestLeaveArena: (self: LobbyClientService) -> (),
	RequestTeleport: (self: LobbyClientService, mapName: string, spawnName: string) -> (),
	RequestDebugSpawnFood: (self: LobbyClientService, mapName: string) -> (),
	RequestDebugResetSling: (self: LobbyClientService) -> (),
	RequestConsumeHpPotion: (self: LobbyClientService) -> (),
	BindStateUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindUIStateUpdate: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
	BindRoundResult: (self: LobbyClientService, handler: (any) -> ()) -> RBXScriptConnection?,
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
	self.StateUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.StateUpdate)
	self.UIStateUpdateRemote = resolveRemote(ProjectTreeSpec.Remotes.UIStateUpdate)
	self.RoundResultRemote = resolveRemote(ProjectTreeSpec.Remotes.RoundResult)
	self.ConsumeHpPotionRemote = resolveRemote(ProjectTreeSpec.Remotes.ConsumeHpPotion)
	if self.RemotesRoot then
		local teleport = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.TeleportRequest)
		if teleport and teleport:IsA("RemoteEvent") then
			self.TeleportRemote = teleport
		end
		local spawnFood = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.DebugSpawnFood)
		if spawnFood and spawnFood:IsA("RemoteEvent") then
			self.DebugSpawnFoodRemote = spawnFood
		end
		local resetSling = self.RemotesRoot:FindFirstChild(RemoteContracts.Names.DebugResetSling)
		if resetSling and resetSling:IsA("RemoteEvent") then
			self.DebugResetSlingRemote = resetSling
		end
	end
	return self
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

function LobbyClientService:RequestDebugResetSling()
	if self.DebugResetSlingRemote then
		self.DebugResetSlingRemote:FireServer()
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
	if self.StateUpdateRemote == nil then
		return nil
	end
	return self.StateUpdateRemote.OnClientEvent:Connect(handler)
end

function LobbyClientService:BindUIStateUpdate(handler: (any) -> ()): RBXScriptConnection?
	if self.UIStateUpdateRemote == nil then
		return nil
	end
	return self.UIStateUpdateRemote.OnClientEvent:Connect(handler)
end

function LobbyClientService:BindRoundResult(handler: (any) -> ()): RBXScriptConnection?
	if self.RoundResultRemote == nil then
		return nil
	end
	return self.RoundResultRemote.OnClientEvent:Connect(handler)
end

return LobbyClientService
