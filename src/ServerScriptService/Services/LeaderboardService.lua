--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local TOP_SCOREBOARD_LIMIT = 100
local GLOBAL_TOP_100_REFRESH_SECONDS = 60

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

function LeaderboardService.new(context)
	local self = setmetatable({}, LeaderboardService)
	self._context = context
	self._cachedRanks = {}
	self._kills = {} :: { [number]: number }
	self._deaths = {} :: { [number]: number }
	self._scoreboardRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchScoreboardUpdate) :: RemoteEvent?
	self._globalTop100Remote = context.Remotes:FindFirstChild(RemoteContracts.Names.GlobalTop100Update) :: RemoteEvent?
	self._globalLoopStarted = false
	return self
end

local function ensureLeaderstats(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:IsA("Folder") then
		return leaderstats
	end
	leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	return leaderstats
end

local function ensureIntValue(parent: Folder, name: string): IntValue
	local value = parent:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end
	value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent
	return value
end

local function safeNumber(value: any, fallback: number): number
	if type(value) == "number" and value == value then
		return value
	end
	return fallback
end

local function getPlayerStateService(self)
	return ServiceResolver.Get(self._context, "PlayerStateService")
end

function LeaderboardService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_syncPlayer(player)
		self:_recomputeRanks()
		self:PublishScoreboard()
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._cachedRanks[player] = nil
		self._kills[player.UserId] = nil
		self._deaths[player.UserId] = nil
		self:_recomputeRanks()
		self:PublishScoreboard()
	end)
	self._context.EventBus:On("LevelUp", function(player: Player)
		self:_syncPlayer(player)
		self:_recomputeRanks()
		self:PublishScoreboard()
	end)
	self._context.EventBus:On("PlayerStateUpdated", function(player: Player)
		self:_syncPlayer(player)
		self:_recomputeRanks()
		self:PublishScoreboard()
	end)
	self._context.EventBus:On("ProgressPointsChanged", function(player: Player)
		self:_syncPlayer(player)
		self:_recomputeRanks()
		self:PublishScoreboard()
		self:PublishGlobalTop100()
	end)
	self._context.EventBus:On("PlayerKilled", function(killer: Player, _victim: Player)
		self._kills[killer.UserId] = (self._kills[killer.UserId] or 0) + 1
		task.defer(function()
			self:_recomputeRanks()
			self:PublishScoreboard()
		end)
	end)
	self._context.EventBus:On("PlayerDied", function(player: Player)
		self._deaths[player.UserId] = (self._deaths[player.UserId] or 0) + 1
		self:PublishScoreboard()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_syncPlayer(player)
	end
	self:_recomputeRanks()
	self:PublishScoreboard()
	self:PublishGlobalTop100()
end

function LeaderboardService:Start()
	if self._globalLoopStarted then
		return
	end
	self._globalLoopStarted = true
	task.spawn(function()
		while self._globalLoopStarted do
			self:PublishGlobalTop100()
			task.wait(GLOBAL_TOP_100_REFRESH_SECONDS)
		end
	end)
end

function LeaderboardService:_getTotalPoints(player: Player): number
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local totalPoints = nil
	if playerDataService and typeof(playerDataService.GetProgressPoints) == "function" then
		totalPoints = playerDataService:GetProgressPoints(player)
	end
	local points = totalPoints or safeNumber(state and state.RankPoints, 0)
	return math.floor(points)
end

function LeaderboardService:_getRoundPoints(player: Player): number
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if playerDataService and typeof(playerDataService.GetRoundProgressPoints) == "function" then
		return math.floor(playerDataService:GetRoundProgressPoints(player))
	end
	return self:_getTotalPoints(player)
end

function LeaderboardService:_getSortedPlayers(): { Player }
	local players = Players:GetPlayers()
	table.sort(players, function(a: Player, b: Player)
		local aPoints = self:_getRoundPoints(a)
		local bPoints = self:_getRoundPoints(b)
		if aPoints ~= bPoints then
			return aPoints > bPoints
		end

		local stateService = getPlayerStateService(self)
		local aState = stateService and stateService:GetState(a) or nil
		local bState = stateService and stateService:GetState(b) or nil
		local aLevel = safeNumber(aState and aState.Level, 0)
		local bLevel = safeNumber(bState and bState.Level, 0)
		if aLevel == bLevel then
			return a.UserId < b.UserId
		end
		return aLevel > bLevel
	end)
	return players
end

function LeaderboardService:_syncPlayer(player: Player)
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	local leaderstats = ensureLeaderstats(player)
	local levelValue = ensureIntValue(leaderstats, "Level")
	local rankValue = ensureIntValue(leaderstats, "Rank")
	local pointsValue = ensureIntValue(leaderstats, "Points")
	levelValue.Value = math.floor(safeNumber(state and state.Level, 0))
	pointsValue.Value = self:_getRoundPoints(player)
	rankValue.Value = self._cachedRanks[player] or 0
end

function LeaderboardService:_recomputeRanks()
	local sorted = self:_getSortedPlayers()
	local previousPoints = nil
	local currentRank = 0
	for index, player in ipairs(sorted) do
		local points = self:_getRoundPoints(player)
		if previousPoints == nil or points ~= previousPoints then
			currentRank = index
			previousPoints = points
		end
		self._cachedRanks[player] = currentRank
		self:_syncPlayer(player)
	end
end

function LeaderboardService:_buildRow(player: Player, rank: number)
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	local activePlayerMode = tostring((state and state.ActivePlayerMode) or GameStates.PlayerMode.Human)
	return {
		UserId = player.UserId,
		Rank = rank,
		Name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		Level = math.floor(safeNumber(state and state.Level, 0)),
		Points = self:_getRoundPoints(player),
		Kills = math.floor(safeNumber(self._kills[player.UserId], 0)),
		Deaths = math.floor(safeNumber(self._deaths[player.UserId], 0)),
		State = activePlayerMode,
	}
end

function LeaderboardService:GetTopPlayers(limit: number?): { any }
	local rows = {}
	local maxRows = math.max(1, math.min(limit or TOP_SCOREBOARD_LIMIT, TOP_SCOREBOARD_LIMIT))
	for index, player in ipairs(self:_getSortedPlayers()) do
		if index > maxRows then
			break
		end
		table.insert(rows, self:_buildRow(player, self._cachedRanks[player] or index))
	end
	return rows
end

function LeaderboardService:ResetForNewRound()
	table.clear(self._kills)
	table.clear(self._deaths)
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if playerDataService and typeof(playerDataService.ResetRoundProgressPoints) == "function" then
		for _, player in ipairs(Players:GetPlayers()) do
			playerDataService:ResetRoundProgressPoints(player)
		end
	end
	self:_recomputeRanks()
	self:PublishScoreboard()
end

function LeaderboardService:PublishScoreboard()
	if not self._scoreboardRemote then
		return
	end
	self._scoreboardRemote:FireAllClients({ Rows = self:GetTopPlayers(TOP_SCOREBOARD_LIMIT), Limit = TOP_SCOREBOARD_LIMIT })
end

function LeaderboardService:GetGlobalTop100(): { any }
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local provider = playerDataService and typeof(playerDataService.GetProvider) == "function" and playerDataService:GetProvider() or nil
	if provider and typeof(provider.GetTopProgressPointProfiles) == "function" then
		return provider:GetTopProgressPointProfiles(TOP_SCOREBOARD_LIMIT)
	end
	return {}
end

function LeaderboardService:PublishGlobalTop100()
	if not self._globalTop100Remote then
		return
	end
	self._globalTop100Remote:FireAllClients({
		Rows = self:GetGlobalTop100(),
		Limit = TOP_SCOREBOARD_LIMIT,
		GeneratedAt = os.time(),
	})
end

function LeaderboardService:GetPlayerRank(player: Player): number?
	return self._cachedRanks[player]
end

return LeaderboardService
