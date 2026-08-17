
DataModel
## 🟦 ReplicatedStorage
├─ ReplicatedStorage
│  │  └─ FoodModels
│  │     ├─ CommonBlue
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ CommonGreen
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ CommonRed
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ EpicViolet
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ LegendaryGold
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ RareAmber
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ UncommonIce
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │
│  ├─ Shared  -> src/ReplicatedStorage/Shared
│  │  ├─ Config
│  │  │  ├─ AbilityConfig.lua
│  │  │  ├─ BalanceConfig.lua
│  │  │  ├─ Config.lua
│  │  │  ├─ EquipmentConfig.lua
│  │  │  ├─ EquipmentUpgradeConfig.lua
│  │  │  ├─ FoodConfig.lua
│  │  │  ├─ GachaRewardConfig.lua
│  │  │  ├─ GameConfig.lua
│  │  │  ├─ ItemConfig.lua
│  │  │  ├─ LevelConfig.lua
│  │  │  ├─ LauncherConfig.lua
│  │  │  ├─ LaunchershotConfig.lua
│  │  │  └─ TrapConfig.lua
│  │  │
│  │  ├─ Constants
│  │  │  ├─ GameStates.lua
│  │  │  └─ LauncherUiConstants.lua
│  │  │
│  │  ├─ Types
│  │  │  ├─ CombatTypes.lua
│  │  │  └─ PlayerState.lua
│  │  │
│  │  ├─ Utils
│  │  │  ├─ EquipmentStatResolver.lua
│  │  │  ├─ GachaSpinLogic.lua
│  │  │  ├─ PathResolver.lua
│  │  │  ├─ RewardRoller.lua
│  │  │  ├─ LauncherUiState.lua
│  │  │  └─ WaitForUI.lua
│  │  ├─ ProjectTreeSpec.lua
│  │  └─ RemoteContracts.lua
│  │
│  ├─ Assets
│  │  ├── Prefabs
│  │  │   └── ArrowModel (Model)
│  │  │       ├── EndAttachment (Attachment)
│  │  │       ├── StartAttachment (Attachment)
│  │  │       └── Arrow (MeshPart/Part)
│  │  │
│  │  ├── Equipment
│  │  │  ├── Poison (Model)
│  │  │  ├── GhostFlame (Model)
│  │  │  ├── PowerCore (Model)
│  │  │  ├── BrainBoost (Model)
│  │  │  ├── ThunderHammer (Model)
│  │  │  └── Medusa (Model)
│  │  │
│  │  ├── Launchers
│  │  │  ├── Player (Character Default)
│  │  │  │  ├── Trail
│  │  │  │  ├── WeldConstraint_HitboxRootPart
│  │  │  │  ├── EquippedLauncherModel (Launcher_Template)
│  │  │  │  │  ├── RootPart
│  │  │  │  │  └── Mesh
│  │  │  │  ├── Hitbox (PrimaryPart)
│  │  │  │  │  ├── AlignOrientation
│  │  │  │  │  ├── AttachmentOrientation (Attachment)
│  │  │  │  │  ├── EffectHead (Attachment)
│  │  │  │  │  │  └── Stun (ParticleEmitter)
│  │  │  │  │  ├── EffectOrigin (Attachment)
│  │  │  │  │  │  ├── Burn (Fire)
│  │  │  │  │  │  ├── Frost (ParticleEmitter)
│  │  │  │  │  │  └── Poison (Smoke)
│  │  │  │  │  ├── LinearVelocity
│  │  │  │  │  ├── LauncherMovementAttachment (Attachment)
│  │  │  │  │  ├── EquipmentSlot1 (Attachment)
│  │  │  │  │  ├── EquipmentSlot2 (Attachment)
│  │  │  │  │  ├── EquipmentSlot3 (Attachment)
│  │  │  │  │  ├── TrailEnd (Attachment)
│  │  │  │  │  └── TrailStart (Attachment)
│  │  │  │  └── LauncherWorldUI
│  │  │  │     ├── UIListLayout
│  │  │  │     ├── HpBarBackground
│  │  │  │     │  ├── UICorner
│  │  │  │     │  └── HpBarFill
│  │  │  │     ├── LevelLabel
│  │  │  │     └── Name
│  │  │  │
│  │  │  ├── Launcher_Template (Model structure reference only)
│  │  │  │  ├── RootPart
│  │  │  │  └── Mesh (MeshPart)
│  │  │  │  
│  │  │  ├── SupportLauncher (Launcher_Template format)
│  │  │  ├── StunLauncher (Launcher_Template format)
│  │  │  ├── NormalLauncher (Launcher_Template format; default launcher)
│  │  │  ├── VacuumLauncher (Launcher_Template format)
│  │  │  ├── StealthLauncher (Launcher_Template format)
│  │  │  ├── HealLauncher (Launcher_Template format)
│  │  │  ├── SpeedLauncher (Launcher_Template format)
│  │  │  ├── BonusBuffLauncher (Launcher_Template format)
│  │  │  ├── FreezeLauncher (Launcher_Template format) -- sẽ delete trong tương lai
│  │  │  ├── PetrifyLauncher (Launcher_Template format) -- new update, replace FreezeLauncher
│  │  │  ├── FireLauncher (Launcher_Template format)
│  │  │  └── PoisonLauncher (Launcher_Template format)
│  │  │
│  │  ├── Icons
│  │  │   ├── Items
│  │  │   │   ├── HP_Potion (Image)
│  │  │   │   ├── Gacha_Ticket (Image)
│  │  │   │   └── EXP_Buff (Image)
│  │  │   │
│  │  │   └── Launchers
│  │  │       └── Launcher icons for the canonical 11 launcher ids (Image)
│  │  │
│  │  └── UI
│  │      ├── FloatingDamage (BillboardGui)
│  │      │   └── Value (TextLabel)
│  │      │   
│  │      ├── FoodWorldUI (BillboardGui)
│  │      │   └── HpBarBackground (Frame)
│  │      │       ├── UICorner
│  │      │       └── HpBarFill (Frame)
│  │      │
│  │      ├── ItemotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── UICorner
│  │      │       ├── Icon (ImageLabel)
│  │      │       ├── Name (TextLabel)
│  │      │       └── Quantity (TextLabel)
│  │      │
│  │      ├── LauncherSlotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── Stars (Frame)
│  │      │       │   ├── Star1 (ImageLabel)
│  │      │       │   ├── Star2 (ImageLabel)
│  │      │       │   ├── Star3 (ImageLabel)
│  │      │       │   ├── Star4 (ImageLabel)
│  │      │       │   └── Star5 (ImageLabel)
│  │      │       ├── Icon (ImageLabel)
│  │      │       ├── EquippedTag (TextLabel)
│  │      │       ├── Level (TextLabel)
│  │      │       └── Name (TextLabel)
│  │      │
│  │      ├── LauncherSlotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── RemainingTimeText (TextLabel)
│  │      │       ├── Icon (ImageLabel)
│  │      │       ├── EquippedTag (TextLabel)
│  │      │       ├── Level (TextLabel)
│  │      │       └── Name (TextLabel)
│  │      │
│  │      ├── SlotRewardTemplate_DailyLoginUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── UIStroke
│  │      │   ├── ClaimButton (TextButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   ├── Claimed (TextLabel)
│  │      │   ├── Quantity (TextLabel)
│  │      │   ├── Timer (TextLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── PlayerRowTemplate_TopRank100 (Frame)
│  │      │   ├── UICorner
│  │      │   ├── UIListLayout
│  │      │   ├── NameValue (TextLabel)
│  │      │   ├── PointValue (TextLabel)
│  │      │   └── RankValue (TextLabel)
│  │      │
│  │      ├── PlayerRowTemplate_MatchScoreboardUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── UIListLayout
│  │      │   ├── KillValue (TextLabel)
│  │      │   ├── LevelValue (TextLabel)
│  │      │   ├── NameValue (TextLabel)
│  │      │   ├── PointValue (TextLabel)
│  │      │   └── StateValue (TextLabel)
│  │      │
│  │      ├── PlayerRowTemplate_MatchSummaryUI (Frame)
│  │      │   ├── UIListLayout
│  │      │   ├── Deaths
│  │      │   ├── Kills
│  │      │   ├── Level
│  │      │   ├── PlayerName
│  │      │   ├── Points
│  │      │   ├── Rank
│  │      │   └── Reward
│  │      │
│  │      ├── SlotItemsTemplate_ShopUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── InfoButton (ImageButton)
│  │      │   ├── BuyButton (TextButton/ImageButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   ├── Quantity (TextLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── SlotLauncherTemplate_shopUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── InfoButton (ImageButton)
│  │      │   ├── BuyButton (TextButton/ImageButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── SlotDiamondPackTemplate_ShopUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── BuyButton (TextButton/ImageButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   ├── Description (TextLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── QuestRowTemplate_QuestUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── ProgressBarBox
│  │      │   ├── ClaimButton
│  │      │   ├── QuestIcon
│  │      │   └── QuestDesc
│  │      │
│  │      ├── LauncherWorldUI (BillboardGui)
│  │      │   ├── UIListLayout
│  │      │   ├── HpBarBackground (Frame)
│  │      │   │   ├── UICorner
│  │      │   │   └── HpBarFill (Frame)
│  │      │   ├── NameLabel (TextLabel)
│  │      │   └── LevelLabel (TextLabel)
│  │      │
│  │      └─ SlotRewardTemplate_OnlineRewardUI (Frame)
│  │          ├─ UICorner
│  │          ├─ ClaimButton (TextButton)
│  │          ├─ Icon (ImageLabel)
│  │          ├─ Claimed (TextLabel)
│  │          ├─ Quantity (TextLabel)
│  │          └─ Timer (TextLabel)
│  │
│  ├─ LauncherArenaRemotes
│  │  └─ (RemoteEvents from *.model.json + freeze contracts)
│  │     ├─ MoveRequest
│  │     ├─ StartCharge
│  │     ├─ ReleaseCharge
│  │     ├─ ClientDoLaunch
│  │     ├─ RequestLaunch [CONTRACT ALIAS / freeze-required]
│  │     ├─ JoinArena
│  │     ├─ LeaveArena
│  │     ├─ TeleportRequest
│  │     ├─ AbilityTrigger [freeze-required]
│  │     ├─ AttributeUpgrade
│  │     ├─ ConsumeHpPotion
│  │     ├─ RequestRespawn
│  │     ├─ PurchaseRespawn
│  │     ├─ PurchaseMatchBuff
│  │     ├─ PrestigeReset
│  │     ├─ DebugSpawnFood
│  │     ├─ DebugResetLauncher
│  │     ├─ StateUpdate
│  │     ├─ UIStateUpdate
│  │     ├─ GameplayFeedback
│  │     ├─ MatchStateUpdate
│  │     ├─ RoundResult
│  │     ├─ PopupMessage
│  │     ├─ SetPlayerMode
│  │     └─ ZoneUpdate [freeze-required]
│  │
│  └─ Client  -> src/ReplicatedStorage/Client
│     ├─ Controllers
│     │  └─ UIController.lua
│     └─ Services
│        └─ LobbyClientService.lua 
│ 
## 🟥 ServerScriptService
├─ ServerScriptService  -> src/ServerScriptService
│  ├─ Main.server.lua
│  ├─ Config
│  ├─ Tests
│  │  └─ EquipmentFoundationTests.server.lua
│  └─ Services
│     ├─ EquipmentService
│     │  └─ EquipmentService.lua
│     └─ EquipmentEffectService
│        ├─ EquipmentEffectService.lua
│        └─ EquipmentEffects
│           └─ NoOp.lua
## 🟩 StarterPlayer
├─ StarterPlayer
│  └─ StarterPlayerScripts
│     ├─ CameraController.client.lua                 (Camera)
│     ├─ CollisionClientScanner.client.lua
│     ├─ FoodWorldUI.client.lua
│     ├─ InputController.client.lua                  (Active input / charge script)
│     ├─ KnockbackReplicationClient.client.lua
│     ├─ LaunchImpulseClient.client.lua
│     ├─ LauncherUIController.client.lua             (Resolves LauncherUI ScreenGui)
│     ├─ PlayerModeController.client.lua
│     ├─ SafeZoneVisualizer.client.lua
│     ├─ UIBinder.client.lua                         (UI bootstrap; event-driven rebinding)
│     └─ Components
│        ├─ AttributePanel.lua
│        ├─ BuffPanel.lua
│        ├─ ChargeBar.lua
│        ├─ CooldownOverlayComponent.lua
│        ├─ CooldownTextComponent.lua
│        ├─ DiamondDisplay.lua
│        ├─ HealthBar.lua
│        ├─ HUD.lua
│        ├─ LeaderboardUI.lua
│        ├─ RespawnPanel.lua
│        └─ SkillButton.lua
│
## 🟨 StarterGui
├─ StarterGui  -> src/StarterGui
│  ├─ UnitTestUI (ScreenGui)
│  │  └─ RootFrame
│  │     ├─ DebugFood
│  │     ├─ DebugReset
│  │     ├─ JoinButton
│  │     ├─ LeaveButton
│  │     ├─ Plus1Minute
│  │     ├─ EndRound
│  │     └─ StartSafeZoneButton
│  │
│  ├─ NotificationGui (ScreenGui)
│  │  ├─ ToastContainer
│  │  │  └─ UIListLayout
│  │  └─ ToastTemplate
│  │     ├─ UICorner
│  │     ├─ UIPadding
│  │     ├─ Icon
│  │     └─ Message
│  │
│  ├─ QuestUI (ScreenGui)
│  │  └─ Root
│  │     ├─ Content_ScrollFrame
│  │     │  ├─ UIListLayout
│  │     │  └─ QuestTemplate
│  │     │     ├─ UICorner
│  │     │     ├─ ProgressBarBox
│  │     │     │  ├─ UICorner
│  │     │     │  ├─ Fill
│  │     │     │  └─ ProgressText
│  │     │     ├─ ClaimButton
│  │     │     ├─ QuestIcon
│  │     │     └─ QuestDesc
│  │     ├─ TabContainer
│  │     │  ├─ UIListLayout
│  │     │  ├─ Tab_Daily
│  │     │  └─ Tab_Main
│  │     ├─ CloseButton
│  │     ├─ Background
│  │     └─ Header
│  │
│  ├─ MatchScoreboardUI (ScreenGui)
│  │  ├─ MainPanel (Frame)
│  │  │  ├─ UICorner
│  │  │  ├─ UIPadding
│  │  │  ├─ ColumnHeader (Frame)
│  │  │  │  ├─ UICorner
│  │  │  │  ├─ UIListLayout
│  │  │  │  ├─ KillHeader (TextLabel)
│  │  │  │  ├─ LevelHeader (TextLabel)
│  │  │  │  ├─ NameHeader (TextLabel)
│  │  │  │  ├─ PointHeader (TextLabel)
│  │  │  │  └─ StateHeader (TextLabel)
│  │  │  ├─ Header (Frame)
│  │  │  │  └─ CloseButton (TextButton)
│  │  │  └─ PlayerList (ScrollingFrame)
│  │  │     ├─ UIListLayout
│  │  │     ├─ UIPadding
│  │  │     └─ PlayerRowTemplate_MatchScoreboardUI (Frame)
│  │  └─ Overlay (Frame)
│  │
│  ├─ MatchSummaryUI (ScreenGui)
│  │  ├─ MainPanel (Frame)
│  │  │  ├─ Header (Frame)
│  │  │  │  └─ CloseButton (TextButton)
│  │  │  └─ Table (Frame)
│  │  │     ├─ UICorner
│  │  │     ├─ UIListLayout
│  │  │     ├─ HeaderRow (Frame)
│  │  │     │  ├─ UIListLayout
│  │  │     │  ├─ Dead (TextLabel)
│  │  │     │  ├─ Kill (TextLabel)
│  │  │     │  ├─ Level (TextLabel)
│  │  │     │  ├─ Name (TextLabel)
│  │  │     │  ├─ Point (TextLabel)
│  │  │     │  ├─ Rank (TextLabel)
│  │  │     │  └─ Reward (TextLabel)
│  │  │     └─ PlayerList (ScrollingFrame)
│  │  │        ├─ UIListLayout
│  │  │        └─ PlayerrRowTemplate_MatchSummaryUI (Frame)
│  │  │       
│  │  └─ Overlay (Frame)
│  │
│  ├─ OnlineRewardUI (ScreenGui)
│  │  └─ Root
│  │     ├─ Content (ScrollingFrame)
│  │     │  ├─ Grid (UIGridLayout)
│  │     │  └─ SlotRewardTemplate_OnlineRewardUI
│  │     ├─ Footer
│  │     │  ├─ ClaimAll (TextButton)
│  │     │  └─ SkipAll (TextButton)
│  │     └─ Header
│  │        ├─ CloseButton (TextButton)
│  │        └─ Title (TextLabel)
│  │
│  ├─ DailyLoginUI (ScreenGui)
│  │  ├─ MainPanel (Frame)
│  │  │  ├─ Content (Frame)
│  │  │  │  ├─ Day7Big (Frame)
│  │  │  │  │  ├─ ClaimButton (TextButton)
│  │  │  │  │  ├─ Icon (ImageLabel)
│  │  │  │  │  ├─ Claimed (TextLabel)
│  │  │  │  │  ├─ Description (TextLabel)
│  │  │  │  │  ├─ Timer (TextLabel)
│  │  │  │  │  └─ Title (TextLabel)
│  │  │  │  └─ LeftGrid (Frame)
│  │  │  │     ├─ UIGridLayout
│  │  │  │     └─ SlotRewardTemplate_DailyLoginUI -- Script Spawn in run time
│  │  │  └─ Header (Frame)
│  │  │     ├─ CloseButton (TextButton)
│  │  │     └─ Title (TextLabel)
│  │  └─ Overlay (Frame/TextButton)
│  │
│  ├─ ShopUI (ScreenGui)
│  │  └─ Main (ImageLabel)
│  │     ├─ Buttons (Frame)
│  │     │  ├─ Launcher (ImageButton)
│  │     │  ├─ Dinamonds (ImageButton)
│  │     │  └─ Items (ImageButton)
│  │     ├─ Dinamonds (Frame)
│  │     │  └─ Content (Frame)
│  │     │     └─ ScrollingFrame
│  │     ├─ Items (Frame)
│  │     │  ├─ UIListLayout
│  │     │  └─ Content (Frame)
│  │     │     ├─ UICorner
│  │     │     ├─ UIListLayout
│  │     │     └─ ScrollingFrame
│  │     ├─ Launcher (Frame)
│  │     │  ├─ UIListLayout
│  │     │  └─ Content (Frame)
│  │     │     ├─ UICorner
│  │     │     ├─ UIListLayout
│  │     │     └─ ScrollingFrame
│  │     └─ Close (TextButton/ImageButton)
│  │
│  ├─ SpinUI (ScreenGui)
│  │  └─ Root
│  │     ├─ Buttons
│  │     │  ├─ Spin1 (TextButton)
│  │     │  └─ Spin2 (TextButton)
│  │     ├─ TurnsDisplay
│  │     ├─ WheelContainer
│  │     │  ├─ Pointer
│  │     │  └─ GachaWheel (ImageLabel)
│  │     ├─ CloseButton (TextButton)
│  │     └─ Title (TextLabel)
│  │ 
│  ├─ InventoryUI (ScreenGui)
│  │  ├── Root (Frame)
│  │  │   ├── Header (Frame)
│  │  │   │   ├─ CloseButton (TextButton)
│  │  │   │   └─ Title (TextLabel)
│  │  │   ├── Tabs (Frame)
│  │  │   │   ├─ ItemsTab (TextButton)
│  │  │   │   ├─ EquipmentTab (TextButton)
│  │  │   │   └─ LauncherTab (TextButton)
│  │  │   ├── BodyLauncher (Frame)
│  │  │   │   ├── Footer (Frame)
│  │  │   │   │   └─ CapacityLabel (TextLabel)
│  │  │   │   ├── GridContainer (ScrollingFrame)
│  │  │   │   │   └─ Slot1, Slot2, Slot3, Slot4 (LauncherSlotTemplate_InventoryUI Frames) -- Script Spawn in run time
│  │  │   │   └── RightPanel (Frame)
│  │  │   │       ├─ ActionButtons (Frame)
│  │  │   │       │   ├─ DeleteButton (TextButton)
│  │  │   │       │   ├─ EquipButton (TextButton)
│  │  │   │       │   └─ UpgradeButton (TextButton)
│  │  │   │       ├─ Stats (Frame)
│  │  │   │       │   └─ Damage, HP, Range, Regen (TextLabels)
│  │  │   │       └─ SelectedName (TextLabel)
│  │  │   ├── BodyEquipment (Frame)
│  │  │   │   ├── Footer (Frame)
│  │  │   │   │   └─ CapacityLabel (TextLabel)
│  │  │   │   ├── GridContainer (ScrollingFrame)
│  │  │   │   │   └─ Slot1, Slot2, Slot3, Slot4 (EquipmentSlotTemplate_InventoryUI Frames) -- Script Spawn in run time
│  │  │   │   └── RightPanel (Frame)
│  │  │   │       ├─ ActionButtons (Frame)
│  │  │   │       │   ├─ DeleteButton (TextButton)
│  │  │   │       │   ├─ EquipButton (TextButton)
│  │  │   │       │   └─ UpgradeButton (TextButton)
│  │  │   │       ├─ Stats (Frame)
│  │  │   │       │   └─ Damage, HP, Range, Regen (TextLabels)
│  │  │   │       └─ SelectedName (TextLabel)
│  │  │   └── BodyItems (Frame)
│  │  │       ├── GridContainer (ScrollingFrame)
│  │  │       │   └─ Slot1, Slot2, Slot3, Slot4 (ItemSlotTemplate_InventoryUI Frames) -- Script Spawn in run time
│  │  │       └── RightPanel (Frame)
│  │  │           ├─ ActionButtons (Frame)
│  │  │           │   ├─ DeleteButton (TextButton)
│  │  │           │   └─ UseButton (TextButton)
│  │  │           ├─ Stats (Frame)
│  │  │           │   └─ ItemStat1, ItemStat2, ItemStat3 (TextLabels)
│  │  │           ├─ Description (TextLabel)
│  │  │           └─ SelectedName (TextLabel)
│  │  ├── Overlay (Frame)
│  │  └── UpgradePopup (Frame)
│  │      ├─ Cancel (TextButton)
│  │      ├─ Confirm (TextButton)
│  │      ├─ ConfirmText (TextLabel)
│  │      └─ PopupTitle (TextLabel)
│  │
│  ├─ MatchUI (ScreenGui)
│  │  └─ RootFrame
│  │     ├─ AlivePlayersLabel
│  │     ├─ StatusLabel
│  │     ├─ TimerLabel
│  │     └─ WinnerPopup
│  │
│  ├─ StatsUI (ScreenGui)
│  │   └─ RootFrame
│  │     ├─ GoldLabel
│  │     ├─ ScoreLabel
│  │     ├─ TitleLabel
│  │     └─ WinsLabel
│  │
│  ├─ MainHUD (ScreenGui)
│  │  └─ Root
│  │     ├─ ProgressPoint
│  │     │  └─ ValueText
│  │     ├─ BuffContainer
│  │     │  ├─ UIGridLayout
│  │     │  ├─ UISizeConstraint
│  │     │  ├─ DamageBuff
│  │     │  │  ├─ UICorner
│  │     │  │  ├─ UISizeConstraint
│  │     │  │  ├─ DMGIcon
│  │     │  │  └─ ValueText
│  │     │  ├─ ExpBuff
│  │     │  │  ├─ UICorner
│  │     │  │  ├─ UISizeConstraint
│  │     │  │  ├─ ExpIcon
│  │     │  │  └─ ValueText
│  │     │  └─ HPRecovery
│  │     │     ├─ UISizeConstraint
│  │     │     ├─ HPIcon
│  │     │     └─ Time
│  │     ├─ HumanLauncherToggle
│  │     │  ├─ UIAspectRatioConstraint
│  │     │  ├─ UICorner
│  │     │  ├─ UIStroke
│  │     │  ├─ Background
│  │     │  │  ├─ Gradient
│  │     │  │  └─ UICorner
│  │     │  └─ Options
│  │     │     ├─ Off
│  │     │     │  ├─ Click
│  │     │     │  └─ Title
│  │     │     └─ On
│  │     │        ├─ Click
│  │     │        └─ Title
│  │     ├─ ExpProress
│  │     │  ├─ ExpValueLabel
│  │     │  ├─ LevelOnBarLabel
│  │     │  └─ ExpBar
│  │     │     ├─ ExpBarBackground (Frame)
│  │     │     └─ ExpBarFill (Frame)
│  │     ├─ LeftMenu
│  │     │  ├─ DailyButton (ImageButton)
│  │     │  ├─ InventoryButton (ImageButton)
│  │     │  ├─ OnlineRewardButton (ImageButton)
│  │     │  ├─ SettingButton (ImageButton)
│  │     │  ├─ TabScore (ImageButton)
│  │     │  ├─ Quest (ImageButton)
│  │     │  └─ ShopButton (ImageButton)
│  │     ├─ RankFrame
│  │     │  ├─ List
│  │     │  │  └─ Player1
│  │     │  └─ Title (TextLabel)
│  │     ├─ Diamond
│  │     │  ├─ DiamondIcon (ImageLabel)
│  │     │  └─ Value (TextLabel)
│  │     ├─ QuickHP (ImageButton)
│  │     │  ├─ Time (TextLabel)
│  │     │  ├─ Overlay (Frame)
│  │     │  └─ Quantity (TextLabel)
│  │     └─ Home (ImageButton)
│  │   
│  ├─ DailyLoginUI (ScreenGui) -- [REFINED FROM NEW IMAGE]
│  │  ├─ MainPanel (Frame)
│  │  │  ├─ UICorner
│  │  │  ├─ UIPadding
│  │  │  └─ Content (Frame)
│  │  │     ├─ Day7Big (Frame)
│  │  │     └─ LeftGrid (Frame)
│  │  │        ├─ UIGridLayout
│  │  │        ├─ Day1 (Frame)
│  │  │        ├─ Day2 (Frame)
│  │  │        ├─ Day3 (Frame)
│  │  │        ├─ Day4 (Frame)
│  │  │        ├─ Day5 (Frame)
│  │  │        └─ Day6 (Frame)
│  │  ├─ Header (Frame)
│  │  │  ├─ CloseButton (TextButton/ImageButton)
│  │  │  │  └─ UICorner
│  │  │  └─ Title (TextLabel)
│  │  └─ Overlay (Frame)
│  │
│  └─ LauncherUI (ScreenGui)
│     ├─ ChargeBar
│     │  └─ Fill
│     ├─ CancelZone
│     │  └─ IconX
│     └─ JoystickRoot
│        ├─ Base
│        │  └─ UICorner
│        ├─ CooldownOverlay
│        │  ├─ UICorner
│        │  ├─ LeftHalf
│        │  │  └─ Clip
│        │  │     └─ Fill
│        │  └─ RightHalf
│        │     └─ Clip
│        │        └─ Fill
│        ├─ Thumb
│        ├─ DirectionIndicator
│        └─ CooldownText
│
## 🟫 Workspace (Maps)
├─ Workspace -> src/Workspace
│  ├─ Camera
│  └─ Maps (Folder/Model)
│     ├─ LobbyMap (Model)
│     │  ├─ SpawnPoints
│     │  │  └─ LobbySpawn
│     │  ├─ GachaSpin
│     │  │  └─ Spinwheel
│     │  ├─ Gate (optional join trigger)
│     │  └─ Rank (Folder)
│     │     └─ Table (Part)
│     │        └─ SurfaceGui (SurfaceGui)
│     │           └─ Root
│     │              └─ List
│     │                 ├─ UIGridLayout
│     │                 └─ PlayerRowTemplate_TopRank100 (Frame Clone)
│     │                    ├─ NameValue
│     │                    ├─ RankValue
│     │                    └─ PointValue
│     │
│     └─ ArenaMap (Model)
│        ├─ FoodContainer (Folder)
│        ├─ FoodSpawns (Folder)
│        │  ├─ CenterZones (Folder)
│        │  │  ├─ FoodSpawn_01
│        │  │  └─ FoodSpawn_..N
│        │  ├─ EdgeZones (Folder)
│        │  │  ├─ FoodSpawn_01
│        │  │  └─ FoodSpawn_..N
│        │  └─ MidZones (Folder)
│        │     ├─ FoodSpawn_01
│        │     └─ FoodSpawn_..N
│        │
│        ├─ SpawnPoints (Folder)
│        │  ├─ SpawnPoint_01
│        │  ├─ SpawnPoint_02
│        │  ├─ SpawnPoint_03
│        │  └─ SpawnPoint_04
│        │
│        ├─ Traps (Folder)
│        │  ├─ LavaTrap (Model)
│        │  │  ├─ LavaFloor
│        │  │  ├─ LavaCenter
│        │  │  └─ Lava
│        │  ├─ SpikeTrap (Model)
│        │  │  ├─ Core
│        │  │  └─ Spike
│        │  ├─ SpikeTrap (Model)
│        │  └─ SpikeTrap (Model)
│        │
│        ├─ CenterCross (Model)
│        ├─ ContestZone_Green (Model)
│        ├─ FarmZone_Main (Model)
│        └─ SimulatorCircle (Model)
│           ├── GradientCylinder (Mesh)
│           │    ├─ Decal
│           │    ├─ Decal
│           │    ├─ Decal
│           │    └─ Decal
│           └── Core (Part)
│
## 🟪 ServerStorage
├─ ServerStorage [INFERRED runtime dependency]
## ⚫ Runtime Workspace
└─ Workspace
   └─ Runtime
      └─ LauncherPawns
         └─ LauncherPawns  [INFERRED auto-created by PlayerService]


Notes:
- All production `ReplicatedStorage.LauncherArenaRemotes.*` instances are defined statically through `src/ReplicatedStorage/LauncherArenaRemotes/*.model.json`.
- Several runtime-critical map/template instances (e.g. `Workspace/Maps`, `ServerStorage/FoodTemplates`)
  are not present as files in the repo and must be created manually in Roblox Studio.
