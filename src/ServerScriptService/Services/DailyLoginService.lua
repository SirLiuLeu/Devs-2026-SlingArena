--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DailyLoginConfig = require(ReplicatedStorage.Shared.Config.DailyLoginConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type Context = {
	Remotes: Folder?,
	Services: { [string]: any }?,
	ServiceRegistry: any?,
	EventBus: any?,
}

local DailyLoginService = {}
DailyLoginService.__index = DailyLoginService

local REQUEST_COOLDOWN_SECONDS = 0.2
local DEBUG_COOLDOWN_SECONDS = 0.35
local SECONDS_PER_DAY = 24 * 60 * 60

local function copyArray(values: any): { any }
	local result = {}
	if type(values) == "table" then
		for index, value in ipairs(values) do
			result[index] = value
		end
	end
	return result
end

local function getDayKey(timestamp: number): number
	local offsetSeconds = (tonumber(DailyLoginConfig.ResetUtcOffsetHours) or 0) * 60 * 60
	local date = os.date("!*t", math.floor(timestamp + offsetSeconds))
	return date.year * 10000 + date.month * 100 + date.day
end

local function getNextResetAt(timestamp: number): number
	local offsetSeconds = (tonumber(DailyLoginConfig.ResetUtcOffsetHours) or 0) * 60 * 60
	local shifted = timestamp + offsetSeconds
	return (math.floor(shifted / SECONDS_PER_DAY) + 1) * SECONDS_PER_DAY - offsetSeconds
end

local function isPositiveInteger(value: any): boolean
	return typeof(value) == "number" and value % 1 == 0 and value > 0
end

function DailyLoginService.new(context: Context)
	local self = setmetatable({}, DailyLoginService)
	self._context = context
	self._requestRemote = nil :: RemoteEvent?
	self._updateRemote = nil :: RemoteEvent?
	self._connections = {}
	self._claimLocks = {} :: { [number]: boolean }
	self._lastRequestAt = {} :: { [number]: number }
	self._lastDebugAt = {} :: { [number]: number }
	self._debugTimeOffsets = {} :: { [number]: number }
	self._random = Random.new()
	return self
end

function DailyLoginService:_dataService()
	return ServiceResolver.Get(self._context, "PlayerDataService")
end

function DailyLoginService:_getNow(player: Player): number
	return os.time() + (self._debugTimeOffsets[player.UserId] or 0)
end

function DailyLoginService:_chooseWeighted(candidates: { any }): any?
	local totalWeight = 0
	for _, candidate in ipairs(candidates) do
		totalWeight += math.max(0, tonumber(candidate.Weight) or 0)
	end
	if totalWeight <= 0 then
		return nil
	end

	local roll = self._random:NextNumber(0, totalWeight)
	local cursor = 0
	for _, candidate in ipairs(candidates) do
		cursor += math.max(0, tonumber(candidate.Weight) or 0)
		if roll <= cursor then
			return candidate
		end
	end
	return candidates[#candidates]
end

function DailyLoginService:_chooseBundleIds(previousIds: any): { string }
	local excluded = {}
	for _, bundleId in ipairs(previousIds or {}) do
		if typeof(bundleId) == "string" then
			excluded[bundleId] = true
		end
	end

	local selected = {}
	for day = 1, 6 do
		local tier = DailyLoginConfig.GetTierForDay(day)
		local pool = DailyLoginConfig.GetPool(tier or "")
		local eligible = {}
		for _, bundle in ipairs(pool) do
			if not excluded[bundle.Id] then
				table.insert(eligible, bundle)
			end
		end
		if #eligible == 0 then
			for _, bundle in ipairs(pool) do
				if not table.find(selected, bundle.Id) then
					table.insert(eligible, bundle)
				end
			end
		end

		local choice = self:_chooseWeighted(eligible)
		if not choice then
			warn(string.format("[DailyLoginService] No valid bundle candidate for day %d (tier=%s).", day, tostring(tier)))
			return {}
		end
		table.insert(selected, choice.Id)
		excluded[choice.Id] = true
	end
	return selected
end

function DailyLoginService:_validateConfig(): boolean
	local seenIds = {}
	local expectedCounts = { Basic = 6, Medium = 7, Premium = 7 }
	local totalBundles = 0

	for tier, expectedCount in pairs(expectedCounts) do
		local pool = DailyLoginConfig.GetPool(tier)
		if #pool ~= expectedCount then
			warn(string.format("[DailyLoginService] Tier %s must contain exactly %d bundles.", tier, expectedCount))
			return false
		end
		for _, bundle in ipairs(pool) do
			if type(bundle.Id) ~= "string" or bundle.Id == "" or seenIds[bundle.Id] then
				warn("[DailyLoginService] Missing or duplicate bundle ID in DailyLoginConfig.")
				return false
			end
			seenIds[bundle.Id] = true
			totalBundles += 1

			if (tonumber(bundle.Weight) or 0) <= 0 then
				warn(string.format("[DailyLoginService] Bundle %s has an invalid Weight.", bundle.Id))
				return false
			end
			if bundle.Kind == "Diamonds" then
				if not isPositiveInteger(bundle.Amount) then
					warn(string.format("[DailyLoginService] Bundle %s has an invalid Diamonds amount.", bundle.Id))
					return false
				end
			elseif bundle.Kind == "Item" then
				if type(bundle.ItemId) ~= "string" or not ItemConfig.GetById(bundle.ItemId)
					or not isPositiveInteger(bundle.Quantity) or bundle.Quantity > 999 then
					warn(string.format("[DailyLoginService] Bundle %s references an invalid Item reward.", bundle.Id))
					return false
				end
			else
				warn(string.format("[DailyLoginService] Bundle %s must contain only Diamonds or one Item type.", bundle.Id))
				return false
			end
		end
	end

	if totalBundles ~= 20 or #DailyLoginConfig.DayTiers ~= 6 then
		warn("[DailyLoginService] Daily Login requires 20 bundles and exactly six non-Pet days.")
		return false
	end

	local weightTotal = 0
	local petRarities = {}
	for rarity, weight in pairs(DailyLoginConfig.PetDropWeights) do
		if (tonumber(weight) or 0) < 0 then
			warn(string.format("[DailyLoginService] Invalid Pet drop weight for %s.", rarity))
			return false
		end
		weightTotal += weight
	end
	for _, definitionId in ipairs(PetsConfig.GetAllIds()) do
		local definition = PetsConfig.GetById(definitionId)
		if definition and DailyLoginConfig.PetDropWeights[definition.rarity] then
			petRarities[definition.rarity] = true
		end
	end
	if math.abs(weightTotal - 100) > 0.001 then
		warn("[DailyLoginService] Pet drop weights must total 100.")
		return false
	end
	for rarity, weight in pairs(DailyLoginConfig.PetDropWeights) do
		if weight > 0 and not petRarities[rarity] then
			warn(string.format("[DailyLoginService] No Pet definitions found for weighted rarity %s.", rarity))
			return false
		end
	end
	return true
end

function DailyLoginService:_ensurePlayerState(player: Player): (any?, any?)
	local dataService = self:_dataService()
	if not dataService then
		return nil, nil
	end

	local profile = dataService:GetData(player)
	if type(profile) ~= "table" then
		return nil, nil
	end

	local state = profile.DailyLoginState
	if type(state) ~= "table" then
		state = {
			SchemaVersion = DailyLoginConfig.SchemaVersion,
			CycleId = 1,
			CurrentDay = 1,
			LastClaimDayKey = 0,
			SelectedBundleIds = {},
		}
		profile.DailyLoginState = state
	end

	state.SchemaVersion = DailyLoginConfig.SchemaVersion
	state.CycleId = math.max(1, math.floor(tonumber(state.CycleId) or 1))
	state.CurrentDay = math.clamp(math.floor(tonumber(state.CurrentDay) or 1), 1, 7)
	state.LastClaimDayKey = math.max(0, math.floor(tonumber(state.LastClaimDayKey) or 0))
	if type(state.SelectedBundleIds) ~= "table" then
		state.SelectedBundleIds = {}
	end

	local selectedValid = #state.SelectedBundleIds == 6
	if selectedValid then
		for day = 1, 6 do
			local bundle = DailyLoginConfig.GetBundle(tostring(state.SelectedBundleIds[day] or ""))
			if not bundle or bundle.Tier ~= DailyLoginConfig.GetTierForDay(day) then
				selectedValid = false
				break
			end
		end
	end

	if not selectedValid then
		local previousIds = copyArray(state.SelectedBundleIds)
		local selectedIds = self:_chooseBundleIds(previousIds)
		if #selectedIds ~= 6 then
			return profile, nil
		end
		state.SelectedBundleIds = selectedIds
		dataService:SavePlayer(player)
	end

	return profile, state
end

function DailyLoginService:_rollPet(): (string?, any?)
	local pools = {}
	for _, definitionId in ipairs(PetsConfig.GetAllIds()) do
		local definition = PetsConfig.GetById(definitionId)
		if definition and (tonumber(DailyLoginConfig.PetDropWeights[definition.rarity]) or 0) > 0 then
			pools[definition.rarity] = pools[definition.rarity] or {}
			table.insert(pools[definition.rarity], definitionId)
		end
	end

	local rarityChoices = {}
	for rarity, weight in pairs(DailyLoginConfig.PetDropWeights) do
		if weight > 0 and pools[rarity] and #pools[rarity] > 0 then
			table.insert(rarityChoices, { Id = rarity, Weight = weight })
		end
	end
	local selectedRarity = self:_chooseWeighted(rarityChoices)
	if not selectedRarity then
		return nil, nil
	end

	local candidates = pools[selectedRarity.Id]
	local definitionId = candidates[self._random:NextInteger(1, #candidates)]
	return definitionId, PetsConfig.GetById(definitionId)
end

function DailyLoginService:_buildRewardEntry(day: number, bundleId: string, state: string): any?
	local bundle = DailyLoginConfig.GetBundle(bundleId)
	if not bundle then
		return nil
	end

	if bundle.Kind == "Diamonds" then
		return {
			day = day,
			rewardType = "Diamonds",
			rewardText = string.format("+%d", bundle.Amount),
			amount = bundle.Amount,
			icon = "",
			iconKind = "Diamonds",
			state = state,
		}
	end

	local item = ItemConfig.GetById(bundle.ItemId)
	if not item then
		return nil
	end
	return {
		day = day,
		rewardType = item.name,
		rewardText = string.format("x%d", bundle.Quantity),
		amount = bundle.Quantity,
		itemId = bundle.ItemId,
		icon = item.icon or "",
		iconKind = "Item",
		state = state,
	}
end

function DailyLoginService:_buildSnapshot(player: Player): any?
	local _, state = self:_ensurePlayerState(player)
	if not state then
		return nil
	end

	local now = self:_getNow(player)
	local todayKey = getDayKey(now)
	local nextResetAt = getNextResetAt(now)
	local entries = {}

	for day = 1, 6 do
		local dayState = if day < state.CurrentDay then "Claimed"
			elseif day > state.CurrentDay then "Locked"
			elseif state.LastClaimDayKey >= todayKey then "Waiting"
			else "Claimable"
		local entry = self:_buildRewardEntry(day, tostring(state.SelectedBundleIds[day]), dayState)
		if entry then
			table.insert(entries, entry)
		end
	end

	local day7State = if state.CurrentDay > 7 then "Claimed"
		elseif state.CurrentDay < 7 then "Locked"
		elseif state.LastClaimDayKey >= todayKey then "Waiting"
		else "Claimable"
	table.insert(entries, {
		day = 7,
		rewardType = "Random Pet",
		rewardText = "1 Pet · Rare 65% / Epic 30% / Legendary 5%",
		icon = "",
		iconKind = "Pet",
		state = day7State,
	})

	return {
		CycleId = state.CycleId,
		CurrentDay = state.CurrentDay,
		LastClaimDayKey = state.LastClaimDayKey,
		TodayKey = todayKey,
		ServerNow = now,
		NextResetAt = nextResetAt,
		CanClaim = state.LastClaimDayKey < todayKey,
		entries = entries,
	}
end

function DailyLoginService:_sendSnapshot(player: Player, result: any?)
	if not self._updateRemote then
		return
	end
	local snapshot = self:_buildSnapshot(player)
	if not snapshot then
		warn(string.format("[DailyLoginService] Could not build Daily Login snapshot for user %d.", player.UserId))
		return
	end
	self._updateRemote:FireClient(player, {
		Snapshot = snapshot,
		Result = result,
	})
end

function DailyLoginService:_allowRequest(player: Player): boolean
	local now = os.clock()
	local previous = self._lastRequestAt[player.UserId] or 0
	if now - previous < REQUEST_COOLDOWN_SECONDS then
		return false
	end
	self._lastRequestAt[player.UserId] = now
	return true
end

function DailyLoginService:_sendClaimNotification(player: Player, result: any)
	local notificationRemote = self._context.Remotes
		and self._context.Remotes:FindFirstChild(RemoteContracts.Names.Notification)
	if not notificationRemote or not notificationRemote:IsA("RemoteEvent") then
		return
	end

	local message = "Đã nhận phần thưởng Daily Login."
	if result.Reward and result.Reward.Kind == "Pet" then
		message = string.format(
			"Chúc mừng nhận được Pet %s (%s)!",
			tostring(result.Reward.Name or result.Reward.DefinitionId or "Pet"),
			tostring(result.Reward.Rarity or "Pet")
		)
	end
	notificationRemote:FireClient(player, {
		Type = "Generic",
		Priority = 85,
		Text = message,
	})
end

function DailyLoginService:_claimReward(player: Player, payload: any)
	local userId = player.UserId
	local result: { [string]: any } = {
		Action = "Claim",
		Day = math.floor(tonumber(payload.Day) or 0),
		Success = false,
		Reason = "Rejected",
	}

	if not self:_allowRequest(player) or self._claimLocks[userId] then
		result.Reason = "RequestPending"
		self:_sendSnapshot(player, result)
		return
	end
	self._claimLocks[userId] = true

	local function finish()
		self._claimLocks[userId] = nil
		self:_sendSnapshot(player, result)
	end

	local _, state = self:_ensurePlayerState(player)
	if not state then
		result.Reason = "ProfileUnavailable"
		finish()
		return
	end

	local expectedCycleId = math.floor(tonumber(payload.CycleId) or 0)
	local requestedDay = math.floor(tonumber(payload.Day) or 0)
	if expectedCycleId ~= state.CycleId then
		result.Reason = "StaleCycle"
		finish()
		return
	end
	if requestedDay ~= state.CurrentDay or requestedDay < 1 or requestedDay > 7 then
		result.Reason = "NotCurrentDay"
		finish()
		return
	end

	local todayKey = getDayKey(self:_getNow(player))
	if state.LastClaimDayKey >= todayKey then
		result.Reason = "AlreadyClaimedToday"
		finish()
		return
	end

	local dataService = self:_dataService()
	if not dataService or typeof(dataService.CommitDailyLoginClaim) ~= "function" then
		result.Reason = "RewardServiceUnavailable"
		finish()
		return
	end

	local reward: any = nil
	local nextBundleIds: { string }? = nil
	if requestedDay == 7 then
		local definitionId, definition = self:_rollPet()
		if not definitionId or not definition then
			result.Reason = "PetRewardUnavailable"
			finish()
			return
		end
		reward = {
			Kind = "Pet",
			DefinitionId = definitionId,
		}
		nextBundleIds = self:_chooseBundleIds(state.SelectedBundleIds)
		if #nextBundleIds ~= 6 then
			result.Reason = "NextCycleUnavailable"
			finish()
			return
		end
	else
		local bundleId = tostring(state.SelectedBundleIds[requestedDay] or "")
		local bundle = DailyLoginConfig.GetBundle(bundleId)
		if not bundle then
			result.Reason = "RewardUnavailable"
			finish()
			return
		end
		reward = table.clone(bundle)
	end

	local committed, reason = dataService:CommitDailyLoginClaim(
		player,
		state.CycleId,
		requestedDay,
		todayKey,
		reward,
		nextBundleIds
	)
	if not committed then
		result.Reason = tostring(reason or "CommitFailed")
		finish()
		return
	end

	local rewardResult: { [string]: any } = {
		Kind = reward.Kind,
		Amount = reward.Amount,
		ItemId = reward.ItemId,
		Quantity = reward.Quantity,
		DefinitionId = reward.DefinitionId,
	}
	if reward.Kind == "Pet" then
		local definition = PetsConfig.GetById(reward.DefinitionId)
		rewardResult.Name = definition and definition.DisplayName or reward.DefinitionId
		rewardResult.Rarity = definition and definition.rarity or "Unknown"
	end

	result.Success = true
	result.Reason = "Claimed"
	result.Reward = rewardResult
	self:_sendClaimNotification(player, result)
	finish()
end

function DailyLoginService:_handleRequest(player: Player, payload: any)
	if not RemoteContracts.Validate(RemoteContracts.Names.DailyLoginRequest, payload) then
		self:_sendSnapshot(player, {
			Action = "Request",
			Success = false,
			Reason = "InvalidRequest",
		})
		return
	end

	if payload.Action == "Snapshot" then
		if self:_allowRequest(player) then
			self:_sendSnapshot(player)
		end
	elseif payload.Action == "Claim" then
		self:_claimReward(player, payload)
	elseif payload.Action == "DebugAdvance24h" then
		if not RunService:IsStudio() then
			self:_sendSnapshot(player, {
				Action = "DebugAdvance24h",
				Success = false,
				Reason = "StudioOnly",
			})
			return
		end
		local now = os.clock()
		local last = self._lastDebugAt[player.UserId] or 0
		if now - last < DEBUG_COOLDOWN_SECONDS then
			return
		end
		self._lastDebugAt[player.UserId] = now
		self._debugTimeOffsets[player.UserId] = (self._debugTimeOffsets[player.UserId] or 0) + SECONDS_PER_DAY
		self:_sendSnapshot(player, {
			Action = "DebugAdvance24h",
			Success = true,
			Reason = "TimeAdvanced",
			AddedSeconds = SECONDS_PER_DAY,
		})
		print(string.format(
			"[DailyLoginService][StudioDebug] Advanced Daily Login virtual time by 24h for user %d.",
			player.UserId
		))
	end
end

function DailyLoginService:_onPlayerAdded(player: Player)
	task.defer(function()
		if player.Parent ~= Players then
			return
		end
		local _, state = self:_ensurePlayerState(player)
		if state then
			self:_sendSnapshot(player)
		end
	end)
end

function DailyLoginService:_onPlayerRemoving(player: Player)
	local userId = player.UserId
	local debugOffset = self._debugTimeOffsets[userId] or 0
	if debugOffset > 0 then
		-- Studio time travel is session-local. Preserve the claimed day/cycle/rewards,
		-- but clamp a future test day key back to today's real date before saving.
		local realDayKey = getDayKey(os.time())
		local dataService = self:_dataService()
		if dataService then
			dataService:UpdateData(player, function(profile)
				local state = profile.DailyLoginState
				if type(state) == "table" and (tonumber(state.LastClaimDayKey) or 0) > realDayKey then
					state.LastClaimDayKey = realDayKey
				end
				return profile
			end)
			dataService:SavePlayer(player)
		end
	end

	self._claimLocks[userId] = nil
	self._lastRequestAt[userId] = nil
	self._lastDebugAt[userId] = nil
	self._debugTimeOffsets[userId] = nil
end

function DailyLoginService:Init()
	if not self:_validateConfig() then
		error("[DailyLoginService] Invalid DailyLoginConfig; bootstrap cannot continue.", 0)
	end

	local remotes = self._context.Remotes
	self._requestRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.DailyLoginRequest) :: RemoteEvent?
	self._updateRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.DailyLoginUpdate) :: RemoteEvent?

	if self._requestRemote and self._requestRemote:IsA("RemoteEvent") then
		table.insert(self._connections, self._requestRemote.OnServerEvent:Connect(function(player: Player, payload: any)
			self:_handleRequest(player, payload)
		end))
	else
		warn("[DailyLoginService] Missing LauncherArenaRemotes.DailyLoginRequest.")
	end
	if not self._updateRemote or not self._updateRemote:IsA("RemoteEvent") then
		self._updateRemote = nil
		warn("[DailyLoginService] Missing LauncherArenaRemotes.DailyLoginUpdate.")
	end

	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end))
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end
end

function DailyLoginService:Start()
	-- Daily countdowns are estimated on Client from ServerNow/NextResetAt.
	-- The server only sends state changes and never trusts the Client's timer.
end

return DailyLoginService
