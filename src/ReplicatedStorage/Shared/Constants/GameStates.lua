--!strict

local GameStates = {
	PlayerState = {
		Idle = "Idle",
		Moving = "Moving",
		Charging = "Charging",
		Launching = "Launching",
		Dead = "Dead",
	},
	PlayerFlag = {
		Ghost = "Ghost",
		Slow = "Slow",
		Stun = "Stun",
		Petrify = "Petrify",
		PoisonSpike = "PoisonSpike",
		Invisible = "Invisible",
		Recovering = "Recovering",
		Invulnerable = "Invulnerable",
	},
	SessionState = {
		Lobby = "Lobby",
		Loading = "Loading",
		InGame = "InGame",
	},
	MapRoundState = {
		Lobby = "Lobby",
		Awaits = "Awaits",
		EarlyGame = "EarlyGame",
		FinalPhase = "FinalPhase",
		RoundEnd = "RoundEnd",
	},
}

return GameStates
