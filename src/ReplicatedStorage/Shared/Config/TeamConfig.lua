--!strict

local TeamConfig = {}

TeamConfig.ChangeCooldownSeconds = 30
TeamConfig.RageStartSeconds = 8 * 60
TeamConfig.MaxPlayersPerTeam = 10
TeamConfig.TeamIds = { "White", "Yellow", "Blue", "Red" }

local teamIdSet: { [string]: boolean } = { White = true, Yellow = true, Blue = true, Red = true }
local teamColors: { [string]: Color3 } = {
	White = Color3.fromRGB(245, 245, 245),
	Yellow = Color3.fromRGB(255, 220, 70),
	Blue = Color3.fromRGB(70, 145, 255),
	Red = Color3.fromRGB(255, 80, 80),
}
TeamConfig.TeamIdSet = teamIdSet
TeamConfig.TeamColors = teamColors

return TeamConfig
