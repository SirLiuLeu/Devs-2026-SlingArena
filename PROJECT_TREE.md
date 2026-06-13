
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
│  │     ├─ MythicCrystal
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ RareAmber
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ UncommonIce
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     ├─ UniqueCore
│  │     │  ├─ Hitbox
│  │     │  └─ Visual
│  │     └─ UniqueCrown
│  │        ├─ Hitbox
│  │        └─ Visual
│  │
│  ├─ Shared  -> src/ReplicatedStorage/Shared
│  │  ├─ Config
│  │  │  ├─ AbilityConfig.lua
│  │  │  ├─ BalanceConfig.lua
│  │  │  ├─ Config.lua
│  │  │  ├─ FoodConfig.lua
│  │  │  ├─ GachaRewardConfig.lua
│  │  │  ├─ GameConfig.lua
│  │  │  ├─ ItemConfig.lua
│  │  │  ├─ LevelConfig.lua
│  │  │  ├─ SlingConfig.lua
│  │  │  ├─ SlingshotConfig.lua
│  │  │  └─ TrapConfig.lua
│  │  │
│  │  ├─ Constants
│  │  │  ├─ GameStates.lua
│  │  │  └─ SlingUiConstants.lua
│  │  │
│  │  ├─ Types
│  │  │  ├─ CombatTypes.lua
│  │  │  └─ PlayerState.lua
│  │  │
│  │  ├─ Utils
│  │  │  ├─ GachaSpinLogic.lua
│  │  │  ├─ PathResolver.lua
│  │  │  ├─ RewardRoller.lua
│  │  │  ├─ SlingUiState.lua
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
│  │  ├── Slings
│  │  │  ├── Player (Character Default)
│  │  │
│  │  ├── Slings
│  │  │  ├── Player (Character Default)
│  │  │  │  ├── Trail
│  │  │  │  ├── WeldConstraint_HitboxMesh
│  │  │  │  ├── EquippedSlingModel (Sling_Template)
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
│  │  │  │  │  ├── SlingMovementAttachment (Attachment)
│  │  │  │  │  ├── TrailEnd (Attachment)
│  │  │  │  │  └── TrailStart (Attachment)
│  │  │  │  └── SlingWorldUI
│  │  │  │     ├── UIListLayout
│  │  │  │     ├── HpBarBackground
│  │  │  │     │  ├── UICorner
│  │  │  │     │  └── HpBarFill
│  │  │  │     ├── LevelLabel
│  │  │  │     └── Name
│  │  │  │
│  │  │  ├── Sling_Template (Model structure reference only)
│  │  │  │  └── Mesh (MeshPart)
│  │  │  │        ├── WeldConstraint
│  │  │  │        └── Part
│  │  │  ├── SupportSling (Sling_Template format)
│  │  │  ├── StunSling (Sling_Template format)
│  │  │  ├── NormalSling (Sling_Template format; default sling)
│  │  │  ├── VacuumSling (Sling_Template format)
│  │  │  ├── StealthSling (Sling_Template format)
│  │  │  ├── HealSling (Sling_Template format)
│  │  │  ├── SpeedSling (Sling_Template format)
│  │  │  ├── BonusBuffSling (Sling_Template format)
│  │  │  ├── FreezeSling (Sling_Template format) -- sẽ delete trong tương lai
│  │  │  ├── PetrifySling (Sling_Template format) -- new update, replace FreezeSling
│  │  │  ├── FireSling (Sling_Template format)
│  │  │  └── PoisonSling (Sling_Template format)
│  │  │
│  │  ├── Icons
│  │  │   ├── Items
│  │  │   │   ├── HP_Potion (Image)
│  │  │   │   ├── Gacha_Ticket (Image)
│  │  │   │   └── EXP_Buff (Image)
│  │  │   │
│  │  │   └── Slings
│  │  │       └── Sling icons for the canonical 11 sling ids (Image)
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
│  │      ├── ItemSlotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── UICorner
│  │      │       ├── Icon (ImageLabel)
│  │      │       ├── Name (TextLabel)
│  │      │       └── Quantity (TextLabel)
│  │      │
│  │      ├── SlingsSlotTemplate_InventoryUI (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── UIStroke (RarityStroke)
│  │      │       ├── UICorner
│  │      │       ├── Stars (Frame)
│  │      │       │   ├── UIListLayout
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
│  │      ├── SlotItemsTemplate_ShopUI (Frame)
│  │      │   ├── UICorner
│  │      │   ├── InfoButton (ImageButton)
│  │      │   ├── BuyButton (TextButton/ImageButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   ├── Quantity (TextLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── SlotLaucherTemplate_shopUI (Frame)
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
│  │      ├── SlingWorldUI (BillboardGui)
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
│  ├─ SlingArenaRemotes
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
│  │     ├─ DebugResetSling
│  │     ├─ StateUpdate
│  │     ├─ UIStateUpdate
│  │     ├─ GameplayFeedback
│  │     ├─ MatchStateUpdate
│  │     ├─ RoundResult
│  │     ├─ PopupMessage
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
│  ├─ MapLoader.server.lua
│  ├─ SlingService.server.lua
│  │
│  ├─ Config
│  │  ├─ PhysisConfig.lua
│  │  └─ FoodConfig.lua
│  │
│  ├─ Tests
│  │  └─ CoreLoopTests.server.lua
│  │
│  └─ Services
│     ├─ EventBus.lua
│     ├─ PlayerStateService.lua
│     ├─ PlayerService.lua
│     ├─ RoundService.lua
│     ├─ MapService.lua
│     ├─ SlingService.lua
│     │  ├─ SlingMovement.lua (internal movement module)
│     │  └─ ChargeFlow.lua [MISSING: planned internal submodule]
│     ├─ CollisionService.lua
│     ├─ DamagePipelineService.lua
│     ├─ GrowthService.lua
│     ├─ FoodService.lua
│     ├─ TrapService.lua
│     ├─ TeamService.lua
│     ├─ LeaderboardService.lua
│     ├─ MonetizationService.lua
│     ├─ SlingAbilityService.lua [MISSING: required by freeze]
│     ├─ SafeZoneService.lua [MISSING: required by freeze]
│     ├─ MapLoader.server.lua (legacy helper entrypoint)
│     └─ (SkillService removed in safe migration target)
│
## 🟩 StarterPlayer
├─ StarterPlayer
│  └─ StarterPlayerScripts
│     └─ Client  -> src/StarterPlayer
│        └─ StarterPlayerScripts
│           ├─ InputController.client.lua      (active input / charge script)
│           ├─ UIBinder.client.lua           (active UI bootstrap; event-driven rebinding)
│           └─ CameraController.client.lua   (Camera)
│
## 🟨 StarterGui
├─ StarterGui  -> src/StarterGui
│  ├─ UnitTestUI (ScreenGui)
│  │  └─ RootFrame
│  │     ├─ DebugFood
│  │     ├─ DebugReset
│  │     ├─ JoinButton
│  │     ├─ LeaveButton
│  │     └─ StartSafeZoneButton
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
│  │  │   │   └─ SlingTab (TextButton)
│  │  │   ├── BodySling (Frame)
│  │  │   │   ├── Footer (Frame)
│  │  │   │   │   └─ CapacityLabel (TextLabel)
│  │  │   │   ├── GridContainer (ScrollingFrame)
│  │  │   │   │   └─ Slot1, Slot2, Slot3, Slot4 (Frames) -- Script Spawn in run time
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
│  │  │       │   └─ Slot1, Slot2, Slot3, Slot4 (Frames) -- Script Spawn in run time
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
│  │     ├─ BuffContainer
│  │     │  ├─ Buff1 (Frame)
│  │     │  └─ Buff2 (Frame)
│  │     ├─ ExpProress
│  │     │  ├─ ExpValueLabel
│  │     │  ├─ LevelOnBarLabel
│  │     │  └─ ExpBar
│  │     │     ├─ ExpBarBackground
│  │     │     └─ ExpBarFill
│  │     ├─ LeftMenu
│  │     │  ├─ DailyButton (ImageButton)
│  │     │  ├─ InventoryButton (ImageButton)
│  │     │  ├─ OnlineRewardButton (ImageButton)
│  │     │  ├─ SettingButton (ImageButton)
│  │     │  └─ ShopButton (ImageButton)
│  │     ├─ RankFrame
│  │     │  ├─ List
│  │     │  │  └─ Player1
│  │     │  └─ Title (TextLabel)
│  │     ├─ Diamond
│  │     │  ├─ DiamondIcon (ImageLabel)
│  │     │  └─ Quantity (TextLabel)
│  │     ├─ QuickHP (ImageButton)
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
│  └─ SlingArenaUI [INFERRED legacy / alternative UI stack]
│        ├─ SlingUI (ScreenGui; created in Studio/manual UI asset)
│        │   ├─ JoystickRoot (Frame)
│        │   │  ├─ Base (Frame)
│        │   │  └─ Thumb (Frame)
│        │   │
│        │   ├─ ChargeBar (Frame)
│        │   │  └─ Fill (Frame)
│        │   │
│        │   ├─ CooldownBar (Frame)
│        │   │  └─ Fill (Frame)
│        │   │
│        │   └─ DirectionIndicator (ImageLabel)
│        ├─ MainUI.client.lua (deprecated)
│        ├─ SlingUIController.client.lua (LocalScript; resolves SlingUI ScreenGui without name collision)
│        ├─ UIController.lua
│        └─ Components/*
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
│     │  └─ Gate (optional join trigger)
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
│        │  ├─ SpikeTrap
│        │  ├─ SpikeTrap
│        │  └─ SpikeTrap
│        │
│        ├─ CenterCross (Model)
│        ├─ ContestZone_Green (Model)
│        ├─ FarmZone_Main (Model)
│        ├─ LavaBase (Part)
│        └─ SimulatorCircle (Model)
│           ├── GradientCylinder (MeshPart/Part)
│           │    ├─ Decal
│           │    ├─ Decal
│           │    ├─ Decal
│           │    └─ Decal
│           └── LightCore (Part)
│
## 🟪 ServerStorage
├─ ServerStorage [INFERRED runtime dependency]
## ⚫ Runtime Workspace
└─ Workspace
   └─ Runtime
      └─ SlingPawns
         └─ SlingPawns  [INFERRED auto-created by PlayerService]


Notes:
- All production `ReplicatedStorage.SlingArenaRemotes.*` instances are defined statically through `src/ReplicatedStorage/SlingArenaRemotes/*.model.json`.
- Several runtime-critical map/template instances (e.g. `Workspace/Maps`, `ServerStorage/FoodTemplates`)
  are not present as files in the repo and must be created manually in Roblox Studio.
