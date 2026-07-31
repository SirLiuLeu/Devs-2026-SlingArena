--!strict

export type RankSetting = {
	Name: string,
	MinPoints: number,
	MaxPoints: number,
	EntryFee: number,
}

export type ScoreSetting = {
	Points: number?,
	MaxPerSession: number?,
	BasePoints: number?,
	CooldownSeconds: number?,
	CycleSeconds: number?,
	ZoneMultipliers: { number },
}

export type LateJoinSettings = {
	DiscountByMinute: { number },
	ExpCompensationRate: number,
}

local RankConfig = {}

RankConfig.RankSettings = {
	{ Name = "Iron", MinPoints = 0, MaxPoints = 499, EntryFee = 0 },
	{ Name = "Bronze", MinPoints = 500, MaxPoints = 999, EntryFee = 10 },
	{ Name = "Silver", MinPoints = 1000, MaxPoints = 1999, EntryFee = 25 },
	{ Name = "Gold", MinPoints = 2000, MaxPoints = 3499, EntryFee = 50 },
	{ Name = "Diamond", MinPoints = 3500, MaxPoints = 5499, EntryFee = 80 },
	{ Name = "Master", MinPoints = 5500, MaxPoints = 7999, EntryFee = 120 },
	{ Name = "Challenger", MinPoints = 8000, MaxPoints = math.huge, EntryFee = 180 },
} :: { RankSetting }

RankConfig.ScoreSettings = {
	CommonFood = {
		Points = 1,
		MaxPerSession = 30,
		ZoneMultipliers = {},
	},
	PremiumFood = {
		Points = 2,
		ZoneMultipliers = {},
	},
	KillPlayer = {
		BasePoints = 10,
		CooldownSeconds = 60,
		ZoneMultipliers = {},
	},
	Survival = {
		BasePoints = 5,
		CycleSeconds = 30,
		ZoneMultipliers = { 1, 1.15, 1.3, 1.5, 1.75, 2 },
	},
} :: { [string]: ScoreSetting }

RankConfig.LateJoinSettings = {
	DiscountByMinute = {
		[0] = 1,
		[1] = 0.95,
		[2] = 0.9,
		[3] = 0.85,
		[4] = 0.8,
		[5] = 0.75,
		[6] = 0.7,
		[7] = 0.65,
		[8] = 0.6,
	},
	ExpCompensationRate = 0.8,
} :: LateJoinSettings

function RankConfig.GetRankForPoints(points: number): RankSetting
	for _, rankSetting in ipairs(RankConfig.RankSettings) do
		if points >= rankSetting.MinPoints and points <= rankSetting.MaxPoints then
			return rankSetting
		end
	end

	return RankConfig.RankSettings[1]
end

function RankConfig.GetLateJoinDiscountMultiplier(joinElapsedSeconds: number): number
	local minute = math.clamp(math.floor(math.max(joinElapsedSeconds, 0) / 60), 0, 8)
	return RankConfig.LateJoinSettings.DiscountByMinute[minute] or 1
end

return RankConfig
