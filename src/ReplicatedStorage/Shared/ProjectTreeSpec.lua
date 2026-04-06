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
		SlingStats = {
			ScreenGui = "SlingStatsUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI
			StatsRoot = "SlingStatsUI.StatsRoot", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot
			HeaderBar = "SlingStatsUI.StatsRoot.HeaderBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.HeaderBar
			TitleLabel = "SlingStatsUI.StatsRoot.HeaderBar.TitleLabel", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.HeaderBar.TitleLabel
			AvailablePointsLabel = "SlingStatsUI.StatsRoot.HeaderBar.AvailablePointsLabel", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.HeaderBar.AvailablePointsLabel
			ToggleDropdownButton = "SlingStatsUI.StatsRoot.HeaderBar.ToggleDropdownButton", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.HeaderBar.ToggleDropdownButton
			BodyContainer = "SlingStatsUI.StatsRoot.BodyContainer", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer
			AttributeList = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList
			AttributeRows = {
				HP = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.HPRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.HPRow
				BaseDamage = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.BaseDamageRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.BaseDamageRow
				RegenRate = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.RegenRateRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.RegenRateRow
				ReflectDamage = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.ReflectDamageRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.ReflectDamageRow
				LaunchSpeed = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.LaunchSpeedRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.LaunchSpeedRow
				LaunchRange = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.LaunchRangeRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.LaunchRangeRow
				ChargeSpeed = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.ChargeSpeedRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.ChargeSpeedRow
				MoveSpeed = "SlingStatsUI.StatsRoot.BodyContainer.AttributeList.MoveSpeedRow", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.AttributeList.MoveSpeedRow
			},
			ResetButton = "SlingStatsUI.StatsRoot.BodyContainer.ActionButtonsRow.ResetButton", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.ActionButtonsRow.ResetButton
			AcceptButton = "SlingStatsUI.StatsRoot.BodyContainer.ActionButtonsRow.AcceptButton", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.BodyContainer.ActionButtonsRow.AcceptButton
			FooterExpBar = "SlingStatsUI.StatsRoot.FooterExpBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.FooterExpBar
			ExpBarFill = "SlingStatsUI.StatsRoot.FooterExpBar.ExpBarFill", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.FooterExpBar.ExpBarFill
			ExpValueLabel = "SlingStatsUI.StatsRoot.FooterExpBar.ExpValueLabel", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.FooterExpBar.ExpValueLabel
			LevelOnBarLabel = "SlingStatsUI.StatsRoot.FooterExpBar.LevelOnBarLabel", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI.StatsRoot.FooterExpBar.LevelOnBarLabel
		},
		MainHub = {
			ScreenGui = "MainHUD", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD
			Root = "MainHUD.Root", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root
			SlingStatsButton = "MainHUD.Root.SlingStatsButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.SlingStatsButton
			DailyButton = "MainHUD.Root.LeftMenu.DailyButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.DailyButton
			InventoryButton = "MainHUD.Root.LeftMenu.InventoryButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.InventoryButton
			OnlineRewardButton = "MainHUD.Root.LeftMenu.OnlineRewardButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.OnlineRewardButton
			SettingButton = "MainHUD.Root.LeftMenu.SettingButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.SettingButton
			SpinButton = "MainHUD.Root.LeftMenu.SpinButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.SpinButton
			QuickHP = "MainHUD.Root.QuickHP", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.QuickHP
			HomeButton = "MainHUD.Root.Home", -- [INFERRED from PROJECT_TREE.md] StarterGui.MainHUD.Root.Home
			HpBarFill = "MainHUD.Root.HpBar.Fill", -- [UNKNOWN] optional hp fill path to support visual hp bar updates
			Panels = {
				SlingStats = "SlingStatsUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingStatsUI
				DailyLogin = "DailyLoginUI", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI
				Inventory = "InventoryUI", -- [ASSUMED] expected inventory panel root ScreenGui name
				OnlineReward = "OnlineRewardUI", -- [ASSUMED] expected online reward panel root ScreenGui name
				Settings = "SettingsUI", -- [ASSUMED] expected settings panel root ScreenGui name
				Spin = "SpinUI", -- [ASSUMED] expected spin panel root ScreenGui name
			},
			LobbyTeleport = {
				MapName = "LobbyMap", -- [PROJECT_TREE_SPEC] Workspace.Maps.LobbyMap
				SpawnName = "SpawnPoint", -- [PROJECT_TREE_SPEC] Workspace.Maps.LobbyMap.SpawnPoints.SpawnPoint
			},
		},
		Inventory = {
			ScreenGui = "InventoryUI", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI
			MainHub = "InventoryUI.MainHub", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.MainHub
			ItemsGridContainer = "InventoryUI.MainHub.BodyItems.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.MainHub.BodyItems.GridContainer
			SlingsGridContainer = "InventoryUI.MainHub.BodySling.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.MainHub.BodySling.GridContainer
			SlingCapacityLabel = "InventoryUI.MainHub.BodySling.Footer.CapacityLabel", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.MainHub.BodySling.Footer.CapacityLabel
		},
		Match = {
			ScreenGui = "MatchUI", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI
			Root = "MatchUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame
			StatusLabel = "MatchUI.RootFrame.StatusLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.StatusLabel
			TimerLabel = "MatchUI.RootFrame.TimerLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.TimerLabel
			AlivePlayersLabel = "MatchUI.RootFrame.AlivePlayersLabel", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.AlivePlayersLabel
			WinnerPopup = "MatchUI.RootFrame.WinnerPopup", -- [PROJECT_TREE_SPEC] StarterGui.MatchUI.RootFrame.WinnerPopup
		},
		SlingTouch = {
			Container = "SlingArenaUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI
			ScreenGui = "SlingArenaUI.SlingUI", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI
			JoystickRoot = "SlingArenaUI.SlingUI.JoystickRoot", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.JoystickRoot
			JoystickBase = "SlingArenaUI.SlingUI.JoystickRoot.Base", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.JoystickRoot.Base
			JoystickThumb = "SlingArenaUI.SlingUI.JoystickRoot.Thumb", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.JoystickRoot.Thumb
			ChargeBar = "SlingArenaUI.SlingUI.ChargeBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.ChargeBar
			ChargeFill = "SlingArenaUI.SlingUI.ChargeBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.ChargeBar.Fill
			DirectionIndicator = "SlingArenaUI.SlingUI.DirectionIndicator", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.DirectionIndicator
			DirectionArrow = "SlingArenaUI.SlingUI.DirectionArrow", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.DirectionArrow (compatibility alias)
			CooldownBar = "SlingArenaUI.SlingUI.CooldownBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.CooldownBar
			CooldownFill = "SlingArenaUI.SlingUI.CooldownBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.CooldownBar.Fill
		},
	},
	Remotes = {
		Folder = "SlingArenaRemotes", -- [PROJECT_TREE_SPEC] ReplicatedStorage.SlingArenaRemotes
		MoveRequest = "SlingArenaRemotes.MoveRequest", -- [PROJECT_TREE_SPEC]
		StartCharge = "SlingArenaRemotes.StartCharge", -- [PROJECT_TREE_SPEC]
		ReleaseCharge = "SlingArenaRemotes.ReleaseCharge", -- [PROJECT_TREE_SPEC]
		JoinArena = "SlingArenaRemotes.JoinArena", -- [PROJECT_TREE_SPEC]
		LeaveArena = "SlingArenaRemotes.LeaveArena", -- [PROJECT_TREE_SPEC]
		TeleportRequest = "SlingArenaRemotes.TeleportRequest", -- [PROJECT_TREE_SPEC]
		AttributeUpgrade = "SlingArenaRemotes.AttributeUpgrade", -- [PROJECT_TREE_SPEC]
		RequestRespawn = "SlingArenaRemotes.RequestRespawn", -- [PROJECT_TREE_SPEC]
		PurchaseRespawn = "SlingArenaRemotes.PurchaseRespawn", -- [PROJECT_TREE_SPEC]
		PurchaseMatchBuff = "SlingArenaRemotes.PurchaseMatchBuff", -- [PROJECT_TREE_SPEC]
		PrestigeReset = "SlingArenaRemotes.PrestigeReset", -- [PROJECT_TREE_SPEC]
		ToggleSpecialUpgrade = "SlingArenaRemotes.ToggleSpecialUpgrade", -- [PROJECT_TREE_SPEC]
		DebugSpawnFood = "SlingArenaRemotes.DebugSpawnFood", -- [PROJECT_TREE_SPEC]
		DebugResetSling = "SlingArenaRemotes.DebugResetSling", -- [PROJECT_TREE_SPEC]
		ConsumeHpPotion = "SlingArenaRemotes.ConsumeHpPotion", -- [PROJECT_TREE_SPEC]
		StateUpdate = "SlingArenaRemotes.StateUpdate", -- [PROJECT_TREE_SPEC]
		UIStateUpdate = "SlingArenaRemotes.UIStateUpdate", -- [PROJECT_TREE_SPEC]
		GameplayFeedback = "SlingArenaRemotes.GameplayFeedback", -- [PROJECT_TREE_SPEC]
		MatchStateUpdate = "SlingArenaRemotes.MatchStateUpdate", -- [PROJECT_TREE_SPEC]
		RoundResult = "SlingArenaRemotes.RoundResult", -- [PROJECT_TREE_SPEC]
		PopupMessage = "SlingArenaRemotes.PopupMessage", -- [PROJECT_TREE_SPEC]
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
		--       SafeSpawnZone (BasePart)
		--       AntiGiantZone (BasePart)
		--       SizeRestrictedCorridor (BasePart)
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
		--   Slings (Folder)
		--     SlingModel (Model)
		--   Assets (Folder)
		--     UI (Folder)
		--       ItemSlotTemplate (Frame)
		--       SlingsSlotTemplate (Frame)
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
				ItemSlotTemplate = "Assets.UI.ItemSlotTemplate",
				SlingsSlotTemplate = "Assets.UI.SlingsSlotTemplate",
				Food1 = "Assets.Food.Food1",
				Food2 = "Assets.Food.Food2",
				Food3 = "Assets.Food.Food3",
				Food4 = "Assets.Food.Food4",
				Food5 = "Assets.Food.Food5",
				Food6 = "Assets.Food.Food6",
				Food7 = "Assets.Food.Food7",
				BasicTrap = "Assets.Trap.BasicTrap",
			},
			Slings = {
				SlingModel = "Slings.SlingModel",
			}
		},
	},
}

return ProjectTreeSpec
