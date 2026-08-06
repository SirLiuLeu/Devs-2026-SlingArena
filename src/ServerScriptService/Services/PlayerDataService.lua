--!strict

local Players = game:GetService("Players")

local MockProvider = require(script.Parent.DataProviders.MockProvider)

type Context = { EventBus: any?, Services: any?, ServiceRegistry: any? }

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local function currentMondayStamp(now: number): number
	local date = os.date("!*t", now)
	local daysSinceMonday = (date.wday + 5) % 7
	date.hour = 0; date.min = 0; date.sec = 0
	return os.time(date) - (daysSinceMonday * 24 * 60 * 60)
end

function PlayerDataService.new(context: Context, provider: any?)
	local self = setmetatable({}, PlayerDataService)
	self._context = context
	self._provider = provider or MockProvider.new()
	return self
end

function PlayerDataService:BuildDefaultData(player: Player): { [string]: any }
	return {
		UserId = player.UserId,
		ProgressPoints = {
			TotalPoints = 0,
			WeeklyPoints = 0,
			WeeklyResetAt = currentMondayStamp(os.time()),
		},
	}
end

function PlayerDataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:LoadPlayer(player)
	end
end

function PlayerDataService:LoadPlayer(player: Player): { [string]: any }
	local data = self._provider:LoadPlayerData(player, self:BuildDefaultData(player))
	self:_ensureProgress(data)
	return data
end

function PlayerDataService:GetData(player: Player): { [string]: any }
	return self._provider:GetPlayerData(player) or self:LoadPlayer(player)
end

function PlayerDataService:SavePlayer(player: Player): boolean
	local data = self._provider:GetPlayerData(player)
	return data ~= nil and self._provider:SavePlayerData(player, data) or false
end

function PlayerDataService:UpdateData(player: Player, updater: ({ [string]: any }) -> { [string]: any }?): { [string]: any }
	if self._provider:GetPlayerData(player) == nil then
		self:LoadPlayer(player)
	end
	return self._provider:UpdatePlayerData(player, updater) or self:GetData(player)
end

function PlayerDataService:_ensureProgress(data: { [string]: any })
	local progress = data.ProgressPoints
	if type(progress) ~= "table" then
		progress = {}
		data.ProgressPoints = progress
	end
	progress.TotalPoints = tonumber(progress.TotalPoints) or 0
	progress.WeeklyPoints = tonumber(progress.WeeklyPoints) or 0
	progress.WeeklyResetAt = tonumber(progress.WeeklyResetAt) or currentMondayStamp(os.time())
	local monday = currentMondayStamp(os.time())
	if progress.WeeklyResetAt < monday then
		progress.WeeklyPoints = 0
		progress.WeeklyResetAt = monday
	end
end

function PlayerDataService:AddProgressPoints(player: Player, amount: number): (number, number)
	local add = math.max(0, math.floor(amount))
	local updated = self:UpdateData(player, function(data)
		self:_ensureProgress(data)
		local progress = data.ProgressPoints
		progress.TotalPoints += add
		progress.WeeklyPoints += add
		return data
	end)
	local progress = updated.ProgressPoints
	if self._context.EventBus then
		self._context.EventBus:Fire("ProgressPointsChanged", player, progress.TotalPoints, progress.WeeklyPoints)
	end
	return progress.TotalPoints, progress.WeeklyPoints
end

function PlayerDataService:GetProgressPoints(player: Player): (number, number)
	local data = self:GetData(player)
	self:_ensureProgress(data)
	return data.ProgressPoints.TotalPoints, data.ProgressPoints.WeeklyPoints
end

return PlayerDataService
