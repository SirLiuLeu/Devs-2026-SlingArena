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
	self._participants = {}
	self._matchStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent
	self._roundResultRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.RoundResult) :: RemoteEvent
	self._uiStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
	self._joinRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
	self._leaveRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
	return self
end

function RoundService:Init()
	if self._joinRemote then
		self._joinRemote.OnServerEvent:Connect(function(player) self:JoinArena(player) end)
	end
	if self._leaveRemote then
		self._leaveRemote.OnServerEvent:Connect(function(player) self:LeaveArena(player) end)
	end
	self._context.EventBus:On("LobbyGateTouched", function(player: Player)
		self:JoinArena(player)
	end)
	self._context.EventBus:On("PlayerDied", function() self:_checkRoundEnd() end)
	self._context.EventBus:On("ExitZoneTouched", function(player: Player, zone: BasePart)
		local score = zone:GetAttribute("ScoreValue")
		if typeof(score) == "number" and score > 0 then
			self._context.Services.PlayerStateService:GrantExp(player, score)
		end
		if zone:GetAttribute("EndsRound") == true and self._state == STATES.ActiveRound then
			self:SetState(STATES.RoundEnd)
			if self._roundResultRemote then self._roundResultRemote:FireAllClients({ Winner = player.Name, RoundId = self._roundId }) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) self._participants[player] = nil end)

	self._context.Services.MapService:ActivateMap("LobbyMap")
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

function RoundService:IsPlayingState(): boolean
	return self._state == STATES.ActiveRound
end

function RoundService:IsPlayerQueued(player: Player): boolean
	return self._participants[player] == true
end

function RoundService:GetState()
	return self._state
end

function RoundService:JoinArena(player: Player)
	print(string.format("[MapService] JoinArena requested by %s", player.Name))
	self._participants[player] = true
	if self._context.Services.MapService:GetActiveMap() ~= "ArenaMap" and self._state == STATES.Lobby then
		self._context.Services.MapService:ActivateMap("ArenaMap")
	end

	local pawn = self._context.Services.PlayerService:GetPawn(player)
	if not pawn then
		pawn = self._context.Services.PlayerService:SpawnPawn(player, nil, "ArenaMap")
	end

	local arenaSpawn = self._context.Services.MapService:GetArenaSpawn()
	if arenaSpawn then
		print(string.format("[MapService] Spawn found: %s", arenaSpawn:GetFullName()))
		print(string.format("[MapService] Teleporting player: %s", player.Name))
		local teleported = self._context.Services.PlayerService:TeleportCharacterToSpawn(player, arenaSpawn)
		if not teleported then
			warn(string.format("[MapService] Teleport failed during JoinArena for %s", player.Name))
		end
	else
		warn(string.format("[MapService] Spawn point detection failed for JoinArena player=%s", player.Name))
	end

	self._context.Services.PlayerStateService:SetMapName(player, "ArenaMap")
	self._context.Services.PlayerStateService:SetArenaStatus(player, "InArena")
	self._context.Services.PlayerStateService:SetTeleporting(player, false)
	self:_publishUiState()
end

function RoundService:LeaveArena(player: Player)
	if not self._participants[player] then
		warn(string.format("[MapService] LeaveArena ignored because player is not participating: %s", player.Name))
		return
	end
	print(string.format("[MapService] LeaveArena requested by %s", player.Name))

	self._participants[player] = nil
	if self:_participantCount() == 0 then
		self._context.Services.MapService:ActivateMap("LobbyMap")
	end

	local lobbySpawn = self._context.Services.MapService:GetLobbySpawn()
	if lobbySpawn then
		print(string.format("[MapService] Spawn found: %s", lobbySpawn:GetFullName()))
		print(string.format("[MapService] Teleporting player to lobby: %s", player.Name))
		local teleported = self._context.Services.PlayerService:TeleportCharacterToSpawn(player, lobbySpawn)
		if not teleported then
			warn(string.format("[MapService] LeaveArena teleport failed for %s", player.Name))
			self._context.Services.PlayerService:SpawnPawn(player, 1, "LobbyMap")
		end
	else
		warn("[MapService] Lobby spawn missing during LeaveArena; respawning pawn in LobbyMap")
		self._context.Services.PlayerService:SpawnPawn(player, 1, "LobbyMap")
	end

	self._context.Services.PlayerStateService:SetMapName(player, "LobbyMap")
	self._context.Services.PlayerStateService:SetArenaStatus(player, "Lobby")
	self._context.Services.PlayerStateService:SetTeleporting(player, false)
	self:_publishUiState()
end

function RoundService:SetState(nextState: string)
	if self._state == nextState then return end
	self._state = nextState
	for player in pairs(self._participants) do
		if player.Parent == Players then
			self._context.Services.PlayerStateService:SetArenaStatus(player, nextState)
		end
	end
	if self._matchStateRemote then
		self._matchStateRemote:FireAllClients({ State = nextState, RoundId = self._roundId })
	end
