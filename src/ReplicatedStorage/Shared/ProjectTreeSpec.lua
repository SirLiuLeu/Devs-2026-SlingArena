--!strict

local ProjectTreeSpec = {
	UI = {
		Lobby = {
			ScreenGui = "UnitTestUI", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI
			Root = "UnitTestUI.RootFrame", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI.RootFrame
			JoinButton = "UnitTestUI.RootFrame.JoinButton", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI.RootFrame.JoinButton
			LeaveButton = "UnitTestUI.RootFrame.LeaveButton", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI.RootFrame.LeaveButton
			StartSafeZoneButton = "UnitTestUI.RootFrame.StartSafeZoneButton", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI.RootFrame.StartSafeZoneButton
			DebugFoodButton = "UnitTestUI.RootFrame.DebugFood", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI.RootFrame.DebugFood
			DebugResetButton = "UnitTestUI.RootFrame.DebugReset", -- [PROJECT_TREE_SPEC] StarterGui.UnitTestUI.RootFrame.DebugReset
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
			ShopButton = "MainHUD.Root.LeftMenu.ShopButton", -- [ASSUMED] StarterGui.MainHUD.Root.LeftMenu.ShopButton
			QuickHP = "MainHUD.Root.QuickHP", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.QuickHP
			QuickHPCountLabel = "MainHUD.Root.QuickHP.CountLabel", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.QuickHP.CountLabel (TextLabel)
			HomeButton = "MainHUD.Root.Home", -- [INFERRED from PROJECT_TREE.md] StarterGui.MainHUD.Root.Home
			TeamIndicator = "MainHUD.Root.TeamIndicator", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.TeamIndicator (TextLabel)
			ExpProgress = {
				Root = "MainHUD.Root.ExpProress", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress
				Fill = "MainHUD.Root.ExpProress.ExpBarFill", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress.ExpBarFill
				ValueLabel = "MainHUD.Root.ExpProress.ExpValueLabel", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress.ExpValueLabel
				LevelLabel = "MainHUD.Root.ExpProress.LevelOnBarLabel", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress.LevelOnBarLabel
			},
			Panels = {
				SlingStats = "SlingStatsUI", -- [ASSUMED] expected sling stats panel root ScreenGui name
				DailyLogin = "DailyLoginUI", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI
				Shop = "ShopGui", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui
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
			Root = "InventoryUI.Root", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root
			BodyItems = "InventoryUI.Root.BodyItems", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems
			BodySling = "InventoryUI.Root.BodySling", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling
			ItemsTab = "InventoryUI.Root.Tabs.ItemsTab", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.Tabs.ItemsTab
			SlingTab = "InventoryUI.Root.Tabs.SlingTab", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.Tabs.SlingTab
			CloseButton = "InventoryUI.Root.Header.CloseButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.Header.CloseButton
			ItemsGridContainer = "InventoryUI.Root.BodyItems.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.GridContainer
			SlingsGridContainer = "InventoryUI.Root.BodySling.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.GridContainer
			BodySlingGridContainer = "InventoryUI.Root.BodySling.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.GridContainer
			SlingCapacityLabel = "InventoryUI.Root.BodySling.Footer.CapacityLabel", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.Footer.CapacityLabel
			ItemsSelectedName = "InventoryUI.Root.BodyItems.RightPanel.SelectedName", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.SelectedName
			ItemsUseButton = "InventoryUI.Root.BodyItems.RightPanel.ActionButtons.UseButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.ActionButtons.UseButton
			ItemsStat1 = "InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat1", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat1
			ItemsStat2 = "InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat2", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat2
			ItemsStat3 = "InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat3", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat3
			SlingSelectedName = "InventoryUI.Root.BodySling.RightPanel.SelectedName", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.SelectedName
			SlingEquipButton = "InventoryUI.Root.BodySling.RightPanel.ActionButtons.EquipButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.ActionButtons.EquipButton
			SlingDeleteButton = "InventoryUI.Root.BodySling.RightPanel.ActionButtons.DeleteButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.ActionButtons.DeleteButton
			SlingStatDamage = "InventoryUI.Root.BodySling.RightPanel.Stats.Damage", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.Stats.Damage
			SlingStatHP = "InventoryUI.Root.BodySling.RightPanel.Stats.HP", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.Stats.HP
			SlingStatRange = "InventoryUI.Root.BodySling.RightPanel.Stats.Range", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.Stats.Range
			SlingStatRegen = "InventoryUI.Root.BodySling.RightPanel.Stats.Regen", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodySling.RightPanel.Stats.Regen
		},
		OnlineReward = {
			ScreenGui = "OnlineRewardUI", -- [PROJECT_TREE_SPEC] StarterGui.OnlineRewardUI
			Root = "OnlineRewardUI.Root", -- [PROJECT_TREE_SPEC] StarterGui.OnlineRewardUI.Root
			Content = "OnlineRewardUI.Root.Content", -- [PROJECT_TREE_SPEC] StarterGui.OnlineRewardUI.Root.Content
			ClaimAll = "OnlineRewardUI.Root.Footer.ClaimAll", -- [PROJECT_TREE_SPEC] StarterGui.OnlineRewardUI.Root.Footer.ClaimAll
			SkipAll = "OnlineRewardUI.Root.Footer.SkipAll", -- [PROJECT_TREE_SPEC] StarterGui.OnlineRewardUI.Root.Footer.SkipAll
			CloseButton = "OnlineRewardUI.Root.Header.CloseButton", -- [PROJECT_TREE_SPEC] StarterGui.OnlineRewardUI.Root.Header.CloseButton
		},
		Shop = {
			ScreenGui = "ShopGui", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui
			Main = "ShopGui.Main", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main
			CloseButton = "ShopGui.Main.Close", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Close
			ItemsTabButton = "ShopGui.Main.Buttons.Items", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Buttons.Items
			LaunchersTabButton = "ShopGui.Main.Buttons.Launcher", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Buttons.Launcher
			DinamondsTabButton = "ShopGui.Main.Buttons.Dinamonds", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Buttons.Dinamonds
			ItemsScroll = "ShopGui.Main.Items.Content.ScrollingFrame", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Items.Content.ScrollingFrame
			LaunchersScroll = "ShopGui.Main.Launcher.Content.ScrollingFrame", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Launcher.Content.ScrollingFrame
			DinamondsScroll = "ShopGui.Main.Dinamonds.Content.ScrollingFrame", -- [PROJECT_TREE_SPEC] StarterGui.ShopGui.Main.Dinamonds.Content.ScrollingFrame
		},
		DailyLogin = {
			ScreenGui = "DailyLoginUI", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI
			MainPanel = "DailyLoginUI.MainPanel", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI.MainPanel
			CloseButton = "DailyLoginUI.MainPanel.Header.CloseButton", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI.MainPanel.Header.CloseButton
			OverlayButton = "DailyLoginUI.Overlay", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI.Overlay
			LeftGrid = "DailyLoginUI.MainPanel.Content.LeftGrid", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI.MainPanel.Content.LeftGrid
			Day7Big = "DailyLoginUI.MainPanel.Content.Day7Big", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI.MainPanel.Content.Day7Big
		},
		Spin = {
			ScreenGui = "SpinUI", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI
			Root = "SpinUI.Root", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI.Root
			Wheel = "SpinUI.Root.WheelContainer.GachaWheel", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI.Root.WheelContainer.GachaWheel
			Pointer = "SpinUI.Root.WheelContainer.Pointer", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI.Root.WheelContainer.Pointer
			Spin1 = "SpinUI.Root.Buttons.Spin1", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI.Root.Buttons.Spin1
			Spin2 = "SpinUI.Root.Buttons.Spin2", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI.Root.Buttons.Spin2
			CloseButton = "SpinUI.Root.CloseButton", -- [PROJECT_TREE_SPEC] StarterGui.SpinUI.Root.CloseButton
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
			CooldownBar = "SlingArenaUI.SlingUI.CooldownBar", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.CooldownBar
			CooldownFill = "SlingArenaUI.SlingUI.CooldownBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.SlingArenaUI.SlingUI.CooldownBar.Fill
		},
	},
	Remotes = {
		Folder = "SlingArenaRemotes", -- [PROJECT_TREE_SPEC] ReplicatedStorage.SlingArenaRemotes
		MoveRequest = "SlingArenaRemotes.MoveRequest", -- [PROJECT_TREE_SPEC]
		StartCharge = "SlingArenaRemotes.StartCharge", -- [PROJECT_TREE_SPEC]
		ReleaseCharge = "SlingArenaRemotes.ReleaseCharge", -- [PROJECT_TREE_SPEC]
		RequestLaunch = "SlingArenaRemotes.RequestLaunch", -- [PROJECT_TREE_SPEC]
		AbilityTrigger = "SlingArenaRemotes.AbilityTrigger", -- [PROJECT_TREE_SPEC]
		JoinArena = "SlingArenaRemotes.JoinArena", -- [PROJECT_TREE_SPEC]
		LeaveArena = "SlingArenaRemotes.LeaveArena", -- [PROJECT_TREE_SPEC]
		StartSafeZone = "SlingArenaRemotes.StartSafeZone", -- [PROJECT_TREE_SPEC]
		TeleportRequest = "SlingArenaRemotes.TeleportRequest", -- [PROJECT_TREE_SPEC]
		AttributeUpgrade = "SlingArenaRemotes.AttributeUpgrade", -- [PROJECT_TREE_SPEC]
		RequestRespawn = "SlingArenaRemotes.RequestRespawn", -- [PROJECT_TREE_SPEC]
		PurchaseRespawn = "SlingArenaRemotes.PurchaseRespawn", -- [PROJECT_TREE_SPEC]
		PurchaseMatchBuff = "SlingArenaRemotes.PurchaseMatchBuff", -- [PROJECT_TREE_SPEC]
		PrestigeReset = "SlingArenaRemotes.PrestigeReset", -- [PROJECT_TREE_SPEC]
		DebugSpawnFood = "SlingArenaRemotes.DebugSpawnFood", -- [PROJECT_TREE_SPEC]
		DebugResetSling = "SlingArenaRemotes.DebugResetSling", -- [PROJECT_TREE_SPEC]
		ConsumeHpPotion = "SlingArenaRemotes.ConsumeHpPotion", -- [PROJECT_TREE_SPEC]
		ReportFoodHit = "SlingArenaRemotes.ReportFoodHit", -- [PROJECT_TREE_SPEC]
		ReportCollision = "SlingArenaRemotes.ReportCollision", -- [PROJECT_TREE_SPEC]
		ClientDoLaunch = "SlingArenaRemotes.ClientDoLaunch", -- [PROJECT_TREE_SPEC]
		StateUpdate = "SlingArenaRemotes.StateUpdate", -- [PROJECT_TREE_SPEC]
		UIStateUpdate = "SlingArenaRemotes.UIStateUpdate", -- [PROJECT_TREE_SPEC]
		GameplayFeedback = "SlingArenaRemotes.GameplayFeedback", -- [PROJECT_TREE_SPEC]
		MatchStateUpdate = "SlingArenaRemotes.MatchStateUpdate", -- [PROJECT_TREE_SPEC]
		RoundResult = "SlingArenaRemotes.RoundResult", -- [PROJECT_TREE_SPEC]
		PopupMessage = "SlingArenaRemotes.PopupMessage", -- [PROJECT_TREE_SPEC]
		ZoneUpdate = "SlingArenaRemotes.ZoneUpdate", -- [PROJECT_TREE_SPEC]
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
		--       GachaSpin (Model)
		--       Gate (Part)
		--     Arena_01 (Model)
		--       SpawnPoints (Folder)
		--         SpawnPoint_01..N (Part)
		--         RedSpawn (SpawnLocation | Part)
		--         BlueSpawn (SpawnLocation | Part)
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
		--   Assets (Folder)
		--     Slings (Folder)
		--       NormalSling (Model default)
		--   Assets (Folder)
		--     UI (Folder)
		--       ItemSlotTemplate (Frame)
		--       SlingSlotTemplate (Frame)
		--     Slings (Folder)
		--       SupportSling, StunSling, NormalSling, VacuumSling, StealthSling, HealSling, SpeedSling, BonusBuffSling, PetrifySling, FireSling, PoisonSling
		--     Food (Folder)
		--       BasicFood (Model) [fallback]
		--		 Food1, Food2, Food3, ...Food7 (Model)
		--     Trap (Folder)
		--       BasicTrap (Model) [fallback]
		--
		-- Teams
		--   TeamRed (Team)
		--   TeamBlue (Team)
		Workspace = {
			SlingPawns = "SlingPawns",
			Maps = {
				Root = "Maps",
				LobbyMap = "Maps.LobbyMap",
				GachaSpin = "Maps.LobbyMap.GachaSpin",
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
				SlingSlotTemplate = "Assets.UI.SlingSlotTemplate",
				RewardSlotTemplate = "Assets.UI.RewardSlotTemplate",
				SlingWorldUI = "Assets.UI.SlingWorldUI",
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
				SupportSling = "Assets.Slings.SupportSling",
				StunSling = "Assets.Slings.StunSling",
				NormalSling = "Assets.Slings.NormalSling",
				VacuumSling = "Assets.Slings.VacuumSling",
				StealthSling = "Assets.Slings.StealthSling",
				HealSling = "Assets.Slings.HealSling",
				SpeedSling = "Assets.Slings.SpeedSling",
				BonusBuffSling = "Assets.Slings.BonusBuffSling",
				PetrifySling = "Assets.Slings.PetrifySling",
				FireSling = "Assets.Slings.FireSling",
				PoisonSling = "Assets.Slings.PoisonSling",
			}
		},
	},
	World = {
		GachaSpin = {
			Model = "Maps.LobbyMap.GachaSpin", -- [PROJECT_TREE_SPEC] Workspace.Maps.LobbyMap.GachaSpin
		},
	},
}

return ProjectTreeSpec
