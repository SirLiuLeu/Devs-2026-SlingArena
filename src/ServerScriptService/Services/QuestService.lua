--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type Context = { EventBus: any?, Services: any?, ServiceRegistry: any?, Remotes: Folder? }

local QuestService = {}
QuestService.__index = QuestService

local SECONDS_PER_DAY = 24 * 60 * 60
local SECONDS_PER_WEEK = 7 * SECONDS_PER_DAY
local DAILY_CHAIN = QuestConfig.DailyQuestChain
local MAX_DAILY_STEPS = math.max(1, math.floor(tonumber(DAILY_CHAIN.MaxDailySteps) or 5))
local SKIP_COOLDOWN_SECONDS = math.max(1, math.floor(tonumber(DAILY_CHAIN.SkipCooldownSeconds) or 90))

local WEEKLY_REWARD_TIERS = {
	{ MinPoints = 5000, Reward = { Diamonds = 250 } },
	{ MinPoints = 2500, Reward = { Diamonds = 125 } },
	{ MinPoints = 1000, Reward = { Diamonds = 50 } },
	{ MinPoints = 250, Reward = { Diamonds = 10 } },
}

local function currentDayKey(now: number): number
	local date = os.date("!*t", now)
	return date.year * 10000 + date.month * 100 + date.day
end

local function currentMondayStamp(now: number): number
	local date = os.date("!*t", now)
	local daysSinceMonday = (date.wday + 5) % 7
	date.hour = 0
	date.min = 0
	date.sec = 0
	return os.time(date) - (daysSinceMonday * SECONDS_PER_DAY)
end

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

function QuestService.new(context: Context)
	local self = setmetatable({}, QuestService)
	self._context = context
	self._onlineStartedAt = {} :: { [number]: number }
	self._nextOnlineFlushAt = {} :: { [number]: number }
	self._nextDailyCheckAt = {} :: { [number]: number }
	self._lastRemoteRequestAt = {} :: { [number]: number }
	self._claimLocks = {} :: { [number]: boolean }
	return self
end

