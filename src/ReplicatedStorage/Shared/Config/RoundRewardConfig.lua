--!strict

-- Server-authoritative round placement reward and queue timing settings.
local RoundRewardConfig = {}

RoundRewardConfig.AwaitCountdownSeconds = 30
RoundRewardConfig.SoloFinalPhaseSeconds = 8 * 60

-- The winner receives N + 1 boxes; the last eligible placement receives 2.
function RoundRewardConfig.GetGiftBoxAmount(participantCount: number, rank: number): number
	local safeCount = math.max(0, math.floor(tonumber(participantCount) or 0))
	local safeRank = math.max(1, math.floor(tonumber(rank) or 1))
	if safeCount == 0 or safeRank > safeCount then
		return 0
	end
	return math.max(0, safeCount + 2 - safeRank)
end

return RoundRewardConfig
