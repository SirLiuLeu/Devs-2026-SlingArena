
DataModel
## 🟦 ReplicatedStorage
├─ ReplicatedStorage
│  │  └─ FoodModels
│  │     └─ CommonBlue, CommonGreen, CommonRed, EpicViolet, LegendaryGold, RareAmber, UncommonIce
│  │        ├─ Hitbox
│  │        └─ Visual
│  │
│  ├─ Shared  -> src/ReplicatedStorage/Shared
│  │  ├─ Config
│  │  │  ├─ AbilityConfig.lua
│  │  │  ├─ BalanceConfig.lua
│  │  │  ├─ ConfirmationTextConfig.lua
│  │  │  ├─ DebugConfig.lua
│  │  │  ├─ GachaRewardConfig.lua
│  │  │  ├─ GameConfig.lua
│  │  │  ├─ ItemConfig.lua
│  │  │  ├─ LevelConfig.lua
│  │  │  ├─ LauncherAnimationIds.lua
│  │  │  ├─ LauncherConfig.lua
│  │  │  ├─ LauncherTextureConfig.lua
│  │  │  ├─ TeamConfig.lua
│  │  │  ├─ NotificationConfigData.lua
│  │  │  ├─ PetAbilityProgressionConfig.lua
│  │  │  ├─ PetPreviewConfig.lua
│  │  │  ├─ PetRenderConfig.lua
│  │  │  ├─ PetRarityStatsConfig.lua
│  │  │  ├─ PetsConfig.lua
│  │  │  ├─ PetsUpgradeConfig.lua
│  │  │  ├─ PhysicsConfig.lua
│  │  │  ├─ QuestConfig.lua
│  │  │  ├─ RankConfig.lua
│  │  │  ├─ SafeZoneConfig.lua
│  │  │  ├─ SoundConfig.lua
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
│  │  │  ├─ DeepCopy.lua
│  │  │  ├─ CollisionClassifier.lua
│  │  │  ├─ GachaSpinLogic.lua
│  │  │  ├─ PathResolver.lua
│  │  │  ├─ PetDisplayFormatter.lua
│  │  │  ├─ PetProgression.lua
│  │  │  ├─ PlayerModeState.lua
│  │  │  ├─ RewardRoller.lua
│  │  │  ├─ SoundManager.lua
│  │  │  ├─ UiBindManager.lua
│  │  │  ├─ LauncherUiState.lua
│  │  │  └─ WaitForUI.lua
│  │  ├─ ProjectTreeSpec.lua
│  │  └─ RemoteContracts.lua
│  │
│  ├─ Assets
│  │  ├── Prefabs
│  │  │   ├── ArrowModel (Model)
│  │  │   │   ├── EndAttachment (Attachment)
│  │  │   │   ├── StartAttachment (Attachment)
│  │  │   │   └── Arrow (MeshPart/Part)
│  │  │   ├── PlasmaBall (Model)
│  │  │   └── SlowBall (Model)
│  │  │
│  │  ├── Pets (Folder)
│  │  │   ├── Dragon (Model)
│  │  │   ├── Hydra (Model)
│  │  │   ├── Octopus (Model)
│  │  │   ├── Phoenix (Model)
│  │  │   ├── Snake (Model)
│  │  │   ├── Unicorn (Model)
│  │  │   ├── Yeti (Model)
│  │  │   ├── Bee (Model)
│  │  │   ├── Bunny (Model)
│  │  │   ├── Caterpillar (Model)
│  │  │   ├── Cow (Model)
│  │  │   ├── Dog (Model)
│  │  │   ├── Elephant (Model)
│  │  │   ├── Fish (Model)
│  │  │   ├── Monkey (Model)
│  │  │   ├── Panda (Model)
│  │  │   ├── Penguin (Model)
│  │  │   └── Pig (Model)
│  │  │
│  │  ├── Equipment (Folder)
│  │  │  ├── BrainBoost (Model)
│  │  │  ├── ThornArmor (Model)
│  │  │  ├── ShadowCloak (Model)
│  │  │  ├── GhostFlame (Model)
│  │  │  ├── HealthCore (Model)
│  │  │  ├── SlowBlaster (Model)
│  │  │  ├── Shield (Model)
│  │  │  ├── TurboModule (Model)
│  │  │  ├── Medusa (Model)
│  │  │  ├── Poison (Model)
│  │  │  ├── PowerCore (Model)
│  │  │  ├── RegenBooster (Model)
│  │  │  ├── QuickReload (Model)
│  │  │  ├── PlasmaCannon (Model)
│  │  │  ├── ThunderHammer (Model)
│  │  │  ├── TitanCore (Model)
│  │  │  ├── LaunchBooster (Model)
│  │  │  └── IceCrystal (Model)
│  │  │
│  │  ├── Launchers
│  │  │  ├── Player (Character Default)
│  │  │  │  ├── MotionTrail1 (Trail; uses TrailStart_A / TrailEnd_A; default Enabled=false)
│  │  │  │  ├── MotionTrail2 (Trail; uses TrailStart_B / TrailEnd_B; default Enabled=false)
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
│  │  │  │  │  ├── TailAttachment (Attachment)
│  │  │  │  │  │  └── RocketLaunchParticle (ParticleEmitter)
│  │  │  │  │  ├── TrailEnd_A (Attachment)
│  │  │  │  │  ├── TrailStart_A (Attachment)
│  │  │  │  │  ├── TrailEnd_B (Attachment)
│  │  │  │  │  └── TrailStart_B (Attachment)
│  │  │  │  └── LauncherWorldUI
│  │  │  │     ├── UIListLayout
│  │  │  │     ├── HpBarBackground
│  │  │  │     │  ├── UICorner
│  │  │  │     │  └── HpBarFill
│  │  │  │     ├── LevelLabel
│  │  │  │     └── Name
│  │  │  ├── Normalduck (Launcher visual; default)
│  │  │  ├── Kingduck (Launcher visual)
│  │  │  ├── Witchduck (Launcher visual)
│  │  │  ├── Drakeduck (Launcher visual)
│  │  │  └── Shielduck (Launcher visual)
│  │  │
│  │  ├── Icons
│  │  │   ├── Items
│  │  │   │   ├── HP_Potion (Image)
│  │  │   │   ├── Gacha_Ticket (Image)
│  │  │   │   └── EXP_Buff (Image)
│  │  │   │
│  │  │   └── Launchers
│  │  │       └── Launcher icons for the five Duck Launcher IDs (Image)
│  │  │
│  │  └── UI
│  │      ├── FloatingDamage (BillboardGui)
│  │      │   └── Value (TextLabel)
│  │      │
│  │      ├── PlayerRowTemplate_RankFrame (Frame)
│  │      │   ├── Name (TextLabel) 
│  │      │   └── Level (TextLabel)   
│  │      │
│  │      ├── FoodWorldUI (BillboardGui)
│  │      │   └── HpBarBackground (Frame)
│  │      │       ├── UICorner
│  │      │       └── HpBarFill (Frame)
│  │      │
│  │      ├── ItemSlotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── UICorner
│  │      │       ├── Icon (ImageLabel)
│  │      │       ├── Name (TextLabel)
│  │      │       └── Quantity (TextLabel)
│  │      │
│  │      ├── LauncherSlotTemplate_LauncherInventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── Stars (Frame)
│  │      │       │   ├── Star1 (ImageLabel)
│  │      │       │   ├── Star2 (ImageLabel)
│  │      │       │   ├── Star3 (ImageLabel)
│  │      │       │   ├── Star4 (ImageLabel)
│  │      │       │   └── Star5 (ImageLabel)
│  │      │       ├── LauncherPreview (ViewportFrame)
│  │      │       │   ├── Model (Model Equipment)
│  │      │       │   └── Camera
│  │      │       ├── EquippedTag (TextLabel)
│  │      │       ├── Level (TextLabel)
│  │      │       └── Name (TextLabel)
│  │      │
│  │      ├── PetsSlotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── RemainingTimeText (TextLabel)
│  │      │       ├── PetPreview (ViewportFrame)
│  │      │       │   ├── Model (Model Equipment)
│  │      │       │   └── Camera
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
│  │      │   ├── LauncherPreview (ViewportFrame)
│  │      │   │   ├── Model (Model Equipment)
│  │      │   │   └── Camera
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
│  │     ├─ ChangeTeam
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
│  │     ├─ ReportWallHit
│  │     ├─ RequestRespawn
│  │     ├─ PurchaseRespawn
│  │     ├─ PurchaseMatchBuff
│  │     ├─ PrestigeReset
│  │     ├─ DebugSpawnFood
│  │     ├─ DebugResetLauncher
│  │     ├─ DebugLevelUp5
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
│     │  ├─ TeamSelectionUIController.lua
│     │  └─ UIController.lua
│     └─ Services
│        └─ LobbyClientService.lua 
│ 
## 🟥 ServerScriptService
├─ ServerScriptService  -> src/ServerScriptService
│  ├─ Main.server.lua
│  ├─ Config
│  ├─ Tests
│  │  └─ CoreLoopTests.server.lua
│  └─ Services
## 🟩 StarterPlayer
├─ StarterPlayer
│  └─ StarterPlayerScripts
│     ├─ CameraController.client.lua                 (Camera)
│     ├─ CollisionClientScanner.client.lua
│     ├─ FoodWorldUI.client.lua
│     ├─ InputController.client.lua                  (Active input / charge script)
│     ├─ KnockbackReplicationClient.client.lua
│     ├─ LaunchImpulseClient.client.lua
│     ├─ LauncherControlUIController.client.lua             (Resolves LauncherControlUI ScreenGui)
│     ├─ PlayerModeController.client.lua
│     ├─ SafeZoneVisualizer.client.lua
│     ├─ UIBinder.client.lua                         (UI bootstrap; event-driven rebinding)
│     └─ Components
│        ├─ AttributePanel.lua
│        ├─ BuffPanel.lua
│        ├─ ChargeBar.lua
│        ├─ CooldownDisplayComponent.lua
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
│  │     ├─ LevelUp5
│  │     ├─ EndRoundButton
│  │     └─ StartSafeZoneButton
│  │
│  ├─ ConfirmationGui (ScreenGui)
│  │  └─ Root (Frame)
│  │     ├─ UICorner
│  │     ├─ Cancel (TextButton)
│  │     ├─ Confirm (TextButton)
│  │     └─ ConfirmText (TextLabel)
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
│  ├─ TeamSelectionGui (ScreenGui)
│  │  ├─ TeamPopupFrame
│  │  │  └─ Yellow, White, Red, Blue (TextButton)
│  │  │     ├─ UICorner
│  │  │     ├─ TeamIcon (Image)
│  │  │     ├─ PlayerCount (TextLabel)
│  │  │     └─ TeamName (TextLabel)
│  │  └─ ToggleBtn (TextButton)
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
│  │  │   │   └─ PetsTab (TextButton)
│  │  │   ├── BodyPets (Frame)
│  │  │   │   ├── Footer (Frame)
│  │  │   │   │   └─ CapacityLabel (TextLabel)
│  │  │   │   ├── GridContainer (ScrollingFrame)
│  │  │   │   │   └─ Slot1, Slot2, Slot3, Slot4 (PetSlotTemplate_InventoryUI Frames) -- Script Spawn in run time
│  │  │   │   └── RightPanel (Frame)
│  │  │   │       ├─ ActionButtons (Frame)
│  │  │   │       │   ├─ DeleteButton (TextButton)
│  │  │   │       │   ├─ ToggleEquipButton (TextButton)
│  │  │   │       │   └─ UpgradeButton (TextButton)
│  │  │   │       ├─ Stats (Frame)
│  │  │   │       │   └─ Level, Damage, HP, Script (TextLabels)
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
│  │  └── Overlay (Frame)
│  │
│  ├─ LauncherInventoryUI (ScreenGui)
│  │  ├─ Overlay
│  │  └─ Root (Frame)
│  │     └─ BodyLauncher
│  │        ├─ Footer
│  │        │  └─ CapacityLabel (TextLabel)
│  │        ├─ GridContainer
│  │        │  └─  Slot1, Slot2, Slot3, Slot4 (LauncherSlotTemplate_LauncherInventoryUI Frames) -- Script Spawn in run time
│  │        └─ RightPanel
│  │           ├─ ActionButtons
│  │           │  ├─ SellButton (TextButton)
│  │           │  └─ EquiptButton (TextButton)
│  │           ├─ Stats
│  │           │  └─ Damage, HP, Range, Regeneration (TextLabels)
│  │           └─ SelectedName (TextLabel)
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
│  │     │  ├─ SoundToggleButton (TextButton)
│  │     │  │  ├─ SoundOnIcon (ImageLabel)
│  │     │  │  └─ SoundOffIcon (ImageLabel)
│  │     │  ├─ TabScore (ImageButton)
│  │     │  ├─ Quest (ImageButton)
│  │     │  └─ ShopButton (ImageButton)
│  │     ├─ RankFrame
│  │     │  └─ List
│  │     │     └─ Slot1, Slot2, Slot3, Slot4, Slot5 (PlayerRowTemplate_RankFrame clones) -- Script Spawn in run time
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
│  └─ LauncherControlUI (ScreenGui)
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
│     │  ├─ Launcher (Folder)
│     │  │  ├─ LauncherMaster (Model)
│     │  │  └─ LauncherInventoryGUI_Part (Part)
│     │  ├─ Shop (Folder)
│     │  │  ├─ Shop (Model)
│     │  │  └─ ShopGUI_Part (Part)
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


