--!strict

local GameStates = {
	PlayerState = {
		Idle = "Idle",
		Moving = "Moving",
		Charging = "Charging",
		Launching = "Launching",
		Knockback = "Knockback",
		Dead = "Dead",
		Human = "Human",
	},
	MovementStateTransitions = {
		Idle = { Moving = true, Charging = true, Knockback = true, Dead = true, Human = true },
		Moving = { Idle = true, Charging = true, Knockback = true, Dead = true, Human = true },
		Charging = { Launching = true, Idle = true, Knockback = true, Dead = true, Human = true },
		Launching = { Idle = true, Knockback = true, Dead = true, Human = true },
		Human = { Idle = true, Dead = true },
		Dead = { Idle = true, Human = true },

		-- Player-initiated movement transitions cannot exit Knockback. Server-only
		-- ForceSetMovementState handles verified stop/timeout exits.
		Knockback = {},
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
	PlayerMode = {
		Launcher = "Launcher",
		Human = "Human",
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
