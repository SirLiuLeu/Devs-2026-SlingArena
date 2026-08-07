--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)

type Context = { EventBus: any, Services: any, ServiceRegistry: any? }

local ProgressPointService = {}
ProgressPointService.__index = ProgressPointService

local function getService(context: Context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

function ProgressPointService.new(context: Context)
	local self = setmetatable({}, ProgressPointService)
	self._context = context
	self._commonFoodPoints = {} :: { [number]: number }
	self._killWindows = {} :: { [number]: { [number]: { WindowStartedAt: number, Count: number } } }
	return self
end

function ProgressPointService:Init()
	Players.PlayerRemoving:Connect(function(player)
		self._commonFoodPoints[player.UserId] = nil
		self._killWindows[player.UserId] = nil
	end)
	if not self._context.EventBus then
		return
	end
	self._context.EventBus:On("FoodConsumed", function(player: Player, _expAmount: number, isPremium: boolean?)
		self:OnFoodConsumed(player, isPremium == true)
	end)
	self._context.EventBus:On("PlayerKilled", function(killer: Player, victim: Player)
		self:OnPlayerKilled(killer, victim)
	end)
end

function ProgressPointService:_addPoints(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local playerDataService = getService(self._context, "PlayerDataService")
	if not playerDataService then
		warn("[ProgressPointService] PlayerDataService unavailable; progress points skipped.")
		return
	end
	playerDataService:AddRoundProgressPoints(player, amount)
end

function ProgressPointService:OnFoodConsumed(player: Player, isPremium: boolean)
	if isPremium then
		self:_addPoints(player, RankConfig.ScoreSettings.PremiumFood.Points or 0)
		return
	end
	local commonFood = RankConfig.ScoreSettings.CommonFood
	local earned = self._commonFoodPoints[player.UserId] or 0
	local maxPerSession = commonFood.MaxPerSession or math.huge
	local addPoints = math.min(commonFood.Points or 0, math.max(maxPerSession - earned, 0))
	self._commonFoodPoints[player.UserId] = earned + addPoints
	self:_addPoints(player, addPoints)
end

function ProgressPointService:OnPlayerKilled(killer: Player, victim: Player)
	if killer.UserId == victim.UserId then
		return
	end
	local killSettings = RankConfig.ScoreSettings.KillPlayer
	local windows = self._killWindows[killer.UserId]
	if not windows then
		windows = {}
		self._killWindows[killer.UserId] = windows
	end
	local now = os.clock()
	local victimWindow = windows[victim.UserId]
	local cooldownSeconds = killSettings.CooldownSeconds or 60
	if not victimWindow or now - victimWindow.WindowStartedAt >= cooldownSeconds then
		victimWindow = { WindowStartedAt = now, Count = 0 }
		windows[victim.UserId] = victimWindow
	end
	victimWindow.Count += 1
	local multiplier = if victimWindow.Count == 1 then 1 elseif victimWindow.Count == 2 then 0.5 else 0
	self:_addPoints(killer, (killSettings.BasePoints or 0) * multiplier)
end

local END_ROUND_REWARDS = {
	[1] = { ProgressPoints = 100, Coins = 50 },
	[2] = { ProgressPoints = 75, Coins = 35 },
	[3] = { ProgressPoints = 50, Coins = 25 },
}
local DEFAULT_END_ROUND_REWARD = { ProgressPoints = 25, Coins = 10 }

local function getRewardForRank(rank: number): { ProgressPoints: number, Coins: number }
	return END_ROUND_REWARDS[rank] or DEFAULT_END_ROUND_REWARD
end

function ProgressPointService:AwardEndRoundPoints(topPlayers: { any }): { any }
	local playerDataService = getService(self._context, "PlayerDataService")
	if not playerDataService then
		warn("[ProgressPointService] PlayerDataService unavailable; end-round rewards skipped.")
		return {}
	end

	local rows = {}
	for index, row in ipairs(topPlayers) do
		if type(row) == "table" then
			local rank = math.max(1, math.floor(tonumber(row.Rank) or index))
			local reward = getRewardForRank(rank)
			local progressReward = math.max(0, math.floor(reward.ProgressPoints or 0))
			local coinReward = math.max(0, math.floor(reward.Coins or 0))
			local player = if typeof(row.UserId) == "number" then Players:GetPlayerByUserId(row.UserId) else nil
			if player then
				playerDataService:AddProgressPoints(player, progressReward)
				if coinReward > 0 and typeof(playerDataService.AddCoins) == "function" then
					playerDataService:AddCoins(player, coinReward)
				end
			end
			local summaryRow = table.clone(row)
			summaryRow.Reward = progressReward
			summaryRow.ProgressPointReward = progressReward
			summaryRow.CoinReward = coinReward
			table.insert(rows, summaryRow)
		end
	end
	return rows
end

function ProgressPointService:GetProgressPoints(player: Player): (number, number)
	local playerDataService = getService(self._context, "PlayerDataService")
	if not playerDataService then
		return 0, 0
	end
	return playerDataService:GetProgressPoints(player)
end

return ProgressPointService
