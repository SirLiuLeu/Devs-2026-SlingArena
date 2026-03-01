--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local RoundService = {}
RoundService.__index = RoundService

local STATES = {
	Boot = "Boot",
	Lobby = "Lobby",
	PreRound = "PreRound",
	Countdown = "Countdown",
	ActiveRound = "ActiveRound",
	RoundEnd = "RoundEnd",
	PostRound = "PostRound",
}

function RoundService.new(context)
	local self = setmetatable({}, RoundService)
	self._context = context
	self._state = STATES.Boot
	self._roundId = 0
	self._mapEndTime = 0
	self._matchStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent
	self._roundResultRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.RoundResult) :: RemoteEvent
	self._popupRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PopupMessage) :: RemoteEvent
	return self
end

function RoundService:Init()
	self._context.EventBus:On("PlayerDied", function()
		self:_checkRoundEnd()
	end)
	self._context.EventBus:On("LevelUp", function(player: Player)
		if self._popupRemote then
			self._popupRemote:FireClient(player, { Type = "LevelUp", Text = "Level Up!" })
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		if self._matchStateRemote then
			self._matchStateRemote:FireClient(player, {
				State = self._state,
				RoundId = self._roundId,
			})
		end
	end)

	self:SetState(STATES.Lobby)
	task.defer(function()
		while true do
			self:RunRound()
			task.wait(2)
		end
	end)
end

function RoundService:IsRoundActive(): boolean
	return self._state == STATES.ActiveRound
end

function RoundService:SetState(nextState: string)
	if self._state == nextState then
		return
	end
	self._state = nextState
	if self._matchStateRemote then
		self._matchStateRemote:FireAllClients({
			State = nextState,
			RoundId = self._roundId,
		})
	end
end

function RoundService:RunRound()
	self._roundId += 1
	self:SetState(STATES.PreRound)
	self._context.Services.MapService:Generate()
	self:_resetPlayersForRound()
	self:SetState(STATES.Countdown)
	task.wait(2)
	self:SetState(STATES.ActiveRound)
	self._mapEndTime = os.clock() + self._context.Services.MapService:GetMapDuration()

	while self._state == STATES.ActiveRound do
		self:_checkRoundEnd()
		task.wait(0.25)
	end

	self:SetState(STATES.PostRound)
end

function RoundService:_resetPlayersForRound()
	for i, player in ipairs(Players:GetPlayers()) do
		self._context.Services.PlayerStateService:ResetForNewRound(player)
		self._context.Services.PlayerService:SpawnPawn(player, i)
	end
end

function RoundService:_alivePlayers(): { Player }
	local alive = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if self._context.Services.PlayerService:IsAlive(player) then
			table.insert(alive, player)
		end
	end
	return alive
end

function RoundService:_checkRoundEnd()
	if self._state ~= STATES.ActiveRound then
		return
	end
	if os.clock() >= self._mapEndTime then
		self:SetState(STATES.RoundEnd)
		if self._roundResultRemote then
			self._roundResultRemote:FireAllClients({ Winner = "Time Limit", RoundId = self._roundId })
		end
		task.wait(3)
		return
	end

	local alive = self:_alivePlayers()
	if #alive <= 1 then
		self:SetState(STATES.RoundEnd)
		local winner = alive[1]
		local winnerName = winner and winner.Name or "No Winner"
		if self._roundResultRemote then
			self._roundResultRemote:FireAllClients({ Winner = winnerName, RoundId = self._roundId })
		end
		task.wait(3)
	end
end

return RoundService