end

function RoundService:RunRound()
	if self:_participantCount() <= 0 then
		self._context.Services.MapService:ActivateMap("LobbyMap")
		self:SetState(STATES.Lobby)
		self:_publishUiState()
		return
	end
	if not self:_ensureParticipantsHavePawns() then
		self:SetState(STATES.Lobby)
		self:_publishUiState()
		return
	end

	self._roundId += 1
	self:SetState(STATES.PreRound)
	self._context.Services.MapService:ActivateMap("ArenaMap")
	self:_resetPlayersForRound()
	self:SetState(STATES.Countdown)
	task.wait(2)
	self:SetState(STATES.ActiveRound)
	self._mapEndTime = os.clock() + self._context.Services.MapService:GetMapDuration()

	while self._state == STATES.ActiveRound do
		self:_checkRoundEnd()
		self:_publishUiState()
		task.wait(0.25)
	end

	self:SetState(STATES.PostRound)
	self._context.Services.MapService:ActivateMap("LobbyMap")
	for player in pairs(self._participants) do
		if player.Parent == Players then
			self._context.Services.PlayerService:SpawnPawn(player, 1, "LobbyMap")
		end
	end
end

function RoundService:_ensureParticipantsHavePawns(): boolean
	for player in pairs(self._participants) do
		if player.Parent == Players then
			local pawn = self._context.Services.PlayerService:GetPawn(player)
			if not pawn then
				pawn = self._context.Services.PlayerService:SpawnPawn(player, nil, "ArenaMap")
			end
			if not pawn then
				return false
			end
		end
	end
	return true
end

function RoundService:_participantCount(): number
	local c = 0
	for player in pairs(self._participants) do
		if player.Parent == Players then c += 1 end
	end
	return c
end

function RoundService:_resetPlayersForRound()
	local i = 1
	for player in pairs(self._participants) do
		if player.Parent == Players then
			self._context.Services.PlayerStateService:ResetForNewRound(player)
			self._context.Services.PlayerService:SpawnPawn(player, i, "ArenaMap")
			local arenaSpawn = self._context.Services.MapService:GetArenaSpawn()
			if arenaSpawn then
				print(string.format("[MapService] Spawn found: %s", arenaSpawn:GetFullName()))
				print(string.format("[MapService] Teleporting player: %s", player.Name))
				local teleported = self._context.Services.PlayerService:TeleportCharacterToSpawn(player, arenaSpawn)
				if not teleported then
					warn(string.format("[MapService] Round start teleport failed for %s", player.Name))
				end
			else
				warn(string.format("[MapService] Round start spawn missing for %s", player.Name))
			end
			i += 1
		end
	end
end

function RoundService:_aliveParticipants(): { Player }
	local alive = {}
	for player in pairs(self._participants) do
		if player.Parent == Players and self._context.Services.PlayerService:IsAlive(player) then
			table.insert(alive, player)
		end
	end
	return alive
end

function RoundService:_checkRoundEnd()
	if self._state ~= STATES.ActiveRound then return end
	if os.clock() >= self._mapEndTime then
		self:SetState(STATES.RoundEnd)
		self:_finishByTimeout()
		task.wait(3)
		return
	end
	local alive = self:_aliveParticipants()
	if #alive == 0 then
		self:SetState(STATES.RoundEnd)
		if self._roundResultRemote then self._roundResultRemote:FireAllClients({ Winner = "No Winner", RoundId = self._roundId }) end
		task.wait(3)
		return
	end
	if self:_participantCount() > 1 and #alive == 1 then
		self:SetState(STATES.RoundEnd)
		if self._roundResultRemote then self._roundResultRemote:FireAllClients({ Winner = alive[1].Name, RoundId = self._roundId }) end
		task.wait(3)
	end
end

function RoundService:_finishByTimeout()
	local bestPlayer = nil
	local bestDamage = -1
	for player in pairs(self._participants) do
		local dealt = self._context.Services.PlayerStateService:GetDamageDealt(player)
		if dealt > bestDamage then
			bestDamage = dealt
			bestPlayer = player
		end
	end
	local winnerName = bestPlayer and bestPlayer.Name or "Time Limit"
	if self._roundResultRemote then
		self._roundResultRemote:FireAllClients({ Winner = winnerName, RoundId = self._roundId })
	end
end

function RoundService:_publishUiState()
	if not self._uiStateRemote then return end
	local alive = self:_aliveParticipants()
	local timeLeft = math.max(0, self._mapEndTime - os.clock())
	self._uiStateRemote:FireAllClients({
		State = self._state,
		ArenaStatus = self._state,
		AlivePlayers = #alive,
		PlayerCount = self:_participantCount(),
		MapName = self._context.Services.MapService:GetActiveMap() or "Unknown",
		TimeLeft = timeLeft,
		CountdownTimer = timeLeft,
	})
end

return RoundService