## 🔊 SoundService
├─ SoundService
│  └─ SlingArenaSoundGroup (SoundGroup, Volume=1; client-side toggle sets Volume to 0/1)

Notes:
- All production `ReplicatedStorage.LauncherArenaRemotes.*` instances are defined statically through `src/ReplicatedStorage/LauncherArenaRemotes/*.model.json`.
- Several runtime-critical map/template instances (e.g. `Workspace/Maps`, `ServerStorage/FoodTemplates`)
  are not present as files in the repo and must be created manually in Roblox Studio.

## Pet inventory progression notes

`StarterGui/InventoryUI/Root/BodyPets/RightPanel/Stats/Level` is the bound pet-level display. Pet base stats advance on every level; most ability values advance at milestones 1, 5, 10, 15, and 20. Titan's weight and hitbox multipliers scale with Hydra pet level. Visual growth is based on player levels earned after Titan is equipped: +4% per level to a 2x cap; levels earned before equip do not count. `PetAbilityProgressionConfig.Abilities[abilityId].Display` stores `{ Format, Templates = { en, vi } }` for localized display text, while `PetPreviewConfig.Get(petId)` provides the viewport `Rotation` and `Offset`.


## Team / Pet projectile implementation notes

- Team config: `src/ReplicatedStorage/Shared/Config/TeamConfig.lua` and `LauncherTextureConfig.lua`.
- Team selection controller: `src/ReplicatedStorage/Client/Controllers/TeamSelectionUIController.lua`; it binds the Studio-authored `StarterGui.TeamSelectionGui` hierarchy documented in `ProjectTreeSpec.lua`.
- Pet projectile modules: `src/ServerScriptService/Services/PetAbilityService/PetAbilities/PlasmaCannon.lua` and `SlowBlaster.lua`; both activate automatically on available targets and cooldown, without a Pet skill-button request.
- Nearby Pet visuals are client-local and range-gated by `src/ReplicatedStorage/Shared/Config/PetRenderConfig.lua`.
- `UnitTestUI.RootFrame.LevelUp5` uses the Studio-only `LauncherArenaRemotes.DebugLevelUp5` RemoteEvent.
- Required Studio prefab instances: `ReplicatedStorage.Assets.Prefabs.PlasmaBall` and `SlowBall`. These assets are documented but are not source-controlled by Rojo in this repository; verify they remain in Studio after sync.


