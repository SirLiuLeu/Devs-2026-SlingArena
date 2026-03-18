--!strict

local ProjectTreeSpec = {
	UI = {
		Lobby = {
			ScreenGui = "LobbyUI", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI
			Root = "LobbyUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame
			StatusLabel = "LobbyUI.RootFrame.StatusLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.StatusLabel
			JoinButton = "LobbyUI.RootFrame.JoinButton", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.JoinButton
			LeaveButton = "LobbyUI.RootFrame.LeaveButton", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.LeaveButton
			DebugFoodButton = "LobbyUI.RootFrame.DebugFood", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.DebugFood
			DebugResetButton = "LobbyUI.RootFrame.DebugReset", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.DebugReset
			MapName = "LobbyUI.RootFrame.MapName", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.MapName
			LevelLabel = "LobbyUI.RootFrame.LevelLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.LevelLabel
			HpLabel = "LobbyUI.RootFrame.HpLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.HpLabel
			RespawnLabel = "LobbyUI.RootFrame.RespawnLabel", -- [PROJECT_TREE_SPEC] StarterGui.LobbyUI.RootFrame.RespawnLabel
		},
		Stats = {
			ScreenGui = "StatsUI", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI
			Root = "StatsUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.RootFrame
			ScoreLabel = "StatsUI.RootFrame.ScoreLabel", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.RootFrame.ScoreLabel
			GoldLabel = "StatsUI.RootFrame.GoldLabel", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.RootFrame.GoldLabel
			WinsLabel = "StatsUI.RootFrame.WinsLabel", -- [PROJECT_TREE_SPEC] StarterGui.StatsUI.RootFrame.WinsLabel
		},
		Match = {
			ScreenGui = "MatchUI", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI
			Root = "MatchUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame
			StatusLabel = "MatchUI.RootFrame.StatusLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.StatusLabel
			TimerLabel = "MatchUI.RootFrame.TimerLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.TimerLabel
			AlivePlayersLabel = "MatchUI.RootFrame.AlivePlayersLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.AlivePlayersLabel
			WinnerPopup = "MatchUI.RootFrame.WinnerPopup", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.WinnerPopup
		},
		SlingMovement = {
			ScreenGui = "SlingArenaDynamicUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI
			Root = "SlingArenaDynamicUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.RootFrame
			ChargeBarBg = "SlingArenaDynamicUI.RootFrame.ChargeBarBg", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.RootFrame.ChargeBarBg
			ChargeFill = "SlingArenaDynamicUI.RootFrame.ChargeBarBg.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.RootFrame.ChargeBarBg.Fill
			AimDirection = "SlingArenaDynamicUI.RootFrame.AimDirection", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.RootFrame.AimDirection
			ImpactFeedback = "SlingArenaDynamicUI.RootFrame.ImpactFeedback", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaDynamicUI.RootFrame.ImpactFeedback
		},
		SlingTouch = {
			ScreenGui = "SlingArenaUI.SlingUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI
			JoystickRoot = "SlingArenaUI.SlingUI.JoystickRoot", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.JoystickRoot
			JoystickBase = "SlingArenaUI.SlingUI.JoystickRoot.Base", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.JoystickRoot.Base
			JoystickThumb = "SlingArenaUI.SlingUI.JoystickRoot.Thumb", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.JoystickRoot.Thumb
			ChargeBar = "SlingArenaUI.SlingUI.ChargeBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.ChargeBar
			ChargeFill = "SlingArenaUI.SlingUI.ChargeBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.ChargeBar.Fill
			DirectionArrow = "SlingArenaUI.SlingUI.DirectionArrow", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.DirectionArrow
			CooldownBar = "SlingArenaUI.SlingUI.CooldownBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.CooldownBar
			CooldownFill = "SlingArenaUI.SlingUI.CooldownBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.CooldownBar.Fill
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
		--       Traps (Folder)
		--         Trap_01..N (Part | Model)
		--       FoodSpawns (Folder)
		--         EdgeZones (Folder)
		--           FoodSpawn_01..N (Part)
		--         MidZones (Folder)
		--           FoodSpawn_01..N (Part)
		--         CenterZones (Folder)
		--           FoodSpawn_01..N (Part)
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
				ArenaMapDirect = "ArenaMap",
				ArenaMapTraps = "ArenaMap.Traps",
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
