--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type Context = { EventBus: any, Services: any, ServiceRegistry: any? }

local ProgressPointService = {}
ProgressPointService.__index = ProgressPointService


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
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not playerDataService then
		warn("[ProgressPointService] PlayerDataService unavailable; progress points skipped.")
		return
	end
	playerDataService:AddRoundProgressPoints(player, amount)
end

function ProgressPointService:_grantDiamonds(player: Player, amount: number, reason: string)
	local safeAmount = math.max(0, math.floor(amount))
	if safeAmount <= 0 then
		return
	end
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not playerDataService or typeof(playerDataService.GrantReward) ~= "function" then
		warn("[ProgressPointService] PlayerDataService unavailable; Diamond reward skipped.")
		return
	end
	playerDataService:GrantReward(player, { Diamonds = safeAmount }, reason)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
		stateService:RecalculateDerivedStats(player, false)
	end
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
	local diamondReward = math.floor(((killSettings.DiamondReward or 0) * multiplier) + 0.5)
	self:_grantDiamonds(killer, diamondReward, "PlayerKill")
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
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not playerDataService then
		warn("[ProgressPointService] PlayerDataService unavailable; end-round rewards skipped.")
		return {}
	end
	if not stateService then
		warn("[ProgressPointService] PlayerStateService unavailable; participant rewards skipped.")
		return {}
	end

	-- GetTopPlayers includes every server player. Only players still in the Arena
	-- participate in this round's placement and Diamond payout.
	local participantRows = {}
	for _, row in ipairs(topPlayers) do
		if type(row) == "table" and typeof(row.UserId) == "number" then
			local player = Players:GetPlayerByUserId(row.UserId)
			local state = player and stateService:GetState(player) or nil
			if player and state and state.LocationState ~= GameStates.SessionState.Lobby then
				table.insert(participantRows, { Row = row, Player = player })
			end
		end
	end

	local rows = {}
	local previousPoints: number? = nil
	local participantRank = 0
	local diamondSettings = RankConfig.RoundDiamondRewards or {}
	local rankBonuses = diamondSettings.RankBonuses or {}
	for index, participant in ipairs(participantRows) do
		local row = participant.Row
		local player = participant.Player
		local roundPoints = math.max(0, math.floor(tonumber(row.Points or row.RoundPoints) or 0))
		if previousPoints == nil or roundPoints ~= previousPoints then
			participantRank = index
			previousPoints = roundPoints
		end

		local reward = getRewardForRank(participantRank)
		local progressReward = math.max(0, math.floor(reward.ProgressPoints or 0))
		local coinReward = math.max(0, math.floor(reward.Coins or 0))
		local totalProgressAward = roundPoints + progressReward
		local participationDiamondReward = math.max(0, math.floor(diamondSettings.Participation or 0))
		local scoreDiamondReward = math.min(
			math.max(0, math.floor(roundPoints * math.max(0, tonumber(diamondSettings.ScorePerPoint) or 0))),
			math.max(0, math.floor(tonumber(diamondSettings.MaxScoreBonus) or 0))
		)
		local rankDiamondReward = math.max(0, math.floor(
			tonumber(rankBonuses[participantRank]) or tonumber(diamondSettings.DefaultRankBonus) or 0
		))
		local totalDiamondReward = participationDiamondReward + scoreDiamondReward + rankDiamondReward

		playerDataService:AddProgressPoints(player, totalProgressAward)
		if coinReward > 0 and typeof(playerDataService.AddCoins) == "function" then
			playerDataService:AddCoins(player, coinReward)
		end
		self:_grantDiamonds(player, totalDiamondReward, "RoundReward")

		local summaryRow = table.clone(row)
		summaryRow.Rank = participantRank
		summaryRow.Reward = totalProgressAward
		summaryRow.RoundPointReward = roundPoints
		summaryRow.RankBonusReward = progressReward
		summaryRow.ProgressPointReward = totalProgressAward
		summaryRow.CoinReward = coinReward
		summaryRow.ParticipationDiamondReward = participationDiamondReward
		summaryRow.ScoreDiamondReward = scoreDiamondReward
		summaryRow.RankDiamondReward = rankDiamondReward
		summaryRow.DiamondReward = totalDiamondReward
		table.insert(rows, summaryRow)
	end
	return rows
end

function ProgressPointService:GetProgressPoints(player: Player): (number, number)
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not playerDataService then
		return 0, 0
	end
	return playerDataService:GetProgressPoints(player)
end

return ProgressPointService
