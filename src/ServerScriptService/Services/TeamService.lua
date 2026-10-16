--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local TeamConfig = require(ReplicatedStorage.Shared.Config.TeamConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local TeamService = {}
TeamService.__index = TeamService

local TEAM_IDS = TeamConfig.TeamIds
local TEAM_ID_SET: { [string]: boolean } = {}
for _, teamId in ipairs(TEAM_IDS) do TEAM_ID_SET[teamId] = true end
local TEAM_CHANGE_COOLDOWN_SECONDS = TeamConfig.TeamChangeCooldownSeconds
local RAGE_START_SECONDS = TeamConfig.RageStartSeconds

function TeamService.new(context)
	local self = setmetatable({}, TeamService)
	self._context = context
	self._changeTeamRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.ChangeTeam) :: RemoteEvent?
	self._feedbackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	self._lastTeamChangeAt = {} :: { [number]: number }
	self._rageActive = false
	return self
end

function TeamService:_setTeamId(player: Player, teamId: string?)
	if teamId ~= nil and not TEAM_ID_SET[teamId] then
		warn(string.format("[TeamService] Refusing unknown team ID %q for %s.", tostring(teamId), player.Name))
		return
	end
	local teamInstance = if teamId then Teams:FindFirstChild(teamId) else nil
	if teamId and not (teamInstance and teamInstance:IsA("Team")) then
		warn(string.format("[TeamService] Teams.%s is missing. Create the Team instance in Studio.", teamId))
		teamInstance = nil
	end
	player.Team = if teamInstance and teamInstance:IsA("Team") then teamInstance else nil
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService then stateService:SetTeamId(player, teamId) end
end

function TeamService:_sendFeedback(player: Player, success: boolean, reason: string?, teamId: string?, cooldownRemaining: number?)
	if self._feedbackRemote and self._feedbackRemote:IsA("RemoteEvent") then
		self._feedbackRemote:FireClient(player, {
			EventType = "TeamChangeResult",
			Payload = { Success = success, Reason = reason, TeamId = teamId, CooldownRemaining = cooldownRemaining or 0 },
		})
	end
end

function TeamService:IsRageActive(): boolean
	return self._rageActive
end

function TeamService:SetRageActive(active: boolean)
	local changed = self._rageActive ~= active
	self._rageActive = active
	Workspace:SetAttribute("RageActive", active)
	if changed and self._context.EventBus then self._context.EventBus:Fire("RageModeChanged", active) end
end

function TeamService:GetTeamChangeCooldownRemaining(player: Player): number
	local changedAt = self._lastTeamChangeAt[player.UserId]
	if not changedAt then return 0 end
	return math.max(0, TEAM_CHANGE_COOLDOWN_SECONDS - (os.clock() - changedAt))
end

function TeamService:AssignBalancedTeam(player: Player): string?
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	if not state or state.LocationState == GameStates.SessionState.Lobby then return nil end
	local roundService = ServiceResolver.Get(self._context, "RoundService")
	if not (roundService and roundService:IsRoundActive()) then return nil end
	if self._rageActive or roundService:GetRoundElapsed() >= RAGE_START_SECONDS then
		self:SetRageActive(true)
		self:_setTeamId(player, nil)
		return nil
	end

	local counts: { [string]: number } = {}
	for _, teamId in ipairs(TEAM_IDS) do counts[teamId] = 0 end
	for _, candidate in ipairs(Players:GetPlayers()) do
		local candidateState = stateService:GetState(candidate)
		local teamId = candidateState and candidateState.TeamId
		if candidate ~= player and candidateState and candidateState.LocationState ~= GameStates.SessionState.Lobby
			and type(teamId) == "string" and TEAM_ID_SET[teamId] then
			counts[teamId] += 1
		end
	end
	local selectedTeam: string? = nil
	for _, teamId in ipairs(TEAM_IDS) do
		if counts[teamId] < TeamConfig.MaxPlayersPerTeam
			and (selectedTeam == nil or counts[teamId] < counts[selectedTeam]) then
			selectedTeam = teamId
		end
	end
	if not selectedTeam then
		self:_setTeamId(player, nil)
		warn(string.format("[TeamService] No team capacity remains for %s.", player.Name))
		return nil
	end
	self:_setTeamId(player, selectedTeam)
	return selectedTeam
end

