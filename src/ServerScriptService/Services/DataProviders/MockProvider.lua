--!strict

local MockProvider = {}
MockProvider.__index = MockProvider


local MOCK_SCHEMA_DEFAULTS = {
	Level = 1,
	Coin = 0,
	ProgressPoints = {
		RoundPoints = 0,
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

function MockProvider.new()
	local self = setmetatable({}, MockProvider)
	self._dataByUserId = {} :: { [number]: { [string]: any } }
	return self
end

function MockProvider:LoadPlayerData(player: Player, defaultData: { [string]: any }): { [string]: any }
	local existing = self._dataByUserId[player.UserId]
	if existing == nil then
		existing = deepCopy(defaultData)
		self._dataByUserId[player.UserId] = existing
	end
	applyDefaults(existing, MOCK_SCHEMA_DEFAULTS)
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
	return current
end

function MockProvider:ClearPlayerData(player: Player)
	-- RAM-backed development provider intentionally keeps data for the life of the server.
	-- This avoids losing mock progress when Player instances are recreated in local tests.
	local _ = player
end

return MockProvider
