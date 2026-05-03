--!strict

local GameConfig = {
	Match = {
		AwaitsTime = 180,
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

	FlagConfig = {
		Slow = { Duration = 5, Stackable = true, MaxStack = 3 },
		Stun = { Duration = 2 },
		Freeze = { Duration = 2 },
		PoisonSpike = { Duration = 5 },
		Invisible = { Duration = 1 },
		Recovering = { Duration = 5 },
		Ghost = { Duration = 9999 },
		Invulnerable = { Duration = 5 },
	},
}

return GameConfig
