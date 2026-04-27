--!strict

local GameStates = {
	Movement = {
		Idle = "Idle",
		Moving = "Moving",
		Charging = "Charging",
		Launched = "Launched",
		Recovering = "Recovering",
	},
	Round = {
		Boot = "Boot",
		Lobby = "Lobby",
		Awaits = "Awaits",
		EarlyGame = "EarlyGame",
		FinalPhase = "FinalPhase",
		RoundEnd = "RoundEnd",
		PostRound = "PostRound",
	},
	ArenaStatus = {
		Lobby = "Lobby",
		InArena = "InArena",
	},
}

return GameStates
