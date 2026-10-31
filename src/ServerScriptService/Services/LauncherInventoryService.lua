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
	self._combineRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.CombineLaunchers) :: RemoteEvent?
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
		local visualCallOk, visualUpdatedOrError = pcall(function()
			return playerService:EquipLauncherModel(player, owned.definitionId)
		end)
		if not visualCallOk then
			visualStatus = "Failed"
			warn(string.format(
				"[LAUNCHER_INVENTORY] stage=visual_refresh_exception player=%s instanceId=%s launcherId=%s error=%s",
				player.Name,
				instanceId,
				tostring(owned.definitionId),
				tostring(visualUpdatedOrError)
			))
		else
			visualStatus = if visualUpdatedOrError == true then "Updated" else "Failed"
			if not visualUpdatedOrError then
				warn(string.format("[LAUNCHER_INVENTORY] Equipped state changed to %s, but live visual refresh returned false for %s.", tostring(owned.definitionId), player.Name))
			end
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


function LauncherInventoryService:Combine(player: Player, instanceIds: { string }, requestId: number?)
	print(string.format("[LAUNCHER_INVENTORY] Combine request received: player=%s count=%d requestId=%s", player.Name, #instanceIds, tostring(requestId)))
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state or state.LocationState ~= GameStates.SessionState.Lobby then
		self:_feedback(player, false, "LobbyOnly", "LauncherCombineResult", nil, { RequestId = requestId })
		return false, "LobbyOnly"
	end

	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService or typeof(dataService.CombineLaunchers) ~= "function" then
		self:_feedback(player, false, "MissingPlayerDataService", "LauncherCombineResult", nil, { RequestId = requestId })
		return false, "MissingPlayerDataService"
	end

	local ok, reason, resultLauncher = dataService:CombineLaunchers(player, instanceIds)
	if ok then
		stateService:_syncInventoryFromData(player)
		stateService:PublishState(player)
		print(string.format(
			"[LAUNCHER_INVENTORY] Combine completed: player=%s resultInstanceId=%s launcherId=%s rarity=%s star=%s level=%s",
			player.Name,
			tostring(resultLauncher and resultLauncher.instanceId),
			tostring(resultLauncher and resultLauncher.definitionId),
			tostring(resultLauncher and resultLauncher.rarity),
			tostring(resultLauncher and resultLauncher.star),
			tostring(resultLauncher and resultLauncher.level)
		))
	else
		warn(string.format("[LAUNCHER_INVENTORY] Combine rejected: player=%s reason=%s", player.Name, tostring(reason or "Unknown")))
	end

	self:_feedback(player, ok, reason, "LauncherCombineResult", nil, {
		ResultLauncher = resultLauncher,
		RequestId = requestId,
	})
	return ok, reason
end

function LauncherInventoryService:Init()
	print(string.format(
		"[LAUNCHER_INVENTORY] stage=init equipRemoteBound=%s unequipRemoteBound=%s sellRemoteBound=%s combineRemoteBound=%s remotesFolder=%s",
		tostring(self._equipRemote ~= nil and self._equipRemote:IsA("RemoteEvent")),
		tostring(self._unequipRemote ~= nil and self._unequipRemote:IsA("RemoteEvent")),
		tostring(self._sellRemote ~= nil and self._sellRemote:IsA("RemoteEvent")),
		tostring(self._combineRemote ~= nil and self._combineRemote:IsA("RemoteEvent")),
		self._context.Remotes:GetFullName()
	))
	if self._equipRemote and self._equipRemote:IsA("RemoteEvent") then
		self._equipRemote.OnServerEvent:Connect(function(player: Player, instanceId: any)
			print(string.format("[LAUNCHER_INVENTORY] stage=equip_remote_received player=%s instanceId=%s payloadType=%s", player.Name, tostring(instanceId), typeof(instanceId)))
			if not RemoteContracts.Validate(RemoteContracts.Names.EquipLauncher, instanceId) then
				warn(string.format("[LAUNCHER_INVENTORY] Invalid equip payload: player=%s instanceIdType=%s", player.Name, typeof(instanceId)))
				self:_feedback(player, false, "InvalidRequest")
				return
			end
			local callOk, callError = pcall(function()
				self:Equip(player, instanceId)
			end)
			if not callOk then
				warn(string.format("[LAUNCHER_INVENTORY] stage=equip_handler_exception player=%s instanceId=%s error=%s", player.Name, tostring(instanceId), tostring(callError)))
				self:_feedback(player, false, "InternalError")
			end
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
			local callOk, callError = pcall(function()
				self:Sell(player, instanceId)
			end)
			if not callOk then
				warn(string.format("[LAUNCHER_INVENTORY] stage=sell_handler_exception player=%s instanceId=%s error=%s", player.Name, tostring(instanceId), tostring(callError)))
				self:_feedback(player, false, "InternalError", "LauncherSellResult", 0)
			end
		end)
	else
		warn("[LAUNCHER_INVENTORY] Missing ReplicatedStorage.LauncherArenaRemotes.SellLauncher (RemoteEvent); create it through Rojo.")
	end
	if self._combineRemote and self._combineRemote:IsA("RemoteEvent") then
		self._combineRemote.OnServerEvent:Connect(function(player: Player, payload: any)
			if not RemoteContracts.Validate(RemoteContracts.Names.CombineLaunchers, payload) then
				warn(string.format("[LAUNCHER_INVENTORY] Invalid combine payload: player=%s", player.Name))
				self:_feedback(player, false, "InvalidRequest", "LauncherCombineResult")
				return
			end
			local callOk, callError = pcall(function()
				self:Combine(player, payload.instanceIds, payload.requestId)
			end)
			if not callOk then
				warn(string.format("[LAUNCHER_INVENTORY] Combine handler exception: player=%s error=%s", player.Name, tostring(callError)))
				self:_feedback(player, false, "InternalError", "LauncherCombineResult", nil, { RequestId = payload.requestId })
			end
		end)
	else
		warn("[LAUNCHER_INVENTORY] Missing ReplicatedStorage.LauncherArenaRemotes.CombineLaunchers (RemoteEvent); create it through Rojo.")
	end

end

return LauncherInventoryService
