--!strict

local MockProvider = {}
MockProvider.__index = MockProvider

local SEEDED_PROFILE_COUNT = 125
local MOCK_USER_ID_START = -900000
local RNG_SEED = 20260809

local MOCK_SCHEMA_DEFAULTS = {
	Level = 1,
	Coin = 0,
	ProgressPoints = {
		TotalPoints = 0,
		RoundPoints = 0,
		WeeklyPoints = 0,
	},
}

local function applyDefaults(target: { [any]: any }, defaults: { [any]: any })
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			applyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
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

local function normalizeProgress(data: { [string]: any })
	applyDefaults(data, MOCK_SCHEMA_DEFAULTS)
	local progress = data.ProgressPoints
	progress.TotalPoints = math.max(0, math.floor(tonumber(progress.TotalPoints) or 0))
	progress.RoundPoints = math.max(0, math.floor(tonumber(progress.RoundPoints) or 0))
	progress.WeeklyPoints = math.max(0, math.floor(tonumber(progress.WeeklyPoints) or 0))
end

function MockProvider.new()
	local self = setmetatable({}, MockProvider)
	self._dataByUserId = {} :: { [number]: { [string]: any } }
	self:_seedLeaderboardProfiles()
	return self
end

function MockProvider:_seedLeaderboardProfiles()
	local rng = Random.new(RNG_SEED)
	for index = 1, SEEDED_PROFILE_COUNT do
		local userId = MOCK_USER_ID_START - index
		local totalPoints = rng:NextInteger(50, 25000)
		local weeklyPoints = math.max(0, totalPoints - rng:NextInteger(0, 5000))
		self._dataByUserId[userId] = {
			UserId = userId,
			Name = string.format("MockChampion%03d", index),
			DisplayName = string.format("Mock Champion %03d", index),
			Level = rng:NextInteger(1, 75),
			Coin = rng:NextInteger(0, 5000),
			ProgressPoints = {
				TotalPoints = totalPoints,
				RoundPoints = 0,
				WeeklyPoints = weeklyPoints,
			},
			IsMockLeaderboardSeed = true,
		}
	end
end

function MockProvider:LoadPlayerData(player: Player, defaultData: { [string]: any }): { [string]: any }
	local existing = self._dataByUserId[player.UserId]
	if existing == nil then
		existing = deepCopy(defaultData)
		self._dataByUserId[player.UserId] = existing
	end
	normalizeProgress(existing)
	existing.UserId = player.UserId
	existing.Name = player.Name
	existing.DisplayName = player.DisplayName ~= "" and player.DisplayName or player.Name
	return existing
end

function MockProvider:SavePlayerData(player: Player, data: { [string]: any }): boolean
	self._dataByUserId[player.UserId] = data
	return true
end

function MockProvider:GetPlayerData(player: Player): { [string]: any }?
	return self._dataByUserId[player.UserId]
end

function MockProvider:UpdatePlayerData(player: Player, updater: ({ [string]: any }) -> { [string]: any }?): { [string]: any }?
	local current = self._dataByUserId[player.UserId]
	if current == nil then
		return nil
	end
	local updated = updater(current)
	if updated ~= nil then
		self._dataByUserId[player.UserId] = updated
		current = updated
	end
	normalizeProgress(current)
	return current
end

function MockProvider:GetTopProgressPointProfiles(limit: number): { any }
	local rows = {}
	for userId, data in pairs(self._dataByUserId) do
		normalizeProgress(data)
		local progress = data.ProgressPoints
		table.insert(rows, {
			UserId = userId,
			Name = tostring(data.DisplayName or data.Name or ("Player " .. tostring(userId))),
			Level = math.max(1, math.floor(tonumber(data.Level) or 1)),
			ProgressPoints = progress.TotalPoints,
			WeeklyPoints = progress.WeeklyPoints,
			IsMock = data.IsMockLeaderboardSeed == true,
		})
	end
	table.sort(rows, function(a, b)
		if a.ProgressPoints ~= b.ProgressPoints then
			return a.ProgressPoints > b.ProgressPoints
		end
		return a.UserId < b.UserId
	end)
	local maxRows = math.max(1, math.floor(limit))
	local ranked = {}
	local previousPoints = nil
	local currentRank = 0
	for index, row in ipairs(rows) do
		if index > maxRows then
			break
		end
		if previousPoints == nil or row.ProgressPoints ~= previousPoints then
			currentRank = index
			previousPoints = row.ProgressPoints
		end
		row.Rank = currentRank
		table.insert(ranked, row)
	end
	return ranked
end

function MockProvider:ClearPlayerData(player: Player)
	local _ = player
end

return MockProvider
