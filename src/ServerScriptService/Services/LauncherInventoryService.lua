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
	self._sellRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.SellLauncher) :: RemoteEvent?
	return self
end

function LauncherInventoryService:_feedback(player: Player, success: boolean, reason: string?, eventType: string?, salePrice: number?)
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, {
			EventType = eventType or "LauncherEquipResult",
			Payload = { Success = success, Reason = reason, SalePrice = salePrice },
		})
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
		local stateApplied = stateService:SetEquippedLauncherInstance(player, instanceId)
		if not stateApplied then
			warn(string.format("[LAUNCHER_INVENTORY] Persistent Launcher %s could not be applied to state for %s.", instanceId, player.Name))
		end
		local data = dataService:GetData(player)
		local owned = data and data.OwnedLaunchers and data.OwnedLaunchers[instanceId]
		local playerService = ServiceResolver.Get(self._context, "PlayerService")
		if owned and playerService and playerService:GetPawn(player) then
			if not playerService:EquipLauncherModel(player, owned.definitionId) then
				warn(string.format("[LAUNCHER_INVENTORY] Equipped state changed to %s, but the live Launcher model could not be refreshed for %s; the next Launcher spawn will use it.", tostring(owned.definitionId), player.Name))
			end
		end
	end
	self:_feedback(player, ok, reason)
	return ok, reason
end

function LauncherInventoryService:Unequip(player: Player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state or state.LocationState ~= GameStates.SessionState.Lobby then
		self:_feedback(player, false, "LobbyOnly")
		return false, "LobbyOnly"
	end
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return false, "MissingPlayerDataService" end
	dataService:UnequipLauncher(player)
	if stateService then
		stateService:_syncInventoryFromData(player)
		stateService:SetEquippedLauncherInstance(player, "default_normal_launcher")
	end
	self:_feedback(player, true, nil)
	return true, nil
end

function LauncherInventoryService:Sell(player: Player, instanceId: string)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state or state.LocationState ~= GameStates.SessionState.Lobby then
		self:_feedback(player, false, "LobbyOnly", "LauncherSellResult", 0)
		return false, "LobbyOnly"
	end
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService or typeof(dataService.SellLauncher) ~= "function" then
		self:_feedback(player, false, "MissingPlayerDataService", "LauncherSellResult", 0)
		return false, "MissingPlayerDataService"
	end
	local ok, reason, salePrice = dataService:SellLauncher(player, instanceId)
	if ok and stateService then
		stateService:_syncInventoryFromData(player)
		local updatedState = stateService:GetState(player)
		if updatedState then updatedState.Diamonds = dataService:GetDiamonds(player) end
		stateService:PublishState(player)
	end
	self:_feedback(player, ok, reason, "LauncherSellResult", salePrice or 0)
	return ok, reason
end

function LauncherInventoryService:Init()
	if self._equipRemote then self._equipRemote.OnServerEvent:Connect(function(player, instanceId)
		if RemoteContracts.Validate(RemoteContracts.Names.EquipLauncher, instanceId) then self:Equip(player, instanceId) end
	end) end
	if self._unequipRemote then self._unequipRemote.OnServerEvent:Connect(function(player)
		if RemoteContracts.Validate(RemoteContracts.Names.UnequipLauncher) then self:Unequip(player) end
	end) end
	if self._sellRemote then
		self._sellRemote.OnServerEvent:Connect(function(player: Player, instanceId: any)
			if not RemoteContracts.Validate(RemoteContracts.Names.SellLauncher, instanceId) then
				self:_feedback(player, false, "InvalidRequest", "LauncherSellResult", 0)
				return
			end
			self:Sell(player, instanceId)
		end)
	else
		warn("[LAUNCHER_INVENTORY] Missing ReplicatedStorage.LauncherArenaRemotes.SellLauncher (RemoteEvent); create it through Rojo.")
	end
end

return LauncherInventoryService
