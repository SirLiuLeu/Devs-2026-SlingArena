--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local TOP_SCOREBOARD_LIMIT = 100
local PUBLISH_INTERVAL_SECONDS = 0.4
local GLOBAL_TOP_100_REFRESH_SECONDS = 60

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local function safeNumber(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

local function ensureLeaderstats(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats")
	if folder and folder:IsA("Folder") then return folder end
	folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player
	return folder
end

local function ensureIntValue(parent: Folder, name: string): IntValue
	local value = parent:FindFirstChild(name)
	if value and value:IsA("IntValue") then return value end
	value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent
	return value
end

local function getPlayerStateService(self)
	return ServiceResolver.Get(self._context, "PlayerStateService")
end

function LeaderboardService.new(context)
	local self = setmetatable({}, LeaderboardService)
	self._context = context
	self._cachedRanks = {}
	self._kills = {} :: { [number]: number }
	self._deaths = {} :: { [number]: number }
	self._scoreboardRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchScoreboardUpdate) :: RemoteEvent?
	self._globalTop100Remote = context.Remotes:FindFirstChild(RemoteContracts.Names.GlobalTop100Update) :: RemoteEvent?
	self._scoreboardDirty = true
	self._globalTop100Dirty = true
	self._lastPublishedSnapshot = nil
	self._lastGlobalSnapshot = nil
	self._schedulerStarted = false
	self._globalLoopStarted = false
	return self
end

function LeaderboardService:_getRoundPoints(player: Player): number
	local data = ServiceResolver.Get(self._context, "PlayerDataService")
	if data and typeof(data.GetRoundProgressPoints) == "function" then
		return math.floor(data:GetRoundProgressPoints(player))
	end
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	return math.floor(safeNumber(state and state.RankPoints, 0))
end

function LeaderboardService:_getSortedPlayers(): { Player }
	local rows = {}
	local stateService = getPlayerStateService(self)
	for _, player in ipairs(Players:GetPlayers()) do
		local state = stateService and stateService:GetState(player) or nil
		table.insert(rows, { player = player, points = self:_getRoundPoints(player), level = safeNumber(state and state.Level, 0) })
	end
	table.sort(rows, function(a, b)
		if a.points ~= b.points then return a.points > b.points end
		if a.level ~= b.level then return a.level > b.level end
		return a.player.UserId < b.player.UserId
	end)
	local players = {}
	for index, row in ipairs(rows) do players[index] = row.player end
	return players
end

function LeaderboardService:_syncPlayer(player: Player)
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	local leaderstats = ensureLeaderstats(player)
	ensureIntValue(leaderstats, "Level").Value = math.floor(safeNumber(state and state.Level, 0))
	ensureIntValue(leaderstats, "Points").Value = self:_getRoundPoints(player)
	ensureIntValue(leaderstats, "Rank").Value = self._cachedRanks[player] or 0
end

function LeaderboardService:_recomputeRanks()
	local sorted = self:_getSortedPlayers()
	local previousPoints, currentRank = nil, 0
	for index, player in ipairs(sorted) do
		local points = self:_getRoundPoints(player)
		if previousPoints == nil or points ~= previousPoints then currentRank, previousPoints = index, points end
		self._cachedRanks[player] = currentRank
		self:_syncPlayer(player)
	end
end

function LeaderboardService:_buildRows(): { any }
	local stateService = getPlayerStateService(self)
	local rows = {}
	for index, player in ipairs(self:_getSortedPlayers()) do
		if index > TOP_SCOREBOARD_LIMIT then break end
		local state = stateService and stateService:GetState(player) or nil
		table.insert(rows, { UserId = player.UserId, Rank = self._cachedRanks[player] or index, Name = player.DisplayName ~= "" and player.DisplayName or player.Name, Level = math.floor(safeNumber(state and state.Level, 0)), Points = self:_getRoundPoints(player), Kills = self._kills[player.UserId] or 0, Deaths = self._deaths[player.UserId] or 0, State = tostring((state and state.ActivePlayerMode) or GameStates.PlayerMode.Human) })
	end
	return rows
end

function LeaderboardService:_makeSnapshot(rows: { any }): { any }
	local snapshot = {}
	for index, row in ipairs(rows) do
		snapshot[index] = { UserId = row.UserId, Rank = row.Rank, Points = math.floor(safeNumber(row.Points or row.ProgressPoints, 0) + 0.5), Kills = row.Kills or 0, Deaths = row.Deaths or 0 }
	end
	return snapshot
end

local function snapshotChanged(previous: any, rows: { any }): boolean
	if type(previous) ~= "table" or #previous ~= #rows then return true end
	for index, row in ipairs(rows) do
		local old = previous[index]
		local points = math.floor(safeNumber(row.Points or row.ProgressPoints, 0) + 0.5)
		if old.UserId ~= row.UserId or old.Rank ~= row.Rank or old.Points ~= points or old.Kills ~= (row.Kills or 0) or old.Deaths ~= (row.Deaths or 0) then return true end
	end
	return false
end

function LeaderboardService:_publishDirty()
	if not self._scoreboardDirty and not self._globalTop100Dirty then return end
	self:_recomputeRanks()
	if self._scoreboardDirty then
		local rows = self:_buildRows()
		if snapshotChanged(self._lastPublishedSnapshot, rows) and self._scoreboardRemote then
			self._scoreboardRemote:FireAllClients({ Rows = rows, Limit = TOP_SCOREBOARD_LIMIT })
			self._lastPublishedSnapshot = self:_makeSnapshot(rows)
		end
		self._scoreboardDirty = false
	end
	if self._globalTop100Dirty then
		local rows = self:GetGlobalTop100()
		if snapshotChanged(self._lastGlobalSnapshot, rows) and self._globalTop100Remote then
			self._globalTop100Remote:FireAllClients({ Rows = rows, Limit = TOP_SCOREBOARD_LIMIT, GeneratedAt = os.time() })
			self._lastGlobalSnapshot = self:_makeSnapshot(rows)
		end
		self._globalTop100Dirty = false
	end
end

function LeaderboardService:Init()
	local function mark(scoreboard: boolean, global: boolean)
		self._scoreboardDirty = self._scoreboardDirty or scoreboard
		self._globalTop100Dirty = self._globalTop100Dirty or global
	end
	Players.PlayerAdded:Connect(function() mark(true, true) end)
	Players.PlayerRemoving:Connect(function(player) self._cachedRanks[player] = nil; self._kills[player.UserId] = nil; self._deaths[player.UserId] = nil; mark(true, true) end)
	self._context.EventBus:On("LevelUp", function() mark(true, false) end)
	self._context.EventBus:On("PlayerStateUpdated", function() mark(true, false) end)
	self._context.EventBus:On("ProgressPointsChanged", function() mark(true, true) end)
	self._context.EventBus:On("PlayerKilled", function(killer: Player) self._kills[killer.UserId] = (self._kills[killer.UserId] or 0) + 1; mark(true, false) end)
	self._context.EventBus:On("PlayerDied", function(player: Player) self._deaths[player.UserId] = (self._deaths[player.UserId] or 0) + 1; mark(true, false) end)
end

function LeaderboardService:Start()
	if self._schedulerStarted then return end
	self._schedulerStarted = true
	task.spawn(function()
		while self._schedulerStarted do self:_publishDirty(); task.wait(PUBLISH_INTERVAL_SECONDS) end
	end)
	self._globalLoopStarted = true
	task.spawn(function()
		while self._globalLoopStarted do task.wait(GLOBAL_TOP_100_REFRESH_SECONDS); if self._globalTop100Dirty then self:_publishDirty() end end
	end)
end

function LeaderboardService:GetTopPlayers(limit: number?): { any }
	local rows = self:_buildRows()
	while #rows > math.max(1, math.min(limit or TOP_SCOREBOARD_LIMIT, TOP_SCOREBOARD_LIMIT)) do table.remove(rows) end
	return rows
end

function LeaderboardService:PublishScoreboard() self._scoreboardDirty = true end
function LeaderboardService:GetGlobalTop100(): { any }
	local data = ServiceResolver.Get(self._context, "PlayerDataService")
	local provider = data and typeof(data.GetProvider) == "function" and data:GetProvider() or nil
	return if provider and typeof(provider.GetTopProgressPointProfiles) == "function" then provider:GetTopProgressPointProfiles(TOP_SCOREBOARD_LIMIT) else {}
end
function LeaderboardService:PublishGlobalTop100() self._globalTop100Dirty = true end
function LeaderboardService:ResetForNewRound()
	table.clear(self._kills); table.clear(self._deaths)
	local data = ServiceResolver.Get(self._context, "PlayerDataService")
	if data and typeof(data.ResetRoundProgressPoints) == "function" then for _, player in ipairs(Players:GetPlayers()) do data:ResetRoundProgressPoints(player) end end
	self._scoreboardDirty = true
end
function LeaderboardService:GetPlayerRank(player: Player): number? return self._cachedRanks[player] end
return LeaderboardService
