--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)

export type RankSession = {
	PlayerId: number,
	StartedAt: number,
	MatchStartedAt: number,
	JoinElapsedSeconds: number,
	TotalMatchPoints: number,
	CommonFoodPoints: number,
	KillWindows: { [number]: { WindowStartedAt: number, Count: number } },
}

type Context = {
	EventBus: any,
	Services: any,
	ServiceRegistry: any?,
}

local RankService = {}
RankService.__index = RankService

function RankService.new(context: Context)
	local self = setmetatable({}, RankService)
	self._context = context
	self._sessions = {} :: { [number]: RankSession }
	self._rankPoints = {} :: { [number]: number }
	return self
end

local function getPlayerId(playerOrId: Player | number): number
	if typeof(playerOrId) == "Instance" then
		return (playerOrId :: Player).UserId
	end

	return playerOrId :: number
end

local function getService(context: Context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end

	return context.Services and context.Services[name]
end

function RankService:Init()
	Players.PlayerAdded:Connect(function(player: Player)
		self:_syncRankPointsFromState(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:SettlePlayerSession(player.UserId)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_syncRankPointsFromState(player)
	end

	if self._context.EventBus then
		self._context.EventBus:On("FoodConsumed", function(player: Player, _expAmount: number, isPremium: boolean?)
			self:OnEatFood(player, isPremium == true)
		end)

		self._context.EventBus:On("PlayerKilled", function(killer: Player, victim: Player)
			self:OnKillPlayer(killer.UserId, victim.UserId)
		end)

		self._context.EventBus:On("PlayerDied", function(player: Player)
			self:SettlePlayerSession(player.UserId)
		end)
	end
end

function RankService:BeginPlayerSession(player: Player, matchElapsedSeconds: number?)
	local playerId = player.UserId
	local now = os.clock()
	self:_syncRankPointsFromState(player)
	self._sessions[playerId] = {
		PlayerId = playerId,
		StartedAt = now,
		MatchStartedAt = now - math.max(matchElapsedSeconds or 0, 0),
		JoinElapsedSeconds = math.max(matchElapsedSeconds or 0, 0),
		TotalMatchPoints = 0,
		CommonFoodPoints = 0,
		KillWindows = {},
	}
end

function RankService:GetSession(playerOrId: Player | number): RankSession?
	return self._sessions[getPlayerId(playerOrId)]
end

function RankService:GetRankPoints(playerOrId: Player | number): number
	local playerId = getPlayerId(playerOrId)
	return self._rankPoints[playerId] or 0
end

function RankService:_getOrCreateSession(playerOrId: Player | number): RankSession
	local playerId = getPlayerId(playerOrId)
	local session = self._sessions[playerId]
	if session then
		return session
	end

	local now = os.clock()
	session = {
		PlayerId = playerId,
		StartedAt = now,
		MatchStartedAt = now,
		JoinElapsedSeconds = 0,
		TotalMatchPoints = 0,
		CommonFoodPoints = 0,
		KillWindows = {},
	}
	self._sessions[playerId] = session
	return session
end

function RankService:_syncRankPointsFromState(player: Player)
	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if state and type(state.RankPoints) == "number" then
		self._rankPoints[player.UserId] = state.RankPoints
	else
		self._rankPoints[player.UserId] = self._rankPoints[player.UserId] or 0
	end
end

function RankService:_writeRankPoints(playerId: number, points: number)
	self._rankPoints[playerId] = points

	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return
	end

	local stateService = getService(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if state then
		state.RankPoints = points
		if typeof(stateService.PublishState) == "function" then
			stateService:PublishState(player)
		end
	end
end

function RankService:OnEatFood(player: Player, isPremium: boolean)
	local session = self:_getOrCreateSession(player)
	if isPremium then
		session.TotalMatchPoints += RankConfig.ScoreSettings.PremiumFood.Points or 0
		return
	end

	local commonFood = RankConfig.ScoreSettings.CommonFood
	local points = commonFood.Points or 0
	local maxPerSession = commonFood.MaxPerSession or math.huge
	local addPoints = math.min(points, math.max(maxPerSession - session.CommonFoodPoints, 0))
	session.CommonFoodPoints += addPoints
	session.TotalMatchPoints += addPoints
end

function RankService:OnKillPlayer(attackerId: number, victimId: number)
	if attackerId == victimId then
		return
	end

	local session = self:_getOrCreateSession(attackerId)
	local killSettings = RankConfig.ScoreSettings.KillPlayer
	local now = os.clock()
	local cooldownSeconds = killSettings.CooldownSeconds or 60
	local killWindow = session.KillWindows[victimId]

	if not killWindow or now - killWindow.WindowStartedAt >= cooldownSeconds then
		killWindow = { WindowStartedAt = now, Count = 0 }
		session.KillWindows[victimId] = killWindow
	end

	killWindow.Count += 1

	local multiplier = 0
	if killWindow.Count == 1 then
		multiplier = 1
	elseif killWindow.Count == 2 then
		multiplier = 0.5
	end

	session.TotalMatchPoints += (killSettings.BasePoints or 0) * multiplier
end

function RankService:OnSurvivalTick(currentZoneMultiplier: number)
	local survivalSettings = RankConfig.ScoreSettings.Survival
	local multiplier = math.max(currentZoneMultiplier or 1, 0)
	local points = (survivalSettings.BasePoints or 0) * multiplier

	for _, session in pairs(self._sessions) do
		session.TotalMatchPoints += points
	end
end

function RankService:SettlePlayerSession(playerId: number): number?
	local session = self._sessions[playerId]
	if not session then
		return nil
	end

	local oldRankPoints = self._rankPoints[playerId] or 0
	local baseEntryFee = RankConfig.GetRankForPoints(oldRankPoints).EntryFee
	local discountMultiplier = RankConfig.GetLateJoinDiscountMultiplier(session.JoinElapsedSeconds)
	local actualEntryFee = baseEntryFee * discountMultiplier
	local newRankPoints = math.max(0, math.floor(oldRankPoints + (session.TotalMatchPoints - actualEntryFee)))

	self:_writeRankPoints(playerId, newRankPoints)
	self._sessions[playerId] = nil

	return newRankPoints
end

return RankService
