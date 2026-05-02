--!strict

local GameStates = {
	-- Player gameplay state
	PlayerState = {
		Idle = "Idle",
		Moving = "Moving",
		Charging = "Charging",
		Launching = "Launching",
		Dead = "Dead",
	},

	-- Player flag / modifier system
	PlayerFlag = {
		Ghost = "Ghost",
		Slow = "Slow",
		Stun = "Stun",
		Freeze = "Freeze",
		PoisonSpike = "PoisonSpike", -- dính gai độc
		Invisible = "Invisible",
		Recovering = "Recovering", -- hồi máu
	},

	-- Session state: dùng cho flow vào game / ở lobby
	SessionState = {
		Lobby = "Lobby",
		Loading = "Loading",
		InGame = "InGame",
	},

	-- Map / Round service state
	MapRoundState = {
		Lobby = "Lobby",
		Awaits = "Awaits",
		EarlyGame = "EarlyGame",
		FinalPhase = "FinalPhase",
		RoundEnd = "RoundEnd"
	},
}

return GameStates
