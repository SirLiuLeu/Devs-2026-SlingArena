--!strict

local TeamConfig = {}

TeamConfig.TeamIds = { "White", "Yellow", "Blue", "Red" }
TeamConfig.MaxPlayersPerTeam = 10
TeamConfig.ChangeCooldownSeconds = 30
TeamConfig.RageStartSeconds = 8 * 60
TeamConfig.RageTeamId = "Rage"

TeamConfig.IsTeamId = function(teamId: any): boolean
	if typeof(teamId) ~= "string" then return false end
	for _, id in ipairs(TeamConfig.TeamIds) do
		if id == teamId then return true end
	end
	return false
end

return TeamConfig
