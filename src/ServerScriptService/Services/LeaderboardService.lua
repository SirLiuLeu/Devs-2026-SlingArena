--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)

local TOP_SCOREBOARD_LIMIT = 100

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

function LeaderboardService.new(context)
	local self = setmetatable({}, LeaderboardService)
	self._context = context
	self._cachedRanks = {}
	self._kills = {} :: { [number]: number }
	self._deaths = {} :: { [number]: number }
	self._scoreboardRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchScoreboardUpdate) :: RemoteEvent?
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
	return self._context.Services and self._context.Services.PlayerStateService
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
end

function LeaderboardService:_getPoints(player: Player): number
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	local playerDataService = self._context.Services and self._context.Services.PlayerDataService
	local totalPoints = nil
	if playerDataService and typeof(playerDataService.GetProgressPoints) == "function" then
		totalPoints = playerDataService:GetProgressPoints(player)
	end
	local points = totalPoints or safeNumber(state and state.RankPoints, 0)
	return math.floor(points)
end

function LeaderboardService:_getSortedPlayers(): { Player }
	local players = Players:GetPlayers()
	table.sort(players, function(a: Player, b: Player)
		local aPoints = self:_getPoints(a)
		local bPoints = self:_getPoints(b)
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
	pointsValue.Value = self:_getPoints(player)
	rankValue.Value = self._cachedRanks[player] or 0
end

function LeaderboardService:_recomputeRanks()
	local sorted = self:_getSortedPlayers()
	for index, player in ipairs(sorted) do
		self._cachedRanks[player] = index
		self:_syncPlayer(player)
	end
end

function LeaderboardService:_buildRow(player: Player, rank: number)
	local stateService = getPlayerStateService(self)
	local state = stateService and stateService:GetState(player) or nil
	local isAlive = if state and state.IsAlive ~= nil then state.IsAlive else true
	local movementState = if not isAlive then GameStates.PlayerState.Dead else tostring((state and state.MovementState) or GameStates.PlayerState.Idle)
	return {
		UserId = player.UserId,
		Rank = rank,
		Name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		Level = math.floor(safeNumber(state and state.Level, 0)),
		Points = self:_getPoints(player),
		Kills = math.floor(safeNumber(self._kills[player.UserId], 0)),
		Deaths = math.floor(safeNumber(self._deaths[player.UserId], 0)),
		State = movementState,
	}
end

function LeaderboardService:GetTopPlayers(limit: number?): { any }
	local rows = {}
	local maxRows = math.max(1, math.min(limit or TOP_SCOREBOARD_LIMIT, TOP_SCOREBOARD_LIMIT))
	for rank, player in ipairs(self:_getSortedPlayers()) do
		if rank > maxRows then
			break
		end
		table.insert(rows, self:_buildRow(player, rank))
	end
	return rows
end

function LeaderboardService:PublishScoreboard()
	if not self._scoreboardRemote then
		return
	end
	self._scoreboardRemote:FireAllClients({ Rows = self:GetTopPlayers(TOP_SCOREBOARD_LIMIT), Limit = TOP_SCOREBOARD_LIMIT })
end

function LeaderboardService:GetPlayerRank(player: Player): number?
	return self._cachedRanks[player]
end

return LeaderboardService