## Current feature additions (2026-10-18)

- Launcher inventory sell control: `StarterGui/LauncherInventoryUI/Root/BodyLauncher/RightPanel/ActionButtons/SellButton` (Studio-authored, not generated by code; create/rename this button in Studio if missing). The UI path is recorded in `ProjectTreeSpec.UI.LauncherInventory.SellButton`.
- Added static RemoteEvent instance definitions: `src/ReplicatedStorage/LauncherArenaRemotes/SellLauncher.model.json` and `PetProjectileVisual.model.json`.
- Added shared client visual budget config: `src/ReplicatedStorage/Shared/Config/PetProjectileRenderConfig.lua`.
- Added local visual controller: `src/StarterPlayer/StarterPlayerScripts/PetProjectileVisualController.client.lua`.
- Server-simulated projectile prefabs still must exist at `ReplicatedStorage.Assets.Prefabs.PlasmaBall` and `ReplicatedStorage.Assets.Prefabs.SlowBall` in Studio. Client render culling is cosmetic only; the server resolves hit/damage/Slow.
- Launcher sale prices and time-limited sale value are defined in `src/ReplicatedStorage/Shared/Config/LauncherConfig.lua`; time-limited instances carry `isTemporary` and/or `expiresAt` metadata in owned Launcher data.

