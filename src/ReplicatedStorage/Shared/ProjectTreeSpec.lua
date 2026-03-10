--!strict

local ProjectTreeSpec = {
	UI = {
		Lobby = {
			ScreenGui = "LobbyUI", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI
			Root = "LobbyUI.LobbyUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame
			StatusLabel = "LobbyUI.LobbyUI.RootFrame.StatusLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.StatusLabel
			JoinButton = "LobbyUI.LobbyUI.RootFrame.JoinButton", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.JoinButton
			LeaveButton = "LobbyUI.LobbyUI.RootFrame.LeaveButton", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.LeaveButton
			TeleportForestButton = "LobbyUI.LobbyUI.RootFrame.TeleportForest", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.TeleportForest
			TeleportDesertButton = "LobbyUI.LobbyUI.RootFrame.TeleportDesert", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.TeleportDesert
			DebugFoodButton = "LobbyUI.LobbyUI.RootFrame.DebugFood", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.DebugFood
			DebugResetButton = "LobbyUI.LobbyUI.RootFrame.DebugReset", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.DebugReset
			MapName = "LobbyUI.LobbyUI.RootFrame.MapName", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.MapName
			LevelLabel = "LobbyUI.LobbyUI.RootFrame.LevelLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.LevelLabel
			HpLabel = "LobbyUI.LobbyUI.RootFrame.HpLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.HpLabel
			RespawnLabel = "LobbyUI.LobbyUI.RootFrame.RespawnLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.LobbyUI.RootFrame.RespawnLabel
		},
		Stats = {
			ScreenGui = "StatsUI", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI
			Root = "StatsUI.StatsUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.StatsUI.RootFrame
			ScoreLabel = "StatsUI.StatsUI.RootFrame.ScoreLabel", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.StatsUI.RootFrame.ScoreLabel
			GoldLabel = "StatsUI.StatsUI.RootFrame.GoldLabel", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.StatsUI.RootFrame.GoldLabel
			WinsLabel = "StatsUI.StatsUI.RootFrame.WinsLabel", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.StatsUI.RootFrame.WinsLabel
		},
		Match = {
			ScreenGui = "MatchUI", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI
			Root = "MatchUI.MatchUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.MatchUI.RootFrame
			StatusLabel = "MatchUI.MatchUI.RootFrame.StatusLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.MatchUI.RootFrame.StatusLabel
			TimerLabel = "MatchUI.MatchUI.RootFrame.TimerLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.MatchUI.RootFrame.TimerLabel
			AlivePlayersLabel = "MatchUI.MatchUI.RootFrame.AlivePlayersLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.MatchUI.RootFrame.AlivePlayersLabel
			WinnerPopup = "MatchUI.MatchUI.RootFrame.WinnerPopup", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.MatchUI.RootFrame.WinnerPopup
		},
		SlingMovement = {
			ScreenGui = "SlingArenaDynamicUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI
			Root = "SlingArenaDynamicUI.SlingArenaDynamicUI.Root", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.SlingArenaDynamicUI.Root
			ChargeBarBg = "SlingArenaDynamicUI.SlingArenaDynamicUI.Root.ChargeBarBg", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.SlingArenaDynamicUI.Root.ChargeBarBg
			ChargeFill = "SlingArenaDynamicUI.SlingArenaDynamicUI.Root.ChargeBarBg.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.SlingArenaDynamicUI.Root.ChargeBarBg.Fill
			AimDirection = "SlingArenaDynamicUI.SlingArenaDynamicUI.Root.AimDirection", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.SlingArenaDynamicUI.Root.AimDirection
			ImpactFeedback = "SlingArenaDynamicUI.SlingArenaDynamicUI.Root.ImpactFeedback", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.SlingArenaDynamicUI.Root.ImpactFeedback
		},
	},
	Remotes = {
		Folder = "SlingArenaRemotes", -- [PROJECT_TREE_SPEC] ReplicatedStorage.SlingArenaRemotes
		JoinArena = "SlingArenaRemotes.JoinArena", -- [PROJECT_TREE_SPEC]
		LeaveArena = "SlingArenaRemotes.LeaveArena", -- [PROJECT_TREE_SPEC]
		StateUpdate = "SlingArenaRemotes.StateUpdate", -- [PROJECT_TREE_SPEC]
		UIStateUpdate = "SlingArenaRemotes.UIStateUpdate", -- [PROJECT_TREE_SPEC]
		RoundResult = "SlingArenaRemotes.RoundResult", -- [PROJECT_TREE_SPEC]
		StartCharge = "SlingArenaRemotes.StartCharge", -- [PROJECT_TREE_SPEC]
		ReleaseCharge = "SlingArenaRemotes.ReleaseCharge", -- [PROJECT_TREE_SPEC]
		GameplayFeedback = "SlingArenaRemotes.GameplayFeedback", -- [PROJECT_TREE_SPEC]
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
	GameplayInstances = {
		-- [PROJECT_TREE_SPEC]
		-- Workspace
		--   Maps (Folder)
		--     LobbyMap (Model)
		--       SpawnPoints (Folder)
		--         SpawnPoint (Part)
		--       Gate (Part)
		--     Arena_01 (Model)
		--       SpawnPoints (Folder)
		--         SpawnPoint_01..N (Part)
		--       FoodContainer (Folder)
		--       TrapContainer (Folder)
		--       FoodSpawns (Folder)
		--         EdgeZones (Folder)
		--           FoodSpawn_01..N (Part)
		--         MidZones (Folder)
		--           FoodSpawn_01..N (Part)
		--         CenterZones (Folder)
		--           FoodSpawn_01..N (Part)
		--       TrapSpawns (Folder)
		--         TrapSpawn_01..N (Part)
		--       WallContainer (Folder)
		--     Arena_02 (Model)
		--       (same structure as Arena_01)

		-- ServerStorage
		--   FoodTemplates (Folder)
		--     AppleFood (Model)
		--     MeatFood (Model)
		--     BerryFood (Model)
		--   TrapTemplates (Folder)
		--     SpikeTrap (Model)
		--     MineTrap (Model)
		--
		-- ReplicatedStorage
		--   Assets (Folder)
		--     SlingModel (Model)
		--     Food (Folder)
		--       BasicFood (Model) [fallback]
		--		 Food1, Food2, Food3, ...Food7 (Model)
		--     Trap (Folder)
		--       BasicTrap (Model) [fallback]
		Workspace = {
			SlingPawns = "SlingPawns",
			Maps = {
				Root = "Maps",
				LobbyMap = "Maps.LobbyMap",
				Arena01 = "Maps.Arena_01",
				Arena02 = "Maps.Arena_02",
			},
		},
		ServerStorage = {
			FoodTemplates = "FoodTemplates",
			TrapTemplates = "TrapTemplates",
		},
		ReplicatedStorage = {
			Assets = {
				SlingModel = "Assets.SlingModel",
				Food1 = "Assets.Food.Food1",
				Food2 = "Assets.Food.Food2",
				Food3 = "Assets.Food.Food3",
				Food4 = "Assets.Food.Food4",
				Food5 = "Assets.Food.Food5",
				Food6 = "Assets.Food.Food6",
				Food7 = "Assets.Food.Food7",
				BasicTrap = "Assets.Trap.BasicTrap",
			}
		},
	},
}

return ProjectTreeSpec
