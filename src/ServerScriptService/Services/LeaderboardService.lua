--!strict

local Players = game:GetService("Players")

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

function LeaderboardService.new(context)
	local self = setmetatable({}, LeaderboardService)
	self._context = context
	self._cachedRanks = {}
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

function LeaderboardService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_syncPlayer(player)
		self:_recomputeRanks()
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._cachedRanks[player] = nil
		self:_recomputeRanks()
	end)
	self._context.EventBus:On("LevelUp", function(player: Player)
		self:_syncPlayer(player)
		self:_recomputeRanks()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_syncPlayer(player)
	end
	self:_recomputeRanks()
end

function LeaderboardService:_getSortedPlayers(): { Player }
	local players = Players:GetPlayers()
	table.sort(players, function(a: Player, b: Player)
		local aState = self._context.Services.PlayerStateService:GetState(a)
		local bState = self._context.Services.PlayerStateService:GetState(b)
		local aLevel = aState and aState.Level or 0
		local bLevel = bState and bState.Level or 0
		if aLevel == bLevel then
			return a.UserId < b.UserId
		end
		return aLevel > bLevel
	end)
	return players
end

function LeaderboardService:_syncPlayer(player: Player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	local leaderstats = ensureLeaderstats(player)
	local levelValue = ensureIntValue(leaderstats, "Level")
	local rankValue = ensureIntValue(leaderstats, "Rank")
	levelValue.Value = math.floor(state and state.Level or 0)
	rankValue.Value = self._cachedRanks[player] or 0
end

function LeaderboardService:_recomputeRanks()
	local sorted = self:_getSortedPlayers()
	for index, player in ipairs(sorted) do
		self._cachedRanks[player] = index
		self:_syncPlayer(player)
	end
end

function LeaderboardService:GetTopPlayers(): { { Player: Player, Level: number, Rank: number } }
	local rows = {}
	for rank, player in ipairs(self:_getSortedPlayers()) do
		local state = self._context.Services.PlayerStateService:GetState(player)
		table.insert(rows, { Player = player, Level = state and state.Level or 0, Rank = rank })
	end
	return rows
end

function LeaderboardService:GetPlayerRank(player: Player): number?
	return self._cachedRanks[player]
end

return LeaderboardService
