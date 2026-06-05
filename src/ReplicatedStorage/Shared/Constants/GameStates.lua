--!strict

local GameStates = {
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
		Petrify = "Petrify",
		PoisonTrap = "PoisonTrap",
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
