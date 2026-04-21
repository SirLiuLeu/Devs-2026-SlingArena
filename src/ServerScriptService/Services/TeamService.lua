--!strict

local Players = game:GetService("Players")

local TeamService = {}
TeamService.__index = TeamService

function TeamService.new(context)
	local self = setmetatable({}, TeamService)
	self._context = context
	return self
end

function TeamService:AssignBalancedTeam(player: Player): string
	player.Team = nil
	return string.format("Solo:%d", player.UserId)
end

function TeamService:IsFriendly(playerA: Player, playerB: Player): boolean
	local stateService = self._context.Services.PlayerStateService
	local stateA = stateService and stateService:GetState(playerA)
	local stateB = stateService and stateService:GetState(playerB)
	if stateA and stateB and stateA.TeamId and stateB.TeamId then
		return stateA.TeamId == stateB.TeamId
	end
	return false
end

function TeamService:Init()
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
