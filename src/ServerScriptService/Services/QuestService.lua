--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

type Context = { EventBus: any?, Services: any?, ServiceRegistry: any?, Remotes: Folder? }

local QuestService = {}
QuestService.__index = QuestService

local SECONDS_PER_DAY = 24 * 60 * 60
local SECONDS_PER_WEEK = 7 * SECONDS_PER_DAY

local WEEKLY_REWARD_TIERS = {
	{ MinPoints = 5000, Reward = { Diamonds = 250, Items = { { Id = "gacha_ticket", Quantity = 5 } } } },
	{ MinPoints = 2500, Reward = { Diamonds = 125, Items = { { Id = "gacha_ticket", Quantity = 3 } } } },
	{ MinPoints = 1000, Reward = { Diamonds = 50, Items = { { Id = "gacha_ticket", Quantity = 1 } } } },
	{ MinPoints = 250, Reward = { Diamonds = 10 } },
}

local function getService(context: Context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function currentDayStamp(now: number): number
	local date = os.date("!*t", now)
	date.hour = 0; date.min = 0; date.sec = 0
	return os.time(date)
end

local function currentMondayStamp(now: number): number
	local date = os.date("!*t", now)
	local daysSinceMonday = (date.wday + 5) % 7
	date.hour = 0; date.min = 0; date.sec = 0
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

local function flattenDailyQuests(): { any }
	local quests = {}
	for key, quest in pairs(QuestConfig.DailyQuests or {}) do
		if key == "CollectSpecificFood" and type(quest) == "table" then
			local selected = quest.Common
			if not selected then
				local _, firstQuest = next(quest)
				selected = firstQuest
			end
			if type(selected) == "table" then
				table.insert(quests, selected)
			end
		elseif type(quest) == "table" and quest.Id then
			table.insert(quests, quest)
		end
	end
	table.sort(quests, function(a, b) return tostring(a.Id) < tostring(b.Id) end)
	return quests
end

local function flattenMainQuests(): { any }
	local quests = {}
	for family, quest in pairs(QuestConfig.MainQuests or {}) do
		for index, target in ipairs(quest.Milestones or {}) do
			local diamonds = (quest.Rewards or {})[index] or 0
			table.insert(quests, {
				Id = string.format("M_%s_%d", tostring(family), index),
				Type = quest.Type,
				Target = target,
				Reward = { Diamonds = diamonds },
				Desc = string.format(quest.Desc or tostring(family), target),
				Family = family,
				MilestoneIndex = index,
			})
		end
	end
	table.sort(quests, function(a, b) return tostring(a.Id) < tostring(b.Id) end)
	return quests
end

local DAILY_QUESTS = flattenDailyQuests()
local MAIN_QUESTS = flattenMainQuests()

function QuestService.new(context: Context)
	local self = setmetatable({}, QuestService)
	self._context = context
	self._onlineStartedAt = {} :: { [number]: number }
	return self
end

function QuestService:Init()
	self:_ensureRemotes()
	Players.PlayerAdded:Connect(function(player)
		self._onlineStartedAt[player.UserId] = os.time()
		task.defer(function()
			self:EnsurePlayerQuestState(player)
			self:ProcessWeeklyRewards(player)
			self:SendSnapshot(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_flushOnlineTime(player)
		self._onlineStartedAt[player.UserId] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self._onlineStartedAt[player.UserId] = os.time()
		self:EnsurePlayerQuestState(player)
		self:ProcessWeeklyRewards(player)
		self:SendSnapshot(player)
	end
	if self._claimRemote then
		self._claimRemote.OnServerEvent:Connect(function(player: Player, questId: any)
			if type(questId) == "string" then
				self:ClaimQuest(player, questId)
			end
		end)
	end
	if self._context.EventBus then
		self._context.EventBus:On("ProgressPointsChanged", function(player: Player, totalPoints: number, weeklyPoints: number)
			self:_setMetric(player, "CollectPointsTotal", totalPoints)
			self:_setMetric(player, "CollectPoints", weeklyPoints)
			self:SendSnapshot(player)
		end)
		self._context.EventBus:On("PlayerKilled", function(killer: Player)
			self:_incrementMetric(killer, "KillPlayersTotal", 1)
		end)
		self._context.EventBus:On("RequestLaunchAccepted", function(player: Player)
			self:_incrementMetric(player, "LaunchTotal", 1)
		end)
	end
end

function QuestService:_ensureRemotes()
	local folder = self._context.Remotes or ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	if not folder then return end
	self._updateRemote = folder:FindFirstChild(RemoteContracts.Names.QuestUpdate) :: RemoteEvent?
	self._claimRemote = folder:FindFirstChild(RemoteContracts.Names.QuestClaim) :: RemoteEvent?
end

function QuestService:_getPlayerDataService()
	return getService(self._context, "PlayerDataService")
end

function QuestService:EnsurePlayerQuestState(player: Player)
	local playerDataService = self:_getPlayerDataService()
	if not playerDataService then return nil end
	return playerDataService:EnsureQuestData(player, currentDayStamp(os.time()))
end

function QuestService:_flushOnlineTime(player: Player)
	local startedAt = self._onlineStartedAt[player.UserId]
	if not startedAt then return end
	local elapsed = math.max(0, os.time() - startedAt)
	self._onlineStartedAt[player.UserId] = os.time()
	self:_incrementMetric(player, "OnlineTime", elapsed, false)
	self:_incrementMetric(player, "PlayTimeTotal", elapsed, false)
end

function QuestService:_incrementMetric(player: Player, metricName: string, amount: number, shouldSend: boolean?)
	local playerDataService = self:_getPlayerDataService(); if not playerDataService then return end
	playerDataService:IncrementQuestMetric(player, metricName, amount)
	if shouldSend ~= false then self:SendSnapshot(player) end
end

function QuestService:_setMetric(player: Player, metricName: string, value: number)
	local playerDataService = self:_getPlayerDataService(); if not playerDataService then return end
	playerDataService:SetQuestMetric(player, metricName, value)
end

function QuestService:_getProgressForQuest(state: any, quest: any): number
	local metrics = state.Metrics or {}
	return math.max(0, math.floor(metrics[quest.Type] or 0))
end

function QuestService:_buildQuestView(state: any, quest: any)
	local progress = math.min(self:_getProgressForQuest(state, quest), quest.Target or 0)
	local claimed = state.Claimed and state.Claimed[quest.Id] == true
	return {
		Id = quest.Id,
		Type = quest.Type,
		Desc = quest.Desc or quest.Id,
		Target = quest.Target or 0,
		Progress = progress,
		Reward = deepCopy(quest.Reward or {}),
		State = if claimed then "Claimed" elseif progress >= (quest.Target or math.huge) then "Ready" else "Locked",
	}
end

function QuestService:BuildSnapshot(player: Player)
	self:_flushOnlineTime(player)
	local state = self:EnsurePlayerQuestState(player) or {}
	local daily, main = {}, {}
	for i, quest in ipairs(DAILY_QUESTS) do daily[i] = self:_buildQuestView(state, quest) end
	for i, quest in ipairs(MAIN_QUESTS) do main[i] = self:_buildQuestView(state, quest) end
	local playerDataService = self:_getPlayerDataService()
	local weeklyPoints = 0
	if playerDataService then
		local _totalPoints
		_totalPoints, weeklyPoints = playerDataService:GetProgressPoints(player)
	end
	return { Daily = daily, Main = main, Weekly = { Points = weeklyPoints, ResetAt = currentMondayStamp(os.time()) + SECONDS_PER_WEEK } }
end

function QuestService:SendSnapshot(player: Player, claimResult: any?)
	if self._updateRemote then
		self._updateRemote:FireClient(player, { Type = "Snapshot", Snapshot = self:BuildSnapshot(player), ClaimResult = claimResult })
	end
end

function QuestService:_findQuest(questId: string): any?
	for _, quest in ipairs(DAILY_QUESTS) do if quest.Id == questId then return quest end end
	for _, quest in ipairs(MAIN_QUESTS) do if quest.Id == questId then return quest end end
	return nil
end

function QuestService:ClaimQuest(player: Player, questId: string): boolean
	local quest = self:_findQuest(questId)
	local state = self:EnsurePlayerQuestState(player)
	local result = { QuestId = questId, Success = false, Reason = "NotReady" }
	if quest and state and not (state.Claimed and state.Claimed[questId]) and self:_getProgressForQuest(state, quest) >= (quest.Target or math.huge) then
		local playerDataService = self:_getPlayerDataService()
		if playerDataService then
			playerDataService:MarkQuestClaimed(player, questId)
			playerDataService:GrantReward(player, quest.Reward or {}, "QuestClaim:" .. questId)
			if questId:sub(1, 2) == "D_" then
				self:_incrementMetric(player, "CompleteDailyTotal", 1, false)
			end
			result.Success = true; result.Reason = "Claimed"; result.Reward = quest.Reward
		end
	end
	self:SendSnapshot(player, result)
	return result.Success
end

function QuestService:_weeklyRewardForPoints(points: number): any?
	for _, tier in ipairs(WEEKLY_REWARD_TIERS) do
		if points >= tier.MinPoints then return tier.Reward end
	end
	return nil
end

function QuestService:ProcessWeeklyRewards(player: Player)
	local playerDataService = self:_getPlayerDataService(); if not playerDataService then return end
	local pending = playerDataService:ConsumePendingWeeklyReward(player)
	if not pending or (pending.Points or 0) <= 0 then return end
	local reward = self:_weeklyRewardForPoints(pending.Points)
	if reward then
		playerDataService:GrantReward(player, reward, "WeeklyReward")
	end
end

return QuestService
