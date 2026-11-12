--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local OnlineRewardConfig = require(ReplicatedStorage.Shared.Config.OnlineRewardConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type Context = {
	Remotes: Folder?,
	Services: { [string]: any }?,
	ServiceRegistry: any?,
}

local OnlineRewardService = {}
OnlineRewardService.__index = OnlineRewardService

local REQUEST_COOLDOWN_SECONDS = 0.15
local DEBUG_COOLDOWN_SECONDS = 0.5

local function copyTable(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copyTable(child)
	end
	return result
end

local function makeDefaultState(rewardSetId: string)
	return {
		SchemaVersion = 1,
		CycleId = 1,
		RewardSetId = rewardSetId,
		ElapsedSeconds = 0,
		ClaimedSlots = {},
		LastSessionEndAt = 0,
		LastOnlineAt = os.time(),
	}
end

function OnlineRewardService.new(context: Context)
	local self = setmetatable({}, OnlineRewardService)
	self._context = context
	self._runtimeByUserId = {} :: { [number]: { LastTickAt: number, LastSaveAt: number, LastSnapshotAt: number } }
	self._claimLocks = {} :: { [number]: boolean }
	self._lastRequestAt = {} :: { [number]: number }
	self._lastDebugAt = {} :: { [number]: number }
	self._random = Random.new()
	self._running = false
	self._connections = {}
	return self
end

function OnlineRewardService:_dataService()
	return ServiceResolver.Get(self._context, "PlayerDataService")
end

function OnlineRewardService:_chooseRewardSet(previousId: string?): string
	local ids = OnlineRewardConfig.GetRewardSetIds()
	if #ids == 0 then
		return "SetA"
	end
	local eligible = {}
	for _, id in ipairs(ids) do
		if #ids == 1 or id ~= previousId then
			table.insert(eligible, id)
		end
	end
	if #eligible == 0 then
		eligible = ids
	end
	return eligible[self._random:NextInteger(1, #eligible)]
end

function OnlineRewardService:_validateConfig(): boolean
	if #OnlineRewardConfig.Slots ~= 15 then
		warn("[OnlineRewardService] Config must contain exactly 15 slots.")
		return false
	end

	local rarityCounts = { Common = 0, Normal = 0, Rare = 0 }
	local previousDuration = 0
	local seenIds = {}
	for _, slot in ipairs(OnlineRewardConfig.Slots) do
		if type(slot.Id) ~= "string" or slot.Id == "" or seenIds[slot.Id] then
			warn("[OnlineRewardService] Config contains a missing or duplicate reward slot id.")
			return false
		end
		seenIds[slot.Id] = true
		local duration = math.floor(tonumber(slot.TimeSeconds) or 0)
		if duration <= previousDuration or duration > OnlineRewardConfig.CycleDurationSeconds then
			warn(string.format("[OnlineRewardService] Invalid duration for slot '%s'.", slot.Id))
			return false
		end
		previousDuration = duration
		if rarityCounts[slot.Rarity] == nil then
			warn(string.format("[OnlineRewardService] Invalid rarity for slot '%s'.", slot.Id))
			return false
		end
		rarityCounts[slot.Rarity] += 1
	end

	if rarityCounts.Common ~= 5 or rarityCounts.Normal ~= 5 or rarityCounts.Rare ~= 5 then
		warn("[OnlineRewardService] Config must contain five Common, five Normal, and five Rare slots.")
		return false
	end

	for _, setId in ipairs(OnlineRewardConfig.GetRewardSetIds()) do
		local rewards = OnlineRewardConfig.GetRewardSet(setId)
		if type(rewards) ~= "table" or #rewards ~= #OnlineRewardConfig.Slots then
			warn(string.format("[OnlineRewardService] Reward set '%s' must contain 15 rewards.", setId))
			return false
		end
		for index, reward in ipairs(rewards) do
			if reward.Kind == "Diamonds" then
				if (tonumber(reward.Amount) or 0) <= 0 then
					warn(string.format("[OnlineRewardService] Invalid Diamonds reward in %s slot %d.", setId, index))
					return false
				end
			elseif reward.Kind == "Item" then
				if type(reward.ItemId) ~= "string" or not ItemConfig.GetById(reward.ItemId)
					or (tonumber(reward.Quantity) or 0) <= 0 then
					warn(string.format("[OnlineRewardService] Invalid item reward in %s slot %d.", setId, index))
					return false
				end
			else
				warn(string.format("[OnlineRewardService] Unsupported reward kind in %s slot %d; EXP and other direct stat rewards are not allowed.", setId, index))
				return false
			end
		end
	end
	return true
end

function OnlineRewardService:_getProfileState(player: Player): (any?, any?)
	local dataService = self:_dataService()
	if not dataService then
		return nil, nil
	end

	local profile = dataService:GetData(player)
	if type(profile) ~= "table" then
		profile = dataService:LoadPlayer(player)
	end
	if type(profile) ~= "table" then
		return nil, nil
	end

	local state = profile.OnlineRewardState
	if type(state) ~= "table" then
		state = makeDefaultState(self:_chooseRewardSet(nil))
		profile.OnlineRewardState = state
	end

	state.SchemaVersion = 1
	state.CycleId = math.max(1, math.floor(tonumber(state.CycleId) or 1))
	state.ElapsedSeconds = math.clamp(tonumber(state.ElapsedSeconds) or 0, 0, OnlineRewardConfig.CycleDurationSeconds)
	state.ClaimedSlots = if type(state.ClaimedSlots) == "table" then state.ClaimedSlots else {}
	state.LastSessionEndAt = math.max(0, math.floor(tonumber(state.LastSessionEndAt) or 0))
	state.LastOnlineAt = math.max(0, math.floor(tonumber(state.LastOnlineAt) or state.LastSessionEndAt or os.time()))
	if not OnlineRewardConfig.RewardSets[state.RewardSetId] then
		state.RewardSetId = self:_chooseRewardSet(nil)
	end
	return profile, state
end

function OnlineRewardService:_allSlotsClaimed(state: any): boolean
	for _, slot in ipairs(OnlineRewardConfig.Slots) do
		if state.ClaimedSlots[slot.Id] ~= true then
			return false
		end
	end
	return true
end

function OnlineRewardService:_beginNextCycle(state: any)
	local previousSetId = tostring(state.RewardSetId or "")
	state.CycleId = math.max(1, math.floor(tonumber(state.CycleId) or 1)) + 1
	state.RewardSetId = self:_chooseRewardSet(previousSetId)
	state.ElapsedSeconds = 0
	state.ClaimedSlots = {}
	state.LastSessionEndAt = 0
end

function OnlineRewardService:_savePlayer(player: Player)
	local dataService = self:_dataService()
	if dataService and typeof(dataService.SavePlayer) == "function" then
		local ok, saved = pcall(function()
			return dataService:SavePlayer(player)
		end)
		if not ok or saved == false then
			warn(string.format("[OnlineRewardService] Profile save failed for user %d: %s", player.UserId, tostring(saved)))
		end
	end
end

function OnlineRewardService:_ensurePlayerSession(player: Player)
	local userId = player.UserId
	if self._runtimeByUserId[userId] then
		return
	end

	local _, state = self:_getProfileState(player)
	if not state then
		warn(string.format("[OnlineRewardService] Could not load OnlineRewardState for user %d.", userId))
		return
	end

	local now = os.time()
	local lastSeenAt = math.max(tonumber(state.LastSessionEndAt) or 0, tonumber(state.LastOnlineAt) or 0)
	local offlineSeconds = if lastSeenAt > 0 then math.max(0, now - lastSeenAt) else 0
	local resetForOffline = lastSeenAt > 0 and offlineSeconds > OnlineRewardConfig.OfflineResetSeconds
	local recoveredCompletedCycle = self:_allSlotsClaimed(state)

	if resetForOffline or recoveredCompletedCycle then
		self:_beginNextCycle(state)
		self:_savePlayer(player)
	end

	state.LastSessionEndAt = 0
	state.LastOnlineAt = now
	self._runtimeByUserId[userId] = {
		LastTickAt = os.clock(),
		LastSaveAt = os.clock(),
		LastSnapshotAt = 0,
	}
	-- Clear the previous logout marker durably before the player can leave again.
	self:_savePlayer(player)
end

function OnlineRewardService:_advancePlayer(player: Player, nowClock: number)
	self:_ensurePlayerSession(player)
	local runtime = self._runtimeByUserId[player.UserId]
	if not runtime then
		return
	end

	local _, state = self:_getProfileState(player)
	if not state then
		return
	end

	local delta = math.max(0, nowClock - runtime.LastTickAt)
	runtime.LastTickAt = nowClock
	state.ElapsedSeconds = math.min(
		OnlineRewardConfig.CycleDurationSeconds,
		math.max(0, tonumber(state.ElapsedSeconds) or 0) + delta
	)

	if nowClock - runtime.LastSaveAt >= OnlineRewardConfig.SaveIntervalSeconds then
		runtime.LastSaveAt = nowClock
		state.LastOnlineAt = os.time()
		self:_savePlayer(player)
	end
end

function OnlineRewardService:_buildSnapshot(player: Player): any?
	local _, state = self:_getProfileState(player)
	if not state then
		return nil
	end

	local rewardSet = OnlineRewardConfig.GetRewardSet(tostring(state.RewardSetId))
	if not rewardSet then
		return nil
	end

	local slots = {}
	local readyCount = 0
	for index, slotDefinition in ipairs(OnlineRewardConfig.Slots) do
		local reward = rewardSet[index]
		local remaining = math.max(0, math.ceil(slotDefinition.TimeSeconds - state.ElapsedSeconds))
		local claimed = state.ClaimedSlots[slotDefinition.Id] == true
		local slotState = if claimed then "Claimed" elseif remaining <= 0 then "Ready" else "Locked"
		if slotState == "Ready" then
			readyCount += 1
		end

		local rewardType = "Diamonds"
		local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
		local itemId = nil
		local icon = OnlineRewardConfig.DiamondsIcon
		if reward.Kind == "Item" then
			local item = ItemConfig.GetById(tostring(reward.ItemId))
			itemId = tostring(reward.ItemId)
			rewardType = if item then item.name else itemId
			amount = math.max(1, math.floor(tonumber(reward.Quantity) or 1))
			icon = if item then item.icon else ""
		end

		table.insert(slots, {
			id = slotDefinition.Id,
			rewardType = rewardType,
			amount = amount,
			icon = tostring(icon or ""),
			itemId = itemId,
			rarity = slotDefinition.Rarity,
			duration = slotDefinition.TimeSeconds,
			remaining = if slotState == "Locked" then remaining else 0,
			state = slotState,
		})
	end

	return {
		CycleId = state.CycleId,
		RewardSetId = state.RewardSetId,
		ElapsedSeconds = math.floor(state.ElapsedSeconds),
		CycleDurationSeconds = OnlineRewardConfig.CycleDurationSeconds,
		ReadyCount = readyCount,
		slots = slots,
		columns = OnlineRewardConfig.Columns,
		rows = OnlineRewardConfig.Rows,
		ServerNow = os.time(),
	}
end

function OnlineRewardService:_sendSnapshot(player: Player, result: any?)
	if not self._updateRemote then
		return
	end
	local snapshot = self:_buildSnapshot(player)
	if not snapshot then
		return
	end
	self._updateRemote:FireClient(player, {
		Type = "Snapshot",
		Snapshot = snapshot,
		Result = result and copyTable(result) or nil,
	})
end

function OnlineRewardService:_sendResetToast(player: Player)
	local notificationRemote = self._context.Remotes
		and self._context.Remotes:FindFirstChild(RemoteContracts.Names.Notification)
	if notificationRemote and notificationRemote:IsA("RemoteEvent") then
		notificationRemote:FireClient(player, {
			Type = "Generic",
			Priority = 80,
			Text = "Online Reward đã được cập nhật mới.",
		})
	end
end

function OnlineRewardService:_allowClaimRequest(player: Player): boolean
	local userId = player.UserId
	local now = os.clock()
	local previous = self._lastRequestAt[userId] or 0
	if now - previous < REQUEST_COOLDOWN_SECONDS then
		return false
	end
	self._lastRequestAt[userId] = now
	return true
end

function OnlineRewardService:_claimReward(player: Player, payload: any)
	local userId = player.UserId
	local result = {
		Action = "Claim",
		RewardId = tostring(payload.RewardId or ""),
		Success = false,
		Reason = "Rejected",
	}

	if not self:_allowClaimRequest(player) or self._claimLocks[userId] then
		result.Reason = "RequestPending"
		self:_sendSnapshot(player, result)
		return
	end
	self._claimLocks[userId] = true

	local function finish()
		self._claimLocks[userId] = nil
		self:_sendSnapshot(player, result)
	end

	self:_advancePlayer(player, os.clock())
	local _, state = self:_getProfileState(player)
	if not state then
		result.Reason = "ProfileUnavailable"
		finish()
		return
	end

	local requestedCycleId = math.floor(tonumber(payload.CycleId) or 0)
	if requestedCycleId ~= state.CycleId then
		result.Reason = "StaleCycle"
		finish()
		return
	end

	local slotIndex = nil
	local slotDefinition = nil
	for index, slot in ipairs(OnlineRewardConfig.Slots) do
		if slot.Id == payload.RewardId then
			slotIndex = index
			slotDefinition = slot
			break
		end
	end
	if not slotDefinition or not slotIndex then
		result.Reason = "InvalidReward"
		finish()
		return
	end
	if state.ClaimedSlots[slotDefinition.Id] == true then
		result.Reason = "AlreadyClaimed"
		finish()
		return
	end
	if state.ElapsedSeconds < slotDefinition.TimeSeconds then
		result.Reason = "NotReady"
		finish()
		return
	end

	local rewardSet = OnlineRewardConfig.GetRewardSet(tostring(state.RewardSetId))
	local reward = rewardSet and rewardSet[slotIndex]
	if not reward then
		result.Reason = "RewardUnavailable"
		finish()
		return
	end

	local grantPayload
	if reward.Kind == "Diamonds" then
		grantPayload = { Diamonds = math.max(0, math.floor(tonumber(reward.Amount) or 0)) }
	elseif reward.Kind == "Item" and ItemConfig.GetById(tostring(reward.ItemId)) then
		grantPayload = {
			Items = {
				{
					Id = tostring(reward.ItemId),
					Quantity = math.max(1, math.floor(tonumber(reward.Quantity) or 1)),
				},
			},
		}
	else
		result.Reason = "InvalidRewardConfig"
		finish()
		return
	end

	local dataService = self:_dataService()
	if not dataService or typeof(dataService.CommitOnlineRewardClaim) ~= "function" then
		result.Reason = "RewardServiceUnavailable"
		finish()
		return
	end

	local committed, reason = dataService:CommitOnlineRewardClaim(
		player,
		state.CycleId,
		slotDefinition.Id,
		grantPayload
	)
	if not committed then
		result.Reason = tostring(reason or "CommitFailed")
		finish()
		return
	end

	result.Success = true
	result.Reason = "Claimed"
	result.Reward = copyTable(grantPayload)

	local _, updatedState = self:_getProfileState(player)
	if updatedState and self:_allSlotsClaimed(updatedState) then
		self:_beginNextCycle(updatedState)
		result.CycleCompleted = true
		result.NextCycleId = updatedState.CycleId
		self:_savePlayer(player)
		self:_sendResetToast(player)
	else
		self:_savePlayer(player)
	end

	finish()
end

function OnlineRewardService:_handleAction(player: Player, payload: any)
	if not RemoteContracts.Validate(RemoteContracts.Names.OnlineRewardRequest, payload) then
		self:_sendSnapshot(player, {
			Action = "Request",
			Success = false,
			Reason = "InvalidRequest",
		})
		return
	end

	if payload.Action == "Snapshot" then
		self:_advancePlayer(player, os.clock())
		self:_sendSnapshot(player)
	elseif payload.Action == "Claim" then
		self:_claimReward(player, payload)
	end
end

function OnlineRewardService:_debugCompleteCountdown(player: Player)
	if not RunService:IsStudio() then
		return
	end
	local now = os.clock()
	local last = self._lastDebugAt[player.UserId] or 0
	if now - last < DEBUG_COOLDOWN_SECONDS then
		return
	end
	self._lastDebugAt[player.UserId] = now

	self:_ensurePlayerSession(player)
	local _, state = self:_getProfileState(player)
	if not state then
		return
	end
	state.ElapsedSeconds = OnlineRewardConfig.CycleDurationSeconds
	self:_savePlayer(player)
	self:_sendSnapshot(player, {
		Action = "DebugReset",
		Success = true,
		Reason = "CountdownCompleted",
	})
end

function OnlineRewardService:_endPlayerSession(player: Player)
	local userId = player.UserId
	local runtime = self._runtimeByUserId[userId]
	if not runtime then
		return
	end

	self:_advancePlayer(player, os.clock())
	local _, state = self:_getProfileState(player)
	if state then
		state.LastSessionEndAt = os.time()
		state.LastOnlineAt = state.LastSessionEndAt
	end
	self._runtimeByUserId[userId] = nil
	self._claimLocks[userId] = nil
	self._lastRequestAt[userId] = nil
	self._lastDebugAt[userId] = nil
	self:_savePlayer(player)
end

function OnlineRewardService:Init()
	if not self:_validateConfig() then
		error("[OnlineRewardService] Invalid OnlineRewardConfig; bootstrap cannot continue.", 0)
	end

	local remotes = self._context.Remotes
	self._requestRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.OnlineRewardRequest)
	self._updateRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.OnlineRewardUpdate)
	self._debugResetRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.ResetTimeOnlineReward)

	if self._requestRemote and self._requestRemote:IsA("RemoteEvent") then
		table.insert(self._connections, self._requestRemote.OnServerEvent:Connect(function(player: Player, payload: any)
			self:_handleAction(player, payload)
		end))
	else
		warn("[OnlineRewardService] Missing LauncherArenaRemotes.OnlineRewardRequest.")
	end

	if self._debugResetRemote and self._debugResetRemote:IsA("RemoteEvent") then
		table.insert(self._connections, self._debugResetRemote.OnServerEvent:Connect(function(player: Player)
			if RunService:IsStudio() and RemoteContracts.Validate(RemoteContracts.Names.ResetTimeOnlineReward) then
				self:_debugCompleteCountdown(player)
			end
		end))
	else
		warn("[OnlineRewardService] Missing LauncherArenaRemotes.ResetTimeOnlineReward.")
	end

	Players.PlayerAdded:Connect(function(player: Player)
		task.defer(function()
			if player.Parent == Players then
				self:_ensurePlayerSession(player)
				self:_sendSnapshot(player)
			end
		end)
	end)
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player: Player)
		self:_endPlayerSession(player)
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		self:_ensurePlayerSession(player)
	end

	self._running = true
	task.spawn(function()
		while self._running do
			task.wait(OnlineRewardConfig.SnapshotIntervalSeconds)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				self:_advancePlayer(player, now)
				self:_sendSnapshot(player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:_endPlayerSession(player)
		end
	end)
end

function OnlineRewardService:Destroy()
	self._running = false
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return OnlineRewardService