## Audio SFX implementation (updated 2026-10-27)

- Audio metadata lives in `src/ReplicatedStorage/Shared/Config/SoundConfig.lua`; fill `SoundId` values there after the audio choices are finalized. `Pitch` maps to Roblox `Sound.PlaybackSpeed`.
- `src/ReplicatedStorage/Shared/Utils/SoundManager.lua` creates Sound instances lazily, pools them by sound key, supports per-play overrides, and releases completed sounds and temporary 3D emitters to bounded pools.
- `src/ReplicatedStorage/Client/Controllers/SFXController.lua` owns client-local UI and gameplay feedback cues and binds current and dynamically-created GuiButtons for `SFX_UI_Click`.
- No pre-instanced `ReplicatedStorage.Assets.Sounds` hierarchy is required. The configuration table is the source of truth for the planned 21 SFX keys.


## Audio collision SFX update (2026-10-28)

- Successful consumption of `hp_potion` uses `SFX_Item_HealthPotion`; other consumables continue to use `SFX_Success`.
- Added the static `src/ReplicatedStorage/LauncherArenaRemotes/ReportWallHit.model.json` RemoteEvent. `CollisionClientScanner.client.lua` reports collidable world parts intersected during a launch spherecast; the server validates the launch and contact geometry, applies per-part and per-player sound cooldowns, then plays `SFX_Wall_Hit` as spatial audio.
- `CollisionClassifier.lua` resolves the closest `Collision_Wall`, `Collision_Ground`, `Collision_Food`, `Collision_Lava`, or `Collision_Trap` tag on the hit Instance or its ancestors; a child tag overrides a Model-level tag. Only `Collision_Wall` can trigger scanned `SFX_Wall_Hit`. Ground is skipped during spherecast scanning and is silent; Food, Lava, Trap, and unclassified parts do not trigger wall audio. `CollisionValidation.ValidateWallTarget` enforces the Wall tag on the server. Existing arena-boundary bounce remains a separate `SFX_Wall_Hit` path. The report is cosmetic only and does not authoritatively modify launch velocity.
