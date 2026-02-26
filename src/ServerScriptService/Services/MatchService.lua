--!strict

local Players = game:GetService("Players")

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
	return self
end

function MatchService:Init()
	table.insert(self._connections, self._context.EventBus:On("PlayerDied", function()
		self:_checkRoundEnd()
	end))

	self:SetState(STATES.Lobby)
	task.defer(function()
		self:SetState(STATES.PreRound)
		self._context.Services.MapService:Generate(os.time())
		self:SetState(STATES.Countdown)
		task.wait(2)
		self:SetState(STATES.ActiveRound)
	end)
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
end

function MatchService:_checkRoundEnd()
	if self._state ~= STATES.ActiveRound then
		return
	end
	local alive = 0
	for _, player in Players:GetPlayers() do
		if self._context.Services.PlayerService:IsAlive(player) then
			alive += 1
		end
	end
	if alive <= 1 then
		self:SetState(STATES.RoundEnd)
		task.delay(1, function()
			self:SetState(STATES.PostRound)
			self._context.Services.MapService:Generate(os.time())
			self:SetState(STATES.PreRound)
			task.wait(2)
			self:SetState(STATES.ActiveRound)
		end)
	end
end

return MatchService
