--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local MatchService = {}
MatchService.__index = MatchService

local STATES = {
	Boot = "Boot",
	Lobby = "Lobby",
	PreRound = "PreRound",
	Countdown = "Countdown",
	ActiveRound = "ActiveRound",
	RoundEnd = "RoundEnd",
	PostRound = "PostRound",
}

function MatchService.new(context)
	local self = setmetatable({}, MatchService)
	self._context = context
	self._state = STATES.Boot
	self._connections = {}
	self._roundId = 0
	self._matchStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent
	self._roundResultRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.RoundResult) :: RemoteEvent
	self._popupRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PopupMessage) :: RemoteEvent
	return self
end

function MatchService:Init()
	table.insert(self._connections, self._context.EventBus:On("PlayerDied", function()
		self:_checkRoundEnd()
	end))
	table.insert(self._connections, self._context.EventBus:On("LevelUp", function(player: Player)
		if self._popupRemote then
			self._popupRemote:FireClient(player, { Type = "LevelUp", Text = "Level Up!" })
		end
	end))
	table.insert(self._connections, self._context.EventBus:On("LevelDown", function(player: Player)
		if self._popupRemote then
			self._popupRemote:FireClient(player, { Type = "LevelDown", Text = "Level Down" })
		end
	end))

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

function MatchService:IsRoundActive(): boolean
	return self._state == STATES.ActiveRound
end

function MatchService:GetState()
	return self._state
end

function MatchService:SetState(nextState: string)
	if self._state == nextState then
		return
	end
	self._state = nextState
	self._context.EventBus:Fire("MatchStateChanged", nextState)
	if self._matchStateRemote then
		self._matchStateRemote:FireAllClients({
			State = nextState,
			RoundId = self._roundId,
		})
	end
end

function MatchService:RunRound()
	self._roundId += 1
	self:SetState(STATES.PreRound)
	self._context.Services.MapService:Generate(os.time())
	self:_resetPlayersForRound()
	self:SetState(STATES.Countdown)
	task.wait(2)
	self:SetState(STATES.ActiveRound)

	while self._state == STATES.ActiveRound do
		self:_checkRoundEnd()
		task.wait(0.25)
	end

	self:SetState(STATES.PostRound)
end

function MatchService:_resetPlayersForRound()
	local players = Players:GetPlayers()
	for i, player in ipairs(players) do
		self._context.Services.PlayerStateService:ResetForNewRound(player)
		self._context.Services.PlayerService:SpawnPawn(player, i)
	end
end

function MatchService:_alivePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if self._context.Services.PlayerService:IsAlive(player) then
			table.insert(list, player)
		end
	end
	return list
end

function MatchService:_checkRoundEnd()
	if self._state ~= STATES.ActiveRound then
		return
	end
	local alive = self:_alivePlayers()
	if #alive <= 1 then
		self:SetState(STATES.RoundEnd)
		local winner = alive[1]
		local winnerName = winner and winner.Name or "No Winner"
		if self._roundResultRemote then
			self._roundResultRemote:FireAllClients({
				Winner = winnerName,
				RoundId = self._roundId,
			})
		end
		task.wait(3)
	end
end

return MatchService
