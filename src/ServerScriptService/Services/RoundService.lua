--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local RoundService = {}
RoundService.__index = RoundService

local MIN_PLAYERS_TO_START = 3
local REJOIN_COOLDOWN_SECONDS = 15
local ROUND_END_FREEZE_SECONDS = 5
local ROUND_END_RESULTS_SECONDS = 15

function RoundService.new(context)
	local self = setmetatable({}, RoundService)
	self._context = context
	self._state = GameStates.MapRoundState.Lobby
	self._roundActive = false
	self._roundTimer = 0
	self._roundEndElapsed = 0
	self._winnerName = nil :: string?
	self._resultsShown = false
	self._lastLeaveByUserId = {} :: { [number]: number }
	self._frozenRoots = {} :: { [Player]: BasePart }
	self._roundId = 1
	self._matchStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent
	self._uiStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
	self._popupRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PopupMessage) :: RemoteEvent?
	self._roundResultRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.RoundResult) :: RemoteEvent?
	self._joinRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
	self._leaveRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
	self._startSafeZoneRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.StartSafeZone) :: RemoteEvent?
	return self
end

function RoundService:Init()
	if self._joinRemote then
		self._joinRemote.OnServerEvent:Connect(function(player)
			self:JoinArena(player)
		end)
	end
	if self._leaveRemote then
		self._leaveRemote.OnServerEvent:Connect(function(player)
			self:LeaveArena(player)
		end)
	end
	if self._startSafeZoneRemote then
		self._startSafeZoneRemote.OnServerEvent:Connect(function(player)
			self:RequestStartSafeZone(player)
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)

	self:_publishUiState()
end

function RoundService:IsRoundActive(): boolean
	return self._roundActive
end

function RoundService:IsPlayingState(): boolean
	return self._state == GameStates.MapRoundState.EarlyGame or self._state == GameStates.MapRoundState.FinalPhase
end

function RoundService:IsPlayerQueued(player: Player): boolean
	local stateService = self._context.Services.PlayerStateService
	local state = stateService and stateService:GetState(player)
	return state ~= nil and state.LocationState ~= GameStates.SessionState.Lobby
end

function RoundService:GetState()
	return self._state
end

function RoundService:GetRoundElapsed(): number
	return self._roundTimer
end

function RoundService:RequestStartSafeZone(_player: Player)
	if self._state == GameStates.MapRoundState.Awaits then
		self:_startEarlyGame()
	end
end

function RoundService:JoinArena(player: Player)
	if not self:_canJoinArena(player) then
		return
	end
	local arenaMapName = self._context.Services.MapService:GetDefaultArenaMapName()
	self._context.Services.MapService:ActivateMap(arenaMapName)
	self._context.Services.PlayerService:SpawnPawn(player, nil, arenaMapName)
	self._context.Services.PlayerStateService:SetCurrentMap(player, arenaMapName)
	self._context.Services.PlayerStateService:SetLocationState(player, GameStates.SessionState.InGame)
	if self._state == GameStates.MapRoundState.Lobby then
		self:_setState(GameStates.MapRoundState.Awaits)
	end
	self:_publishUiState()
end

function RoundService:LeaveArena(player: Player)
	self._lastLeaveByUserId[player.UserId] = os.clock()
	self._context.Services.PlayerService:SpawnPawn(player, 1, "LobbyMap")
	self._context.Services.PlayerStateService:SetCurrentMap(player, "LobbyMap")
	self._context.Services.PlayerStateService:SetLocationState(player, GameStates.SessionState.Lobby)
	if self:_countArenaPlayers() == 0 and self._state ~= GameStates.MapRoundState.RoundEnd and self._state ~= "PostRound" then
		self:_setState(GameStates.MapRoundState.Lobby)
		self._roundActive = false
		self._roundTimer = 0
	end
	self:_publishUiState()
end

function RoundService:_canJoinArena(player: Player): boolean
	local leaveAt = self._lastLeaveByUserId[player.UserId]
	if not leaveAt then
		return true
	end
	return (os.clock() - leaveAt) >= REJOIN_COOLDOWN_SECONDS
end

function RoundService:_countArenaPlayers(): number
	local stateService = self._context.Services.PlayerStateService
	if not stateService then
		return 0
	end
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local state = stateService:GetState(player)
		if state and state.LocationState ~= GameStates.SessionState.Lobby then
			count += 1
		end
	end
	return count
end

function RoundService:_countAliveArenaPlayers(): number
	local stateService = self._context.Services.PlayerStateService
	if not stateService then
		return 0
	end
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local state = stateService:GetState(player)
		if state and state.LocationState ~= GameStates.SessionState.Lobby and state.IsAlive then
			count += 1
		end
	end
	return count
end

function RoundService:_findLastAlivePlayerName(): string?
	local stateService = self._context.Services.PlayerStateService
	if not stateService then
		return nil
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local state = stateService:GetState(player)
		if state and state.LocationState ~= GameStates.SessionState.Lobby and state.IsAlive then
			return player.Name
		end
	end
	return nil
end

