--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)
local RoundRewardConfig = require(ReplicatedStorage.Shared.Config.RoundRewardConfig)
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

function ProgressPointService:AwardRoundGiftBoxes(participants: { Player }, winner: Player?): { any }
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local itemService = ServiceResolver.Get(self._context, "ItemService")
	if not playerDataService or not stateService then
		warn("[ProgressPointService] Required data/state service unavailable; round GiftBox rewards skipped.")
		return {}
	end

	local ranked = {}
	local includedPlayers = {}
	for _, player in ipairs(participants) do
		local state = stateService:GetState(player)
		if player.Parent == Players
			and state
			and state.LocationState ~= GameStates.SessionState.Lobby
			and not includedPlayers[player.UserId] then
			includedPlayers[player.UserId] = true
			local points = 0
			if typeof(playerDataService.GetRoundProgressPoints) == "function" then
				points = math.max(0, math.floor(tonumber(playerDataService:GetRoundProgressPoints(player)) or 0))
			end
			table.insert(ranked, {
				Player = player,
				UserId = player.UserId,
				Name = player.DisplayName ~= "" and player.DisplayName or player.Name,
				Level = math.max(0, math.floor(tonumber(state.Level) or 0)),
				Points = points,
			})
		end
	end

	local winnerUserId = if winner and includedPlayers[winner.UserId] then winner.UserId else nil
	table.sort(ranked, function(a, b)
		if a.UserId == b.UserId then
			return false
		end
		if winnerUserId ~= nil then
			if a.UserId == winnerUserId then return true end
			if b.UserId == winnerUserId then return false end
		end
		if a.Points ~= b.Points then return a.Points > b.Points end
		if a.Level ~= b.Level then return a.Level > b.Level end
		return a.UserId < b.UserId
	end)

	local participantCount = #ranked
	local results = {}
	for rank, row in ipairs(ranked) do
		local giftBoxAmount = RoundRewardConfig.GetGiftBoxAmount(participantCount, rank)
		if giftBoxAmount > 0 then
			playerDataService:GrantReward(row.Player, {
				Items = {
					{ Id = "gift_box", Quantity = giftBoxAmount },
				},
			}, "RoundPlacementReward")

			if itemService and typeof(itemService.PublishInventory) == "function" then
				itemService:PublishInventory(row.Player)
			else
				stateService:PublishState(row.Player)
			end

			if self._context.EventBus then
				self._context.EventBus:Fire("RoundPlacementRewardGranted", row.Player, rank, giftBoxAmount)
			end
		end

		table.insert(results, {
			UserId = row.UserId,
			Name = row.Name,
			Rank = rank,
			Points = row.Points,
			Level = row.Level,
			GiftBoxReward = giftBoxAmount,
		})
	end
	return results
end

function ProgressPointService:GetProgressPoints(player: Player): (number, number)
	local playerDataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not playerDataService then
		return 0, 0
	end
	return playerDataService:GetProgressPoints(player)
end

return ProgressPointService
