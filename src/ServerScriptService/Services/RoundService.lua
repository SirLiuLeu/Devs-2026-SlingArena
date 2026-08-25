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
local END_ROUND_RATE_LIMIT_SECONDS = 2
local UI_STATE_TIMER_INTERVAL_SECONDS = 0.5

function RoundService.new(context)
	local self = setmetatable({}, RoundService)
	self._context = context
	self._state = GameStates.MapRoundState.Lobby
	self._roundActive = false
	self._roundTimer = 0
	self._roundEndElapsed = 0
	self._winnerName = nil :: string?
	self._resultsShown = false
	self._lastPublishedUiState = nil
	self._uiStateElapsed = 0
	self._lastUiAlivePlayers = nil
	self._lastUiPlayerCount = nil
	self._lastLeaveByUserId = {} :: { [number]: number }
	self._lastEndRoundRequestByUserId = {} :: { [number]: number }
	self._frozenRoots = {} :: { [Player]: BasePart }
	self._roundId = 1
	self._matchStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent
	self._uiStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
	self._popupRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.PopupMessage) :: RemoteEvent?
	self._roundResultRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.RoundResult) :: RemoteEvent?
	self._joinRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
	self._leaveRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
	self._startSafeZoneRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.StartSafeZone) :: RemoteEvent?
	self._plus1MinuteRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.Plus1Minute) :: RemoteEvent?
	self._endRoundRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.EndRound) :: RemoteEvent?
	self._matchSummaryRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchSummaryUpdate) :: RemoteEvent?
	return self
end