function RoundService:_setState(nextState: string)
	if self._state == nextState then
		return
	end
	self._state = nextState
	local stateService = self._context.Services.PlayerStateService
	if stateService then
		for _, player in ipairs(Players:GetPlayers()) do
			local state = stateService:GetState(player)
			if state and state.LocationState ~= GameStates.SessionState.Lobby then
				stateService:SetLocationState(player, GameStates.SessionState.InGame)
			end
		end
	end
	self:_publishUiState()
end

function RoundService:_startEarlyGame()
	if self._state ~= GameStates.MapRoundState.Awaits then
		return
	end
	self._roundActive = true
	self._roundTimer = 0
	local safeZoneService = self._context.Services.SafeZoneService
	if safeZoneService and typeof(safeZoneService.Reset) == "function" then
		safeZoneService:Reset()
	end
	self:_setState(GameStates.MapRoundState.EarlyGame)
	if self._popupRemote then
		self._popupRemote:FireAllClients("Safe zone is shrinking. EXP gain is now 100%.")
	end
end

function RoundService:_freezeArenaPlayers(frozen: boolean)
	local playerService = self._context.Services.PlayerService
	local stateService = self._context.Services.PlayerStateService
	if not playerService or not stateService then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local state = stateService:GetState(player)
		if state and state.LocationState ~= GameStates.SessionState.Lobby then
			local root = playerService:GetRoot(player)
			if root then
				root.Anchored = frozen
				if frozen then
					self._frozenRoots[player] = root
				else
					self._frozenRoots[player] = nil
				end
			end
		end
	end
end

function RoundService:_beginRoundEnd()
	if self._state == GameStates.MapRoundState.RoundEnd or self._state == "PostRound" then
		return
	end
	self._winnerName = self:_findLastAlivePlayerName() or "No winner"
	self._resultsShown = false
	self._roundActive = false
	self._roundEndElapsed = 0
	self:_setState(GameStates.MapRoundState.RoundEnd)
	self:_freezeArenaPlayers(true)
end

function RoundService:_startPostRound()
	self:_setState("PostRound")
	self:_freezeArenaPlayers(false)

	local stateService = self._context.Services.PlayerStateService
	local mapService = self._context.Services.MapService
	if mapService then
		mapService:ActivateMap("LobbyMap")
	end
	local safeZoneService = self._context.Services.SafeZoneService
	if safeZoneService and typeof(safeZoneService.Reset) == "function" then
		safeZoneService:Reset()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		self._context.Services.PlayerService:SpawnPawn(player, 1, "LobbyMap")
		if stateService then
			stateService:SetCurrentMap(player, "LobbyMap")
			stateService:SetLocationState(player, GameStates.SessionState.Lobby)
		end
	end

	self._roundId += 1
	self._roundTimer = 0
	self._roundEndElapsed = 0
	self._winnerName = nil
	self._resultsShown = false
	self._roundActive = false
	self:_setState(GameStates.MapRoundState.Lobby)
end

function RoundService:_step(dt: number)
	local safeZoneService = self._context.Services.SafeZoneService
	local arenaCount = self:_countArenaPlayers()
	if self._state == GameStates.MapRoundState.Lobby and arenaCount > 0 then
		self:_setState(GameStates.MapRoundState.Awaits)
	end
	if self._state == GameStates.MapRoundState.Awaits and arenaCount >= MIN_PLAYERS_TO_START then
		self:_startEarlyGame()
	end

	if self._state == GameStates.MapRoundState.EarlyGame or self._state == GameStates.MapRoundState.FinalPhase then
		self._roundTimer += dt
		if self._state == GameStates.MapRoundState.EarlyGame and safeZoneService and safeZoneService:IsAtMinimumRadius() then
			self:_setState(GameStates.MapRoundState.FinalPhase)
		end
		local aliveArenaPlayers = self:_countAliveArenaPlayers()
		if arenaCount >= MIN_PLAYERS_TO_START and aliveArenaPlayers <= 1 then
			self:_beginRoundEnd()
		end
	elseif self._state == GameStates.MapRoundState.RoundEnd then
		self._roundEndElapsed += dt
		if self._roundEndElapsed >= ROUND_END_FREEZE_SECONDS and self._roundEndElapsed < ROUND_END_RESULTS_SECONDS then
			self:_freezeArenaPlayers(false)
			if not self._resultsShown and self._roundResultRemote then
				self._resultsShown = true
				self._roundResultRemote:FireAllClients({
					Winner = self._winnerName or "No winner",
					RoundId = self._roundId,
				})
			end
		end
		if self._roundEndElapsed >= ROUND_END_RESULTS_SECONDS then
			self:_startPostRound()
		end
	end

	self:_publishUiState()
end

function RoundService:_publishUiState()
	if not self._uiStateRemote then
		return
	end
	local alivePlayers = self:_countAliveArenaPlayers()
	local playerCount = self:_countArenaPlayers()
	self._uiStateRemote:FireAllClients({
		State = self._state,
		LocationState = self._state,
		AlivePlayers = alivePlayers,
		PlayerCount = playerCount,
		CurrentMap = self._context.Services.MapService:GetActiveMap() or "Unknown",
		TimeLeft = self._roundTimer,
		CountdownTimer = self._roundTimer,
		RoundElapsed = self._roundTimer,
		RoundActive = self._roundActive,
		RoundId = self._roundId,
	})
end

return RoundService
