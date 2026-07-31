--!strict

local TeamService = {}
TeamService.__index = TeamService

function TeamService.new(context)
	local self = setmetatable({}, TeamService)
	self._context = context
	return self
end

function TeamService:AssignBalancedTeam(player: Player): string?
	player.Team = nil
	return nil
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
	-- Teams are intentionally uninitialized at startup.
	-- Team creation/assignment will be implemented in a future feature.
end

return TeamService
