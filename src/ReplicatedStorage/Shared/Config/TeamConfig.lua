--!strict

local TeamConfig = {}

-- These IDs must match the Team instances under the Studio Teams service.
TeamConfig.TeamIds = { "White", "Yellow", "Blue", "Red" }
TeamConfig.MaxPlayersPerTeam = 10
TeamConfig.TeamChangeCooldownSeconds = 30
TeamConfig.RageStartSeconds = 8 * 60

local teamIdSet: { [string]: boolean } = {}
for _, teamId in ipairs(TeamConfig.TeamIds) do teamIdSet[teamId] = true end

function TeamConfig.IsTeamId(value: any): boolean
	return typeof(value) == "string" and teamIdSet[value] == true
end

return TeamConfig
