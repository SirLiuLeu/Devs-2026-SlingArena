--!strict

local ProjectTreeSpec = {
	UI = {
		Lobby = {
			ScreenGui = "LobbyUI", -- [REVIEW_REQUIRED]
			Root = "LobbyUI.LobbyUI.RootFrame", -- [REVIEW_REQUIRED]
			StatusLabel = "LobbyUI.LobbyUI.RootFrame.StatusLabel", -- [REVIEW_REQUIRED]
			JoinButton = "LobbyUI.LobbyUI.RootFrame.JoinButton", -- [REVIEW_REQUIRED]
			LeaveButton = "LobbyUI.LobbyUI.RootFrame.LeaveButton", -- [REVIEW_REQUIRED]
		},
		Stats = {
			ScreenGui = "StatsUI", -- [REVIEW_REQUIRED]
			Root = "StatsUI.StatsUI.RootFrame", -- [REVIEW_REQUIRED]
			ScoreLabel = "StatsUI.StatsUI.RootFrame.ScoreLabel", -- [REVIEW_REQUIRED]
			GoldLabel = "StatsUI.StatsUI.RootFrame.GoldLabel", -- [REVIEW_REQUIRED]
			WinsLabel = "StatsUI.StatsUI.RootFrame.WinsLabel", -- [REVIEW_REQUIRED]
		},
		Match = {
			ScreenGui = "MatchUI", -- [REVIEW_REQUIRED]
			Root = "MatchUI.MatchUI.RootFrame", -- [REVIEW_REQUIRED]
			StatusLabel = "MatchUI.MatchUI.RootFrame.StatusLabel", -- [REVIEW_REQUIRED]
			TimerLabel = "MatchUI.MatchUI.RootFrame.TimerLabel", -- [REVIEW_REQUIRED]
			AlivePlayersLabel = "MatchUI.MatchUI.RootFrame.AlivePlayersLabel", -- [REVIEW_REQUIRED]
			WinnerPopup = "MatchUI.MatchUI.RootFrame.WinnerPopup", -- [REVIEW_REQUIRED]
		},
	},
	Remotes = {
		Folder = "SlingArenaRemotes", -- [REVIEW_REQUIRED]
		JoinArena = "SlingArenaRemotes.JoinArena", -- [REVIEW_REQUIRED]
		LeaveArena = "SlingArenaRemotes.LeaveArena", -- [REVIEW_REQUIRED]
		StateUpdate = "SlingArenaRemotes.StateUpdate", -- [REVIEW_REQUIRED]
		UIStateUpdate = "SlingArenaRemotes.UIStateUpdate", -- [REVIEW_REQUIRED]
		RoundResult = "SlingArenaRemotes.RoundResult", -- [REVIEW_REQUIRED]
		StartCharge = "SlingArenaRemotes.StartCharge", -- [REVIEW_REQUIRED]
		ReleaseCharge = "SlingArenaRemotes.ReleaseCharge", -- [REVIEW_REQUIRED]
		GameplayFeedback = "SlingArenaRemotes.GameplayFeedback", -- [REVIEW_REQUIRED]
	},
	Services = {
		Client = {
			Players = "Players",
			ReplicatedStorage = "ReplicatedStorage",
			StarterGui = "StarterGui",
		},
		Server = {
			ServerScriptService = "ServerScriptService",
		},
	},
}

return ProjectTreeSpec