function RoundService:Init()
	Players.PlayerAdded:Connect(function(player)
		-- A newly joined client can miss the initial broadcast; give it a targeted snapshot.
		task.defer(function()
			if player.Parent == Players then
				self:_sendUiStateToPlayer(player)
			end
		end)
	end)
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
	if self._plus1MinuteRemote then
		self._plus1MinuteRemote.OnServerEvent:Connect(function(player)
			self:RequestPlus1Minute(player)
		end)
	end
	if self._endRoundRemote then
		-- TODO: RequestEndRound is a debug-only UnitTestUI hook. Remove this remote before public release.
		self._endRoundRemote.OnServerEvent:Connect(function(player)
			self:RequestEndRound(player)
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

-- Debug-only UnitTestUI tool; remove before public release.
function RoundService:RequestEndRound(player: Player)
	print(string.format("[DIAG][RoundService] RequestEndRound player=%s state=%s roundId=%d t=%.3f", player.Name, tostring(self._state), self._roundId, os.clock()))
	local now = os.clock()
	local lastRequestAt = self._lastEndRoundRequestByUserId[player.UserId]
	if lastRequestAt and now - lastRequestAt < END_ROUND_RATE_LIMIT_SECONDS then
		return
	end
	self._lastEndRoundRequestByUserId[player.UserId] = now
	self:_beginRoundEnd()
end

function RoundService:RequestPlus1Minute(_player: Player)
	if not self:IsPlayingState() then
		return
	end
	self._roundTimer += 60
	local safeZoneService = self._context.Services.SafeZoneService
	if safeZoneService and typeof(safeZoneService.SetElapsed) == "function" then
		safeZoneService:SetElapsed(self._roundTimer)
	end
	if self._state == GameStates.MapRoundState.EarlyGame and safeZoneService and safeZoneService:IsAtMinimumRadius() then
		self:_setState(GameStates.MapRoundState.FinalPhase)
	else
		self:_publishUiState()
	end
end

function RoundService:JoinArena(player: Player)
	if not self:_canJoinArena(player) then
		local leaveAt = self._lastLeaveByUserId[player.UserId] or os.clock()
		local remainingSeconds = REJOIN_COOLDOWN_SECONDS - (os.clock() - leaveAt)
		if self._context.EventBus then
			self._context.EventBus:Fire("ArenaJoinCooldown", player, remainingSeconds)
		end
		return
	end
	local arenaMapName = self._context.Services.MapService:GetDefaultArenaMapName()
	self._context.Services.MapService:ActivateMap(arenaMapName)
	local spawnMode = self._context.Services.PlayerStateService:ResolveArenaSpawnMode(player)
	self._context.Services.PlayerService:SpawnForActiveMode(player, nil, arenaMapName, spawnMode)
	self._context.Services.PlayerStateService:SetCurrentMap(player, arenaMapName)
	self._context.Services.PlayerStateService:SetLocationState(player, GameStates.SessionState.InGame)
	if self._state == GameStates.MapRoundState.Lobby then
		self:_setState(GameStates.MapRoundState.Awaits)
	end
	self:_publishUiState()
end

function RoundService:LeaveArena(player: Player)
	self._lastLeaveByUserId[player.UserId] = os.clock()
	local lobbyMode = self._context.Services.PlayerStateService:GetState(player) and self._context.Services.PlayerStateService:GetState(player).SelectedPlayerMode or GameStates.PlayerMode.Human
	self._context.Services.PlayerService:SpawnForActiveMode(player, 1, "LobbyMap", lobbyMode)
	self._context.Services.PlayerStateService:SetCurrentMap(player, "LobbyMap")
	self._context.Services.PlayerStateService:SetLocationState(player, GameStates.SessionState.Lobby)
	if self:_countArenaPlayers() == 0 and self._state ~= GameStates.MapRoundState.RoundEnd and self._state ~= GameStates.MapRoundState.PostRound then
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
		if state and state.LocationState ~= GameStates.SessionState.Lobby and state.IsAlive and state.ActivePlayerMode == GameStates.PlayerMode.Launcher then
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
		if state and state.LocationState ~= GameStates.SessionState.Lobby and state.IsAlive and state.ActivePlayerMode == GameStates.PlayerMode.Launcher then
			return player.Name
		end
	end
	return nil
end

function RoundService:_setState(nextState: string)
	if self._state == nextState then
		return
	end
	local previousState = self._state
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
	if self._context.EventBus then
		self._context.EventBus:Fire("RoundStateChanged", {
			State = nextState,
			PreviousState = previousState,
			RoundId = self._roundId,
		})
	end
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
	for _, player in ipairs(Players:GetPlayers()) do
		local state = self._context.Services.PlayerStateService:GetState(player)
		if state and state.LocationState ~= GameStates.SessionState.Lobby then
			self._context.Services.PlayerStateService:ResetForNewRound(player)
		end
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
	print(string.format("[DIAG][RoundService] beginRoundEnd entry state=%s roundId=%d active=%s t=%.3f", tostring(self._state), self._roundId, tostring(self._roundActive), os.clock()))
	if self._state == GameStates.MapRoundState.RoundEnd or self._state == GameStates.MapRoundState.PostRound then
		return
	end
	self._resultsShown = false
	self._roundActive = false
	self._roundEndElapsed = 0
	local leaderboardService = self._context.Services.LeaderboardService
	local progressPointService = self._context.Services.ProgressPointService
	local topPlayers = if leaderboardService and typeof(leaderboardService.GetTopPlayers) == "function" then leaderboardService:GetTopPlayers() else {}
	local winnerNames = {}
	for _, row in ipairs(topPlayers) do
		if type(row) == "table" and row.Rank == 1 then
			table.insert(winnerNames, tostring(row.Name or "Player"))
		end
	end
	self._winnerName = if #winnerNames > 0 then table.concat(winnerNames, ", ") else (self:_findLastAlivePlayerName() or "No winner")
	local summaryRows = if progressPointService and typeof(progressPointService.AwardEndRoundPoints) == "function" then progressPointService:AwardEndRoundPoints(topPlayers) else topPlayers
	self:_setState(GameStates.MapRoundState.RoundEnd)
	self:_freezeArenaPlayers(true)
	if self._matchSummaryRemote then
		self._matchSummaryRemote:FireAllClients({
			Rows = summaryRows,
			RoundId = self._roundId,
			Winner = self._winnerName or "No winner",
			DurationSeconds = ROUND_END_RESULTS_SECONDS,
		})
	end
end

function RoundService:_startPostRound()
	self:_setState(GameStates.MapRoundState.PostRound)
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
		local lobbyMode = stateService and stateService:GetState(player) and stateService:GetState(player).SelectedPlayerMode or GameStates.PlayerMode.Human
		self._context.Services.PlayerService:SpawnForActiveMode(player, 1, "LobbyMap", lobbyMode)
		if stateService then
			stateService:ClearHumanQualification(player)
			stateService:SetCurrentMap(player, "LobbyMap")
			stateService:SetLocationState(player, GameStates.SessionState.Lobby)
		end
	end

	local leaderboardService = self._context.Services.LeaderboardService
	if leaderboardService and typeof(leaderboardService.ResetForNewRound) == "function" then
		leaderboardService:ResetForNewRound()
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
		self._uiStateElapsed += dt
		if self._state == GameStates.MapRoundState.EarlyGame and safeZoneService and safeZoneService:IsAtMinimumRadius() then
			self:_setState(GameStates.MapRoundState.FinalPhase)
		end
		local aliveArenaPlayers = self:_countAliveArenaPlayers()
		if arenaCount >= MIN_PLAYERS_TO_START and aliveArenaPlayers <= 1 then
			self:_beginRoundEnd()
		elseif self._lastUiAlivePlayers ~= aliveArenaPlayers or self._lastUiPlayerCount ~= arenaCount or self._uiStateElapsed >= UI_STATE_TIMER_INTERVAL_SECONDS then
			self._uiStateElapsed = 0
			self:_publishUiState()
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

end

function RoundService:_publishUiState()
	if not self._uiStateRemote then
		return
	end
	local payload = self:_buildUiStatePayload()
	local alivePlayers = payload.AlivePlayers
	local playerCount = payload.PlayerCount
	local lastPayload = self._lastPublishedUiState
	if lastPayload then
		local changed = false
		for key, value in pairs(payload) do
			if lastPayload[key] ~= value then changed = true; break end
		end
		if not changed then
			for key in pairs(lastPayload) do if payload[key] == nil then changed = true; break end end
		end
		if not changed then return end
	end
	self._lastPublishedUiState = table.clone(payload)
	self._lastUiAlivePlayers = alivePlayers
	self._lastUiPlayerCount = playerCount
	self._uiStateRemote:FireAllClients(payload)
end

function RoundService:_buildUiStatePayload()
	local alivePlayers = self:_countAliveArenaPlayers()
	local playerCount = self:_countArenaPlayers()
	return {
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
	}
end

function RoundService:_sendUiStateToPlayer(player: Player)
	if self._uiStateRemote then
		self._uiStateRemote:FireClient(player, self:_buildUiStatePayload())
	end
end

return RoundService