function TeamService:AssignBalancedTeams(playersInRound: { Player })
	self:SetRageActive(false)
	table.clear(self._lastTeamChangeAt)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not stateService then
		warn("[TeamService] PlayerStateService unavailable; team assignment skipped.")
		return
	end
	local shuffledPlayers = table.clone(playersInRound)
	for index = #shuffledPlayers, 2, -1 do
		local swapIndex = math.random(1, index)
		shuffledPlayers[index], shuffledPlayers[swapIndex] = shuffledPlayers[swapIndex], shuffledPlayers[index]
	end
	for _, player in ipairs(shuffledPlayers) do self:_setTeamId(player, nil) end
	local counts: { [string]: number } = {}
	for _, teamId in ipairs(TEAM_IDS) do counts[teamId] = 0 end
	for _, player in ipairs(shuffledPlayers) do
		local selectedTeam: string? = nil
		for _, teamId in ipairs(TEAM_IDS) do
			if counts[teamId] < TeamConfig.MaxPlayersPerTeam
				and (selectedTeam == nil or counts[teamId] < counts[selectedTeam]) then
				selectedTeam = teamId
			end
		end
		self:_setTeamId(player, selectedTeam)
		if selectedTeam then counts[selectedTeam] += 1
		else warn(string.format("[TeamService] No team capacity remains for %s.", player.Name)) end
	end
end

function TeamService:ClearPlayerTeam(player: Player)
	self:_setTeamId(player, nil)
	self._lastTeamChangeAt[player.UserId] = nil
end

function TeamService:IsFriendly(playerA: Player, playerB: Player): boolean
	if playerA == playerB or self._rageActive then return false end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local stateA = stateService and stateService:GetState(playerA)
	local stateB = stateService and stateService:GetState(playerB)
	return stateA ~= nil and stateB ~= nil and stateA.TeamId ~= nil and stateA.TeamId == stateB.TeamId
end

function TeamService:ChangeTeam(player: Player, teamId: string)
	if not TEAM_ID_SET[teamId] then
		self:_sendFeedback(player, false, "InvalidTeam")
		return false, "InvalidTeam"
	end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player)
	local roundService = ServiceResolver.Get(self._context, "RoundService")
	if not state or state.LocationState == GameStates.SessionState.Lobby
		or not (roundService and roundService:IsRoundActive() and roundService:IsPlayingState()) then
		self:_sendFeedback(player, false, "RoundInactive")
		return false, "RoundInactive"
	end
	if self._rageActive or roundService:GetRoundElapsed() >= RAGE_START_SECONDS then
		self:SetRageActive(true)
		self:_sendFeedback(player, false, "RageActive")
		return false, "RageActive"
	end
	if state.TeamId == teamId then
		self:_sendFeedback(player, false, "AlreadyOnTeam", state.TeamId)
		return false, "AlreadyOnTeam"
	end
	local teamCount = 0
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= player then
			local candidateState = stateService:GetState(candidate)
			if candidateState and candidateState.LocationState ~= GameStates.SessionState.Lobby and candidateState.TeamId == teamId then
				teamCount += 1
			end
		end
	end
	if teamCount >= TeamConfig.MaxPlayersPerTeam then
		self:_sendFeedback(player, false, "TeamFull", state.TeamId)
		return false, "TeamFull"
	end
	local remaining = self:GetTeamChangeCooldownRemaining(player)
	if remaining > 0 then
		local cooldownRemaining = math.ceil(remaining)
		self:_sendFeedback(player, false, "Cooldown", state.TeamId, cooldownRemaining)
		return false, "Cooldown"
	end
	self:_setTeamId(player, teamId)
	self._lastTeamChangeAt[player.UserId] = os.clock()
	self:_sendFeedback(player, true, nil, teamId, TEAM_CHANGE_COOLDOWN_SECONDS)
	return true, nil
end

function TeamService:Init()
	Workspace:SetAttribute("RageActive", self._rageActive)
	for _, teamId in ipairs(TEAM_IDS) do
		local team = Teams:FindFirstChild(teamId)
		if not (team and team:IsA("Team")) then
			warn(string.format("[TeamService] Required Teams.%s is missing; create it manually in Studio.", teamId))
		else
			team.AutoAssignable = false
		end
	end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	for _, player in ipairs(Players:GetPlayers()) do
		local state = stateService and stateService:GetState(player)
		if not state or state.LocationState == GameStates.SessionState.Lobby then
			self:_setTeamId(player, nil)
		end
	end
	if self._changeTeamRemote and self._changeTeamRemote:IsA("RemoteEvent") then
		self._changeTeamRemote.OnServerEvent:Connect(function(player: Player, teamId: any)
			if not RemoteContracts.Validate(RemoteContracts.Names.ChangeTeam, teamId) then
				self:_sendFeedback(player, false, "InvalidRequest")
				return
			end
			self:ChangeTeam(player, teamId)
		end)
	else
		warn("Missing ReplicatedStorage.LauncherArenaRemotes.ChangeTeam (RemoteEvent). Create it from src/ReplicatedStorage/LauncherArenaRemotes/ChangeTeam.model.json.")
	end
	Players.PlayerAdded:Connect(function(player)
		-- Team assignment starts when the player joins the arena round, not in the lobby.
		player.Team = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._lastTeamChangeAt[player.UserId] = nil
	end)
end

return TeamService
