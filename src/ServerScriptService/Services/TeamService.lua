--!strict

local TeamService = {}
TeamService.__index = TeamService

function TeamService.new(context)
	local self = setmetatable({}, TeamService)
	self._context = context
	return self
end

function TeamService:IsFriendly(playerA: Player, playerB: Player): boolean
	local stateService = self._context.Services.PlayerStateService
	local stateA = stateService and stateService:GetState(playerA)
	local stateB = stateService and stateService:GetState(playerB)
	if stateA and stateB and stateA.TeamId and stateB.TeamId then
		return stateA.TeamId ~= "" and stateA.TeamId == stateB.TeamId
	end
	return false
end

function TeamService:Init()
	-- Team membership is party-driven; no static TeamRed/TeamBlue assignment.
end

return TeamService
