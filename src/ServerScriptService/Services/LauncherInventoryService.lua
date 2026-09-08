--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local LauncherInventoryService = {}
LauncherInventoryService.__index = LauncherInventoryService

function LauncherInventoryService.new(context)
	local self = setmetatable({}, LauncherInventoryService)
	self._context = context
	self._equipRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
	self._unequipRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.UnequipLauncher) :: RemoteEvent?
	return self
end

function LauncherInventoryService:_feedback(player: Player, success: boolean, reason: string?)
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, { EventType = "LauncherEquipResult", Payload = { Success = success, Reason = reason } })
	end
end

function LauncherInventoryService:Equip(player: Player, instanceId: string)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state or state.LocationState ~= GameStates.SessionState.Lobby then
		self:_feedback(player, false, "LobbyOnly")
		return false, "LobbyOnly"
	end
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return false, "MissingPlayerDataService" end
	local ok, reason = dataService:EquipLauncher(player, instanceId)
	if ok and stateService then
		stateService:_syncInventoryFromData(player)
		stateService:SetEquippedLauncherInstance(player, instanceId)
	end
	self:_feedback(player, ok, reason)
	return ok, reason
end

function LauncherInventoryService:Unequip(player: Player)
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return false, "MissingPlayerDataService" end
	dataService:UnequipLauncher(player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService then
		stateService:_syncInventoryFromData(player)
		stateService:SetEquippedLauncherInstance(player, "default_normal_launcher")
	end
	return true, nil
end

function LauncherInventoryService:Init()
	if self._equipRemote then self._equipRemote.OnServerEvent:Connect(function(player, instanceId)
		if RemoteContracts.Validate(RemoteContracts.Names.EquipLauncher, instanceId) then self:Equip(player, instanceId) end
	end) end
	if self._unequipRemote then self._unequipRemote.OnServerEvent:Connect(function(player)
		if RemoteContracts.Validate(RemoteContracts.Names.UnequipLauncher) then self:Unequip(player) end
	end) end
end

return LauncherInventoryService
