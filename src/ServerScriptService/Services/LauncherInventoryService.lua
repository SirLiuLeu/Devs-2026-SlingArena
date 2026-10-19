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

function LauncherInventoryService:_feedback(player: Player, success: boolean, reason: string?, eventType: string?, salePrice: number?, extraPayload: { [string]: any }?)
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	local payload = { Success = success, Reason = reason, SalePrice = salePrice }
	if extraPayload then
		for key, value in pairs(extraPayload) do payload[key] = value end
	end
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, {
			EventType = eventType or "LauncherEquipResult",
			Payload = payload,
		})
	else
		warn(string.format("[LAUNCHER_INVENTORY] Cannot send %s feedback to %s: GameplayFeedback RemoteEvent missing.", eventType or "LauncherEquipResult", player.Name))
	end
	print(string.format("[LAUNCHER_INVENTORY] Feedback: player=%s event=%s success=%s reason=%s", player.Name, eventType or "LauncherEquipResult", tostring(success), tostring(reason or "-")))
end

function LauncherInventoryService:Equip(player: Player, instanceId: string)
	print(string.format("[LAUNCHER_INVENTORY] Equip request received: player=%s instanceId=%s", player.Name, tostring(instanceId)))
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state or state.LocationState ~= GameStates.SessionState.Lobby then
		self:_feedback(player, false, "LobbyOnly")
		return false, "LobbyOnly"
	end

	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then
		self:_feedback(player, false, "MissingPlayerDataService")
		return false, "MissingPlayerDataService"
	end

	local ok, reason = dataService:EquipLauncher(player, instanceId)
	if not ok then
		warn(string.format("[LAUNCHER_INVENTORY] Equip rejected: player=%s instanceId=%s reason=%s", player.Name, instanceId, tostring(reason or "Unknown")))
		self:_feedback(player, false, reason or "EquipFailed")
		return false, reason
	end

	stateService:_syncInventoryFromData(player)
	local stateApplied = stateService:SetEquippedLauncherInstance(player, instanceId)
	if not stateApplied then
		warn(string.format("[LAUNCHER_INVENTORY] Persistent equip changed to %s but runtime state rejected it for %s.", instanceId, player.Name))
		self:_feedback(player, false, "StateApplyFailed", nil, nil, { LauncherId = instanceId, VisualStatus = "Failed" })
		return false, "StateApplyFailed"
	end

	local data = dataService:GetData(player)
	local owned = data and data.OwnedLaunchers and data.OwnedLaunchers[instanceId]
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local pawn = playerService and playerService:GetPawn(player)
	local visualStatus = "PawnUnavailable"
	if owned and playerService and pawn then
		local visualUpdated = playerService:EquipLauncherModel(player, owned.definitionId)
		visualStatus = if visualUpdated then "Updated" else "Failed"
		if not visualUpdated then
			warn(string.format("[LAUNCHER_INVENTORY] Equipped state changed to %s, but live visual refresh failed for %s.", tostring(owned.definitionId), player.Name))
		end
	elseif state.ActivePlayerMode == GameStates.PlayerMode.Human then
		visualStatus = "HumanMode"
		print(string.format("[LAUNCHER_INVENTORY] Launcher %s equipped for %s while in Human mode; visual will apply when a Launcher pawn is spawned.", tostring(owned and owned.definitionId), player.Name))
	else
		warn(string.format("[LAUNCHER_INVENTORY] Equip state updated but Launcher pawn is unavailable for %s.", player.Name))
	end

	if stateService and typeof(stateService.PublishState) == "function" then
		stateService:PublishState(player)
		print(string.format(
			"[LAUNCHER_INVENTORY] stage=state_published player=%s instanceId=%s launcherId=%s",
			player.Name,
			instanceId,
			tostring(owned and owned.definitionId)
		))
	else
		warn(string.format("[LAUNCHER_INVENTORY] stage=state_publish_skipped player=%s reason=PublishStateUnavailable", player.Name))
	end

	self:_feedback(player, true, nil, nil, nil, {
		LauncherId = owned and owned.definitionId or instanceId,
		VisualStatus = visualStatus,
	})
	print(string.format("[LAUNCHER_INVENTORY] Equip completed: player=%s instanceId=%s launcherId=%s visualStatus=%s", player.Name, instanceId, tostring(owned and owned.definitionId), visualStatus))
	return true, nil
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
	print(string.format("[LAUNCHER_INVENTORY] Sell request received: player=%s instanceId=%s", player.Name, tostring(instanceId)))
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
		print(string.format("[LAUNCHER_INVENTORY] Sell completed: player=%s instanceId=%s salePrice=%d", player.Name, instanceId, salePrice or 0))
	else
		warn(string.format("[LAUNCHER_INVENTORY] Sell rejected: player=%s instanceId=%s reason=%s", player.Name, instanceId, tostring(reason or "Unknown")))
	end
	self:_feedback(player, ok, reason, "LauncherSellResult", salePrice or 0)
	return ok, reason
end

function LauncherInventoryService:Init()
	if self._equipRemote and self._equipRemote:IsA("RemoteEvent") then
		self._equipRemote.OnServerEvent:Connect(function(player: Player, instanceId: any)
			print(string.format("[LAUNCHER_INVENTORY] stage=equip_remote_received player=%s instanceId=%s payloadType=%s", player.Name, tostring(instanceId), typeof(instanceId)))
			if not RemoteContracts.Validate(RemoteContracts.Names.EquipLauncher, instanceId) then
				warn(string.format("[LAUNCHER_INVENTORY] Invalid equip payload: player=%s instanceIdType=%s", player.Name, typeof(instanceId)))
				self:_feedback(player, false, "InvalidRequest")
				return
			end
			self:Equip(player, instanceId)
		end)
	else
		warn("[LAUNCHER_INVENTORY] Missing ReplicatedStorage.LauncherArenaRemotes.EquipLauncher (RemoteEvent); create it through Rojo.")
	end

	if self._unequipRemote then
		self._unequipRemote.OnServerEvent:Connect(function(player)
			if not RemoteContracts.Validate(RemoteContracts.Names.UnequipLauncher) then
				self:_feedback(player, false, "InvalidRequest")
				return
			end
			self:Unequip(player)
		end)
	else
		warn("[LAUNCHER_INVENTORY] Missing ReplicatedStorage.LauncherArenaRemotes.UnequipLauncher (RemoteEvent); create it through Rojo.")
	end

	if self._sellRemote and self._sellRemote:IsA("RemoteEvent") then
		self._sellRemote.OnServerEvent:Connect(function(player: Player, instanceId: any)
			print(string.format("[LAUNCHER_INVENTORY] stage=sell_remote_received player=%s instanceId=%s payloadType=%s", player.Name, tostring(instanceId), typeof(instanceId)))
			if not RemoteContracts.Validate(RemoteContracts.Names.SellLauncher, instanceId) then
				warn(string.format("[LAUNCHER_INVENTORY] Invalid sell payload: player=%s instanceIdType=%s", player.Name, typeof(instanceId)))
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
