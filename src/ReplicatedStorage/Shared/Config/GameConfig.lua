--!strict

local StateAndFlagConfig = {
	Match = {
        AwaitsTime = 180, -- thời gian chờ đủ player hoặc hết thời gian thì vào map
		EarlyPhaseTime = 480,
		FinalPhaseTime = 120,
        RoundEndTime = 20,
		RespawnTime = 5,
	},

	JoinRule = {
		AllowFromLobby = true,
		AllowFromLoading = false,
		AllowFromInGame = false,
	},

	PlayerState = {
		Idle = "Idle",
		Moving = "Moving",
		Charging = "Charging",
		Launching = "Launching",
        Knockback = "Knockback",
		Dead = "Dead",
	},

	PlayerFlag = {
		Ghost = "Ghost",
		Slow = "Slow",
		Stun = "Stun",
		Freeze = "Freeze",
		PoisonSpike = "PoisonSpike",
		Invisible = "Invisible",
		Recovering = "Recovering",
	},

	FlagConfig = {
		Slow = {
			Duration = 5,
			Stackable = true,
			MaxStack = 3,
		},

		Stun = {
			Duration = 2,
		},

		Freeze = {
			Duration = 2,
		},

		PoisonSpike = {
			Duration = 5,
		},

		Invisible = {
			Duration = 1,
		},

		Recovering = {
			Duration = 5,
		},

		Ghost = {
			Duration = 9999,
		},

        Invulnerable = {
            Duration = 5, 
        },
	},
 -- Session state: dùng cho flow vào game / ở lobby của player
	SessionState = {
		Lobby = "Lobby",
		Loading = "Loading",
		InGame = "InGame",
	},
-- Map / Round service state: dùng cho flow của map / round
	MapRoundState = {
		Lobby = "Lobby",
		Awaits = "Awaits",
		EarlyGame = "EarlyGame",
		FinalPhase = "FinalPhase",
		RoundEnd = "RoundEnd",
		PostRound = "PostRound",
	},
}

return StateAndFlagConfig