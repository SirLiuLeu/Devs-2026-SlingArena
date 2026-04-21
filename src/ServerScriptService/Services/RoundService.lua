--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(context)
	local self = setmetatable({}, RoundService)
	self._context = context
	self._state = GameStates.Round.ActiveRound
	self._roundId = 1
	self._matchStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent
	self._uiStateRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
	self._joinRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.JoinArena) :: RemoteEvent
	self._leaveRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.LeaveArena) :: RemoteEvent
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
	self:_publishUiState()
end

function RoundService:IsRoundActive(): boolean
	return true
end

function RoundService:IsPlayingState(): boolean
	return true
end

function RoundService:IsPlayerQueued(_player: Player): boolean
	return true
end

function RoundService:GetState()
	return self._state
end

function RoundService:JoinArena(player: Player)
	local arenaMapName = self._context.Services.MapService:GetDefaultArenaMapName()
	self._context.Services.MapService:ActivateMap(arenaMapName)
	self._context.Services.PlayerService:SpawnPawn(player, nil, arenaMapName)
	self._context.Services.PlayerStateService:SetMapName(player, arenaMapName)
	self._context.Services.PlayerStateService:SetArenaStatus(player, GameStates.ArenaStatus.InArena)
	self:_publishUiState()
end

function RoundService:LeaveArena(player: Player)
	self._context.Services.PlayerService:SpawnPawn(player, 1, "LobbyMap")
	self._context.Services.PlayerStateService:SetMapName(player, "LobbyMap")
	self._context.Services.PlayerStateService:SetArenaStatus(player, GameStates.ArenaStatus.Lobby)
	self:_publishUiState()
end

function RoundService:_publishUiState()
	if not self._uiStateRemote then
		return
	end
	self._uiStateRemote:FireAllClients({
		State = self._state,
		ArenaStatus = self._state,
		AlivePlayers = 0,
		PlayerCount = 0,
		MapName = self._context.Services.MapService:GetActiveMap() or "Unknown",
		TimeLeft = 0,
		CountdownTimer = 0,
	})
end

return RoundService