function QuestService:Init()
	self:_ensureRemotes()

	if self._claimRemote then
		self._claimRemote.OnServerEvent:Connect(function(player: Player, assignmentId: any)
			if RemoteContracts.Validate(RemoteContracts.Names.QuestClaim, assignmentId) then
				self:ClaimQuest(player, assignmentId)
			else
				self:_sendActionResult(player, "ClaimResult", {
					Success = false,
					Reason = "InvalidRequest",
					AssignmentId = tostring(assignmentId),
				})
			end
		end)
	end

	if self._skipRemote then
		self._skipRemote.OnServerEvent:Connect(function(player: Player, assignmentId: any)
			if RemoteContracts.Validate(RemoteContracts.Names.QuestSkip, assignmentId) then
				self:SkipQuest(player, assignmentId)
			else
				self:_sendActionResult(player, "SkipResult", {
					Success = false,
					Reason = "InvalidRequest",
					AssignmentId = tostring(assignmentId),
				})
			end
		end)
	end

	if self._context.EventBus then
		self._context.EventBus:On("DailyQuestFoodCollected", function(player: Player, _foodType: string, rarity: string)
			if type(rarity) ~= "string" then
				return
			end
			local allowedRarities = {
				Common = true,
				Uncommon = true,
				Rare = true,
				Epic = true,
				Legendary = true,
			}
			if allowedRarities[rarity] then
				self:_incrementMetric(player, "Food_" .. rarity, 1)
			end
		end)

		self._context.EventBus:On("DamageDealt", function(attacker: Player, victim: Player, amount: number)
			if attacker ~= victim and typeof(amount) == "number" and amount > 0 then
				self:_incrementMetric(attacker, "DamageDealtToPlayers", amount)
			end
		end)

		self._context.EventBus:On("DoTDamageDealt", function(attacker: Player, victim: Player, amount: number)
			if attacker ~= victim and typeof(amount) == "number" and amount > 0 then
				self:_incrementMetric(attacker, "DamageDealtToPlayers", amount)
			end
		end)

		self._context.EventBus:On("PlayerKilled", function(killer: Player, victim: Player)
			if killer ~= victim then
				self:_incrementMetric(killer, "PlayerKills", 1)
			end
		end)

		self._context.EventBus:On("LauncherLaunched", function(player: Player)
			self:_incrementMetric(player, "LaunchCount", 1)
		end)

		self._context.EventBus:On("RoundCompleted", function(player: Player)
			self:_incrementMetric(player, "CompletedRounds", 1)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_flushOnlineTime(player)
		local playerDataService = self:_getPlayerDataService()
		if playerDataService and typeof(playerDataService.SavePlayer) == "function" then
			playerDataService:SavePlayer(player)
		end
		self:_clearPlayerRuntime(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			self:_processPlayers()
		end
	end)
end

function QuestService:_onPlayerAdded(player: Player)
	local userId = player.UserId
	local now = os.time()
	self._onlineStartedAt[userId] = now
	self._nextOnlineFlushAt[userId] = now + 10
	self._nextDailyCheckAt[userId] = now + 60

	task.defer(function()
		if player.Parent ~= Players then
			return
		end
		self:EnsurePlayerQuestState(player)
		self:ProcessWeeklyRewards(player)
		self:_ensureActiveQuest(player)
		self:SendSnapshot(player)
	end)
end

function QuestService:_clearPlayerRuntime(player: Player)
	local userId = player.UserId
	self._onlineStartedAt[userId] = nil
	self._nextOnlineFlushAt[userId] = nil
	self._nextDailyCheckAt[userId] = nil
	self._lastRemoteRequestAt[userId] = nil
	self._claimLocks[userId] = nil
end

function QuestService:_processPlayers()
	local now = os.time()
	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		local data = playerDataService:GetData(player)
		local questState = data and data.QuestState
		local chain = questState and questState.DailyChain

		local onlineFlushAt = self._nextOnlineFlushAt[userId] or now + 10
		if now >= onlineFlushAt then
			self._nextOnlineFlushAt[userId] = now + 10
			if self:_flushOnlineTime(player) then
				self:SendSnapshot(player)
			end
		end

		local dailyCheckAt = self._nextDailyCheckAt[userId] or now + 60
		if now >= dailyCheckAt then
			self._nextDailyCheckAt[userId] = now + 60
			local previousDayKey = questState and questState.DailyResetKey
			local normalizedState = self:EnsurePlayerQuestState(player)
			local currentKey = currentDayKey(now)
			if normalizedState and normalizedState.DailyResetKey ~= previousDayKey then
				self:_ensureActiveQuest(player)
				self:SendSnapshot(player)
			elseif normalizedState and not normalizedState.DailyChain.ActiveQuest
				and not normalizedState.DailyChain.CompletedForDay
				and (tonumber(normalizedState.DailyChain.NextQuestAt) or 0) <= now then
				if self:_ensureActiveQuest(player) then
					self:SendSnapshot(player)
				end
			end
		end

		if chain and (tonumber(chain.NextQuestAt) or 0) > 0 and now >= (tonumber(chain.NextQuestAt) or 0) then
			if self:_ensureActiveQuest(player) then
				self:SendSnapshot(player)
			end
		end
	end
end

function QuestService:_ensureRemotes()
	local folder = self._context.Remotes or ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	if not folder then
		warn("[QuestService] LauncherArenaRemotes is missing.")
		return
	end
	self._updateRemote = folder:FindFirstChild(RemoteContracts.Names.QuestUpdate) :: RemoteEvent?
	self._claimRemote = folder:FindFirstChild(RemoteContracts.Names.QuestClaim) :: RemoteEvent?
	self._skipRemote = folder:FindFirstChild(RemoteContracts.Names.QuestSkip) :: RemoteEvent?

	if not self._updateRemote then
		warn("[QuestService] Missing LauncherArenaRemotes.QuestUpdate (RemoteEvent).")
	end
	if not self._claimRemote then
		warn("[QuestService] Missing LauncherArenaRemotes.QuestClaim (RemoteEvent).")
	end
	if not self._skipRemote then
		warn("[QuestService] Missing LauncherArenaRemotes.QuestSkip (RemoteEvent); create it from the Rojo model file.")
	end
end

function QuestService:_getPlayerDataService()
	return ServiceResolver.Get(self._context, "PlayerDataService")
end

function QuestService:EnsurePlayerQuestState(player: Player)
	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then
		return nil
	end
	return playerDataService:EnsureQuestData(player, currentDayKey(os.time()))
end

function QuestService:_flushOnlineTime(player: Player): boolean
	local startedAt = self._onlineStartedAt[player.UserId]
	if not startedAt then
		return false
	end

	local now = os.time()
	local elapsed = math.max(0, now - startedAt)
	if elapsed <= 0 then
		return false
	end

	self._onlineStartedAt[player.UserId] = now
	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then
		return false
	end
	playerDataService:IncrementQuestMetric(player, "OnlineTimeSeconds", elapsed)
	return true
end

function QuestService:_incrementMetric(player: Player, metricName: string, amount: number)
	if not player or player.Parent ~= Players then
		return
	end
	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then
		return
	end

	playerDataService:IncrementQuestMetric(player, metricName, amount)
	local state = playerDataService:GetData(player).QuestState
	local activeQuest = state and state.DailyChain and state.DailyChain.ActiveQuest
	if activeQuest and activeQuest.MetricKey == metricName then
		self:SendSnapshot(player)
	end
end

function QuestService:_chooseQuest(stepIndex: number, state: any): any?
	local step = DAILY_CHAIN.Steps[stepIndex]
	if type(step) ~= "table" or type(step.QuestPool) ~= "table" or #step.QuestPool == 0 then
		return nil
	end

	local assignedIds = state.DailyChain and state.DailyChain.AssignedQuestIds or {}
	local available = {}
	for _, quest in ipairs(step.QuestPool) do
		if type(quest) == "table" and type(quest.Id) == "string" and assignedIds[quest.Id] ~= true then
			table.insert(available, quest)
		end
	end
	local pool = if #available > 0 then available else step.QuestPool
	local selected = pool[math.random(1, #pool)]
	return {
		QuestId = selected.Id,
		AssignmentId = HttpService:GenerateGUID(false),
		Step = stepIndex,
		Type = selected.Type,
		MetricKey = selected.MetricKey,
		Target = math.max(1, math.floor(tonumber(selected.Target) or 1)),
		Desc = tostring(selected.Desc or selected.Id),
		Rarity = selected.Rarity,
		Baseline = math.max(0, tonumber((state.Metrics or {})[selected.MetricKey]) or 0),
		Reward = deepCopy(step.Reward or {}),
	}
end

function QuestService:_ensureActiveQuest(player: Player): boolean
	local state = self:EnsurePlayerQuestState(player)
	if not state or type(state.DailyChain) ~= "table" then
		return false
	end

	local chain = state.DailyChain
	if chain.CompletedForDay == true or chain.ActiveQuest ~= nil then
		return false
	end

	local now = os.time()
	local nextQuestAt = tonumber(chain.NextQuestAt) or 0
	if nextQuestAt > now then
		return false
	end

	local stepIndex = math.clamp(math.floor(tonumber(chain.Step) or 1), 1, MAX_DAILY_STEPS)
	local assignment = self:_chooseQuest(stepIndex, state)
	if not assignment then
		warn(string.format("[QuestService] No configured quest pool for daily step %d.", stepIndex))
		return false
	end

	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then
		return false
	end
	local success = playerDataService:SetDailyQuestAssignment(player, assignment, nextQuestAt)
	return success == true
end

function QuestService:_getQuestProgress(state: any, quest: any): number
	local metrics = state.Metrics or {}
	local current = math.max(0, tonumber(metrics[quest.MetricKey]) or 0)
	local baseline = math.max(0, tonumber(quest.Baseline) or 0)
	return math.max(0, math.floor(current - baseline))
end

function QuestService:BuildSnapshot(player: Player)
	local state = self:EnsurePlayerQuestState(player) or {}
	local chain = state.DailyChain or {}
	local active = chain.ActiveQuest
	local now = os.time()

	local status = "Preparing"
	local activeView = nil
	local nextQuestAt = math.max(0, tonumber(chain.NextQuestAt) or 0)

	if chain.CompletedForDay == true or (tonumber(chain.CompletedSteps) or 0) >= MAX_DAILY_STEPS then
		status = "CompletedForDay"
	elseif nextQuestAt > now then
		status = "Cooldown"
	elseif type(active) == "table" then
		local progress = math.min(self:_getQuestProgress(state, active), math.max(1, tonumber(active.Target) or 1))
		local target = math.max(1, tonumber(active.Target) or 1)
		local questStatus = if progress >= target then "Ready" else "Active"
		status = questStatus
		activeView = {
			Id = tostring(active.QuestId or ""),
			AssignmentId = tostring(active.AssignmentId or ""),
			Step = math.max(1, math.floor(tonumber(active.Step) or 1)),
			Type = tostring(active.Type or ""),
			Desc = tostring(active.Desc or active.QuestId or "Daily Quest"),
			Target = target,
			Progress = progress,
			Reward = deepCopy(active.Reward or {}),
			State = questStatus,
		}
	end

	local playerDataService = self:_getPlayerDataService()
	local weeklyPoints = 0
	if playerDataService then
		local _totalPoints
		_totalPoints, weeklyPoints = playerDataService:GetProgressPoints(player)
	end

	return {
		DailyQuest = {
			CurrentStep = math.max(1, math.floor(tonumber(chain.Step) or 1)),
			CompletedSteps = math.max(0, math.floor(tonumber(chain.CompletedSteps) or 0)),
			MaxSteps = MAX_DAILY_STEPS,
			Status = status,
			NextQuestAt = nextQuestAt,
			ActiveQuest = activeView,
		},
		Weekly = {
			Points = weeklyPoints,
			ResetAt = currentMondayStamp(now) + SECONDS_PER_WEEK,
		},
		ServerNow = now,
	}
end

function QuestService:SendSnapshot(player: Player, actionKey: string?, actionResult: any?)
	if not self._updateRemote then
		return
	end
	local payload = {
		Type = "Snapshot",
		Snapshot = self:BuildSnapshot(player),
	}
	if actionKey and actionResult then
		payload[actionKey] = actionResult
	end
	self._updateRemote:FireClient(player, payload)
end

function QuestService:_sendActionResult(player: Player, actionKey: string, result: any)
	self:SendSnapshot(player, actionKey, result)
end

function QuestService:_allowRemoteRequest(player: Player): boolean
	local now = os.clock()
	local last = self._lastRemoteRequestAt[player.UserId] or 0
	if now - last < 0.2 then
		return false
	end
	self._lastRemoteRequestAt[player.UserId] = now
	return true
end

function QuestService:ClaimQuest(player: Player, assignmentId: string): boolean
	if not self:_allowRemoteRequest(player) or self._claimLocks[player.UserId] then
		self:_sendActionResult(player, "ClaimResult", {
			Success = false,
			Reason = "RequestPending",
			AssignmentId = assignmentId,
		})
		return false
	end
	self._claimLocks[player.UserId] = true

	local state = self:EnsurePlayerQuestState(player)
	local chain = state and state.DailyChain
	local active = chain and chain.ActiveQuest
	local result = {
		Success = false,
		Reason = "StaleQuest",
		AssignmentId = assignmentId,
	}

	if type(active) == "table" and active.AssignmentId == assignmentId then
		local progress = self:_getQuestProgress(state, active)
		if progress < (tonumber(active.Target) or math.huge) then
			result.Reason = "NotReady"
		else
			local nextQuest = nil
			local completedAfterClaim = (tonumber(chain.CompletedSteps) or 0) + 1
			if completedAfterClaim < MAX_DAILY_STEPS then
				nextQuest = self:_chooseQuest(math.min(MAX_DAILY_STEPS, (tonumber(chain.Step) or 1) + 1), state)
			end

			local playerDataService = self:_getPlayerDataService()
			if playerDataService then
				local success, reason = playerDataService:CommitDailyQuestClaim(
					player,
					assignmentId,
					tostring(active.QuestId or ""),
					active.Reward or {},
					nextQuest,
					MAX_DAILY_STEPS
				)
				result.Success = success == true
				result.Reason = if success then "Claimed" else tostring(reason or "Rejected")
				result.Reward = if success then deepCopy(active.Reward or {}) else nil
			end
		end
	end

	self._claimLocks[player.UserId] = nil
	self:_sendActionResult(player, "ClaimResult", result)
	return result.Success
end

function QuestService:SkipQuest(player: Player, assignmentId: string): boolean
	if not self:_allowRemoteRequest(player) then
		self:_sendActionResult(player, "SkipResult", {
			Success = false,
			Reason = "RateLimited",
			AssignmentId = assignmentId,
		})
		return false
	end

	local state = self:EnsurePlayerQuestState(player)
	local chain = state and state.DailyChain
	local active = chain and chain.ActiveQuest
	local result = {
		Success = false,
		Reason = "StaleQuest",
		AssignmentId = assignmentId,
	}

	if type(active) == "table" and active.AssignmentId == assignmentId and chain.CompletedForDay ~= true then
		local progress = self:_getQuestProgress(state, active)
		if progress >= (tonumber(active.Target) or math.huge) then
			result.Reason = "AlreadyReady"
		else
			local playerDataService = self:_getPlayerDataService()
			if playerDataService then
				local nextQuestAt = os.time() + SKIP_COOLDOWN_SECONDS
				local success, reason = playerDataService:SkipDailyQuest(player, assignmentId, nextQuestAt)
				result.Success = success == true
				result.Reason = if success then "CooldownStarted" else tostring(reason or "Rejected")
				result.NextQuestAt = if success then nextQuestAt else nil
			end
		end
	end

	self:_sendActionResult(player, "SkipResult", result)
	return result.Success
end

function QuestService:_weeklyRewardForPoints(points: number): any?
	for _, tier in ipairs(WEEKLY_REWARD_TIERS) do
		if points >= tier.MinPoints then
			return tier.Reward
		end
	end
	return nil
end

function QuestService:ProcessWeeklyRewards(player: Player)
	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then
		return
	end
	local pending = playerDataService:ConsumePendingWeeklyReward(player)
	if not pending or (pending.Points or 0) <= 0 then
		return
	end
	local reward = self:_weeklyRewardForPoints(pending.Points)
	if reward then
		playerDataService:GrantReward(player, reward, "WeeklyReward")
	end
end

return QuestService
