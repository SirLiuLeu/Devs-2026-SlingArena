--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local TeamService = {}
TeamService.__index = TeamService

TeamService.TeamIds = {
	Red = "TeamRed",
	Blue = "TeamBlue",
}

local TEAM_DEFS = {
	{
		id = TeamService.TeamIds.Red,
		color = BrickColor.new("Bright red"),
	},
	{
		id = TeamService.TeamIds.Blue,
		color = BrickColor.new("Bright blue"),
	},
}

function TeamService.new(context)
	local self = setmetatable({}, TeamService)
	self._context = context
	return self
end

function TeamService:_ensureTeam(teamDef)
	local team = Teams:FindFirstChild(teamDef.id)
	if team and team:IsA("Team") then
		team.TeamColor = teamDef.color
		team.AutoAssignable = false
		return team
	end

	local newTeam = Instance.new("Team")
	newTeam.Name = teamDef.id
	newTeam.TeamColor = teamDef.color
	newTeam.AutoAssignable = false
	newTeam.Parent = Teams
	return newTeam
end

function TeamService:_getTeamCounts(): { [string]: number }
	local counts = {}
	for _, teamDef in ipairs(TEAM_DEFS) do
		counts[teamDef.id] = 0
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local team = player.Team
		if team and counts[team.Name] ~= nil then
			counts[team.Name] += 1
		end
	end
	return counts
end

function TeamService:AssignBalancedTeam(player: Player): string
	local counts = self:_getTeamCounts()
	local teamId = TeamService.TeamIds.Red
	if (counts[TeamService.TeamIds.Blue] or 0) < (counts[TeamService.TeamIds.Red] or 0) then
		teamId = TeamService.TeamIds.Blue
	end

	local team = Teams:FindFirstChild(teamId)
	if team and team:IsA("Team") then
		player.Team = team
		player.TeamColor = team.TeamColor
	end
	return teamId
end

function TeamService:IsFriendly(playerA: Player, playerB: Player): boolean
	local stateService = self._context.Services.PlayerStateService
	local stateA = stateService and stateService:GetState(playerA)
	local stateB = stateService and stateService:GetState(playerB)
	if stateA and stateB and stateA.TeamId and stateB.TeamId then
		return stateA.TeamId == stateB.TeamId
	end
	return playerA.Team ~= nil and playerA.Team == playerB.Team
end

function TeamService:Init()
	for _, teamDef in ipairs(TEAM_DEFS) do
		self:_ensureTeam(teamDef)
	end

	Players.PlayerAdded:Connect(function(player)
		local teamId = self:AssignBalancedTeam(player)
		self._context.Services.PlayerStateService:SetTeamId(player, teamId)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		local teamId = self:AssignBalancedTeam(player)
		self._context.Services.PlayerStateService:SetTeamId(player, teamId)
	end
end

return TeamService
