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
			LauncherStatsButton = "MainHUD.Root.LauncherStatsButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LauncherStatsButton
			DailyButton = "MainHUD.Root.LeftMenu.DailyButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.DailyButton
			InventoryButton = "MainHUD.Root.LeftMenu.InventoryButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.InventoryButton
			OnlineRewardButton = "MainHUD.Root.LeftMenu.OnlineRewardButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.OnlineRewardButton
			SettingButton = "MainHUD.Root.LeftMenu.SettingButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.SettingButton
			SpinButton = "MainHUD.Root.LeftMenu.SpinButton", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.LeftMenu.SpinButton
			ShopButton = "MainHUD.Root.LeftMenu.ShopButton", -- [ASSUMED] StarterGui.MainHUD.Root.LeftMenu.ShopButton
			QuickHP = "MainHUD.Root.QuickHP", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.QuickHP
			QuickHPQuantity = "MainHUD.Root.QuickHP.Quantity", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.QuickHP.Quantity (TextLabel)
			HomeButton = "MainHUD.Root.Home", -- [INFERRED from PROJECT_TREE.md] StarterGui.MainHUD.Root.Home
			TeamIndicator = "MainHUD.Root.TeamIndicator", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.TeamIndicator (TextLabel)
			ExpProgress = {
				Root = "MainHUD.Root.ExpProress", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress
				Fill = "MainHUD.Root.ExpProress.ExpBar.ExpBarFill", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress.ExpBar.ExpBarFill
				ValueLabel = "MainHUD.Root.ExpProress.ExpValueLabel", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress.ExpValueLabel
				LevelLabel = "MainHUD.Root.ExpProress.LevelOnBarLabel", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.ExpProress.LevelOnBarLabel
			},
			DiamondValue = "MainHUD.Root.Diamond.Value", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.Diamond.Value
			BuffContainer = {
				Root = "MainHUD.Root.BuffContainer", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer
				DamageBuff = "MainHUD.Root.BuffContainer.DamageBuff", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer.DamageBuff
				DamageValueText = "MainHUD.Root.BuffContainer.DamageBuff.ValueText", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer.DamageBuff.ValueText
				ExpBuff = "MainHUD.Root.BuffContainer.ExpBuff", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer.ExpBuff
				ExpValueText = "MainHUD.Root.BuffContainer.ExpBuff.ValueText", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer.ExpBuff.ValueText
				HPRecovery = "MainHUD.Root.BuffContainer.HPRecovery", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer.HPRecovery
				HPRecoveryTime = "MainHUD.Root.BuffContainer.HPRecovery.Time", -- [PROJECT_TREE_SPEC] StarterGui.MainHUD.Root.BuffContainer.HPRecovery.Time
			},
			Panels = {
				LauncherStats = "LauncherStatsUI", -- [ASSUMED] expected launcher stats panel root ScreenGui name
				DailyLogin = "DailyLoginUI", -- [PROJECT_TREE_SPEC] StarterGui.DailyLoginUI
				Shop = "ShopUI", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI
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
			BodyLauncher = "InventoryUI.Root.BodyLauncher", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher
			ItemsTab = "InventoryUI.Root.Tabs.ItemsTab", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.Tabs.ItemsTab
			LauncherTab = "InventoryUI.Root.Tabs.LauncherTab", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.Tabs.LauncherTab
			CloseButton = "InventoryUI.Root.Header.CloseButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.Header.CloseButton
			ItemsGridContainer = "InventoryUI.Root.BodyItems.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.GridContainer
			LaunchersGridContainer = "InventoryUI.Root.BodyLauncher.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.GridContainer
			BodyLauncherGridContainer = "InventoryUI.Root.BodyLauncher.GridContainer", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.GridContainer
			LauncherCapacityLabel = "InventoryUI.Root.BodyLauncher.Footer.CapacityLabel", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.Footer.CapacityLabel
			ItemsSelectedName = "InventoryUI.Root.BodyItems.RightPanel.SelectedName", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.SelectedName
			ItemsUseButton = "InventoryUI.Root.BodyItems.RightPanel.ActionButtons.UseButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.ActionButtons.UseButton
			ItemsStat1 = "InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat1", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat1
			ItemsStat2 = "InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat2", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat2
			ItemsStat3 = "InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat3", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyItems.RightPanel.Stats.ItemStat3
			LauncherSelectedName = "InventoryUI.Root.BodyLauncher.RightPanel.SelectedName", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.SelectedName
			LauncherEquipButton = "InventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.EquipButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.EquipButton
			LauncherDeleteButton = "InventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.DeleteButton", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.DeleteButton
			LauncherStatDamage = "InventoryUI.Root.BodyLauncher.RightPanel.Stats.Damage", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.Stats.Damage
			LauncherStatHP = "InventoryUI.Root.BodyLauncher.RightPanel.Stats.HP", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.Stats.HP
			LauncherStatRange = "InventoryUI.Root.BodyLauncher.RightPanel.Stats.Range", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.Stats.Range
			LauncherStatRegen = "InventoryUI.Root.BodyLauncher.RightPanel.Stats.Regen", -- [PROJECT_TREE_SPEC] StarterGui.InventoryUI.Root.BodyLauncher.RightPanel.Stats.Regen
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
			ScreenGui = "ShopUI", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI
			Main = "ShopUI.Main", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main
			CloseButton = "ShopUI.Main.Close", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Close
			ItemsTabButton = "ShopUI.Main.Buttons.Items", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Buttons.Items
			LaunchersTabButton = "ShopUI.Main.Buttons.Launcher", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Buttons.Launcher
			DinamondsTabButton = "ShopUI.Main.Buttons.Dinamonds", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Buttons.Dinamonds
			ItemsScroll = "ShopUI.Main.Items.Content.ScrollingFrame", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Items.Content.ScrollingFrame
			LaunchersScroll = "ShopUI.Main.Launcher.Content.ScrollingFrame", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Launcher.Content.ScrollingFrame
			DinamondsScroll = "ShopUI.Main.Dinamonds.Content.ScrollingFrame", -- [PROJECT_TREE_SPEC] StarterGui.ShopUI.Main.Dinamonds.Content.ScrollingFrame
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
		LauncherTouch = {
			Container = "LauncherArenaUI", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI
			ScreenGui = "LauncherArenaUI.LauncherUI", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI
			JoystickRoot = "LauncherArenaUI.LauncherUI.JoystickRoot", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.JoystickRoot
			JoystickBase = "LauncherArenaUI.LauncherUI.JoystickRoot.Base", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.JoystickRoot.Base
			JoystickThumb = "LauncherArenaUI.LauncherUI.JoystickRoot.Thumb", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.JoystickRoot.Thumb
			ChargeBar = "LauncherArenaUI.LauncherUI.ChargeBar", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.ChargeBar
			ChargeFill = "LauncherArenaUI.LauncherUI.ChargeBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.ChargeBar.Fill
			DirectionIndicator = "LauncherArenaUI.LauncherUI.DirectionIndicator", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.DirectionIndicator
			CooldownBar = "LauncherArenaUI.LauncherUI.CooldownBar", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.CooldownBar
			CooldownFill = "LauncherArenaUI.LauncherUI.CooldownBar.Fill", -- [PROJECT_TREE_SPEC] StarterGui.LauncherArenaUI.LauncherUI.CooldownBar.Fill
		},
	},
	Remotes = {
		Folder = "LauncherArenaRemotes", -- [PROJECT_TREE_SPEC] ReplicatedStorage.LauncherArenaRemotes
		MoveRequest = "LauncherArenaRemotes.MoveRequest", -- [PROJECT_TREE_SPEC]
		StartCharge = "LauncherArenaRemotes.StartCharge", -- [PROJECT_TREE_SPEC]
		ReleaseCharge = "LauncherArenaRemotes.ReleaseCharge", -- [PROJECT_TREE_SPEC]
		RequestLaunch = "LauncherArenaRemotes.RequestLaunch", -- [PROJECT_TREE_SPEC]
		AbilityTrigger = "LauncherArenaRemotes.AbilityTrigger", -- [PROJECT_TREE_SPEC]
		JoinArena = "LauncherArenaRemotes.JoinArena", -- [PROJECT_TREE_SPEC]
		LeaveArena = "LauncherArenaRemotes.LeaveArena", -- [PROJECT_TREE_SPEC]
		StartSafeZone = "LauncherArenaRemotes.StartSafeZone", -- [PROJECT_TREE_SPEC]
		TeleportRequest = "LauncherArenaRemotes.TeleportRequest", -- [PROJECT_TREE_SPEC]
		AttributeUpgrade = "LauncherArenaRemotes.AttributeUpgrade", -- [PROJECT_TREE_SPEC]
		RequestRespawn = "LauncherArenaRemotes.RequestRespawn", -- [PROJECT_TREE_SPEC]
		PurchaseRespawn = "LauncherArenaRemotes.PurchaseRespawn", -- [PROJECT_TREE_SPEC]
		PurchaseMatchBuff = "LauncherArenaRemotes.PurchaseMatchBuff", -- [PROJECT_TREE_SPEC]
		PrestigeReset = "LauncherArenaRemotes.PrestigeReset", -- [PROJECT_TREE_SPEC]
		DebugSpawnFood = "LauncherArenaRemotes.DebugSpawnFood", -- [PROJECT_TREE_SPEC]
		DebugResetLauncher = "LauncherArenaRemotes.DebugResetLauncher", -- [PROJECT_TREE_SPEC]
		ConsumeHpPotion = "LauncherArenaRemotes.ConsumeHpPotion", -- [PROJECT_TREE_SPEC]
		ReportFoodHit = "LauncherArenaRemotes.ReportFoodHit", -- [PROJECT_TREE_SPEC]
		ReportCollision = "LauncherArenaRemotes.ReportCollision", -- [PROJECT_TREE_SPEC]
		ClientDoLaunch = "LauncherArenaRemotes.ClientDoLaunch", -- [PROJECT_TREE_SPEC]
		StateUpdate = "LauncherArenaRemotes.StateUpdate", -- [PROJECT_TREE_SPEC]
		UIStateUpdate = "LauncherArenaRemotes.UIStateUpdate", -- [PROJECT_TREE_SPEC]
		GameplayFeedback = "LauncherArenaRemotes.GameplayFeedback", -- [PROJECT_TREE_SPEC]
		MatchStateUpdate = "LauncherArenaRemotes.MatchStateUpdate", -- [PROJECT_TREE_SPEC]
		RoundResult = "LauncherArenaRemotes.RoundResult", -- [PROJECT_TREE_SPEC]
		PopupMessage = "LauncherArenaRemotes.PopupMessage", -- [PROJECT_TREE_SPEC]
		ZoneUpdate = "LauncherArenaRemotes.ZoneUpdate", -- [PROJECT_TREE_SPEC]
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
		--     Launchers (Folder)
		--       NormalLauncher (Model default)
		--   Assets (Folder)
		--     UI (Folder)
		--       ItemSlotTemplate_InventoryUI (Frame)
		--       LauncherSlotTemplate_InventoryUI (Frame)
		--     Launchers (Folder)
		--       SupportLauncher, StunLauncher, NormalLauncher, VacuumLauncher, StealthLauncher, HealLauncher, SpeedLauncher, BonusBuffLauncher, PetrifyLauncher, FireLauncher, PoisonLauncher
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
			LauncherPawns = "LauncherPawns",
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
				ItemSlotTemplate_InventoryUI = "Assets.UI.ItemSlotTemplate_InventoryUI",
				LauncherSlotTemplate_InventoryUI = "Assets.UI.LauncherSlotTemplate_InventoryUI",
				SlotRewardTemplate_DailyLoginUI = "Assets.UI.SlotRewardTemplate_DailyLoginUI",
				SlotItemsTemplate_ShopUI = "Assets.UI.SlotItemsTemplate_ShopUI",
				SlotLaucherTemplate_shopUI = "Assets.UI.SlotLaucherTemplate_shopUI",
				SlotDiamondPackTemplate_ShopUI = "Assets.UI.SlotDiamondPackTemplate_ShopUI",
				SlotRewardTemplate_OnlineRewardUI = "Assets.UI.SlotRewardTemplate_OnlineRewardUI",
				LauncherWorldUI = "Assets.UI.LauncherWorldUI",
				Food1 = "Assets.Food.Food1",
				Food2 = "Assets.Food.Food2",
				Food3 = "Assets.Food.Food3",
				Food4 = "Assets.Food.Food4",
				Food5 = "Assets.Food.Food5",
				Food6 = "Assets.Food.Food6",
				Food7 = "Assets.Food.Food7",
				BasicTrap = "Assets.Trap.BasicTrap",
				StunEffect = "Assets.Launchers.Player.Hitbox.EffectHead.Stun",
				BurnEffect = "Assets.Launchers.Player.Hitbox.EffectOrigin.Burn",
				FrostEffect = "Assets.Launchers.Player.Hitbox.EffectOrigin.Frost",
				PoisonEffect = "Assets.Launchers.Player.Hitbox.EffectOrigin.Poison",
			},
			Launchers = {
				SupportLauncher = "Assets.Launchers.SupportLauncher",
				StunLauncher = "Assets.Launchers.StunLauncher",
				NormalLauncher = "Assets.Launchers.NormalLauncher",
				VacuumLauncher = "Assets.Launchers.VacuumLauncher",
				StealthLauncher = "Assets.Launchers.StealthLauncher",
				HealLauncher = "Assets.Launchers.HealLauncher",
				SpeedLauncher = "Assets.Launchers.SpeedLauncher",
				BonusBuffLauncher = "Assets.Launchers.BonusBuffLauncher",
				PetrifyLauncher = "Assets.Launchers.PetrifyLauncher",
				FireLauncher = "Assets.Launchers.FireLauncher",
				PoisonLauncher = "Assets.Launchers.PoisonLauncher",
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
