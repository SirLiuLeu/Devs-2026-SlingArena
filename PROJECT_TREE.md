
DataModel
## 🟦 ReplicatedStorage
├─ ReplicatedStorage
│  ├─ Shared  -> src/ReplicatedStorage/Shared
│  │  ├─ Config
│  │  │  ├─ BalanceConfig.lua
│  │  │  ├─ Config.lua
│  │  │  ├─ LevelConfig.lua
│  │  │  ├─ SlingshotConfig.lua
│  │  │  └─ TrapConfig.lua
│  │  │
│  │  ├─ Types
│  │  │  ├─ PlayerState.lua
│  │  │  └─ CombatTypes.lua
│  │  │
│  │  ├─ Utils
│  │  │  └─ PathResolver.lua
│  │  │
│  │  ├─ ProjectTreeSpec.lua
│  │  └─ RemoteContracts.lua
│  │
│  ├─ Assets
│  │  ├── Slings
│  │  │   ├── Sling_Template (Model)
│  │  │   │   ├── Hitbox (Part - PrimaryPart)
│  │  │   │   ├── Mesh (MeshPart/SpecialMesh)
│  │  │   │   ├── Attachments
│  │  │   │   │   ├── TrailStart (Attachment)
│  │  │   │   │   ├── TrailEnd (Attachment)
│  │  │   │   │   └── EffectOrigin (Attachment)
│  │  │   │   └── Trail (Trail)
│  │  │   │
│  │  │   ├── Sling_01 (Sling_Template)
│  │  │   ├── Sling_02 (Sling_Template)
│  │  │   ├── Sling_03 (Sling_Template)
│  │  │   ├── Sling_04 (Sling_Template)
│  │  │   └── Sling_05 (Sling_Template)
│  │  │
│  │  ├── Icons
│  │  │   ├── Items
│  │  │   │   ├── HP_Potion (Image)
│  │  │   │   ├── Gacha_Ticket (Image)
│  │  │   │   └── EXP_Buff (Image)
│  │  │   │
│  │  │   └── Slings
│  │  │       ├── Sling_01 (Image)
│  │  │       ├── Sling_02 (Image)
│  │  │       ├── Sling_03 (Image)
│  │  │       ├── Sling_04 (Image)
│  │  │       └── Sling_05 (Image)
│  │  │
│  │  └── UI
│  │      ├── ItemSlotTemplate (Frame)
│  │      │   └── Root (Frame)
│  │      │       ├── UICorner
│  │      │       ├── Icon (ImageLabel)
│  │      │       ├── Name (TextLabel)
│  │      │       └── Quantity (TextLabel)
│  │      │
│  │      ├── SlingsSlotTemplate (Frame)
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
│  │      ├── SlotDailyLoginRewardTemplate (Frame)
│  │      │   ├── UICorner
│  │      │   ├── UIStroke
│  │      │   ├── ClaimButton (TextButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   ├── Claimed (TextLabel)
│  │      │   ├── Quantity (TextLabel)
│  │      │   ├── Timer (TextLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── SlotItemsOfStoreTemplate (Frame)
│  │      │   ├── UICorner
│  │      │   ├── InfoButton (ImageButton)
│  │      │   ├── BuyButton (TextButton/ImageButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   ├── Quantity (TextLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── SlotLaunchersOfStoreTemplate (Frame)
│  │      │   ├── UICorner
│  │      │   ├── InfoButton (ImageButton)
│  │      │   ├── BuyButton (TextButton/ImageButton)
│  │      │   ├── Icon (ImageLabel)
│  │      │   └── Title (TextLabel)
│  │      │
│  │      ├── SlotDinamondsOfStoreTemplate (Frame)
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
│  │      │   └── LevelLabel (TextLabel)
│  │      │
│  │      └─ RewardSlotTemplate (Frame)
│  │          ├─ UICorner
│  │          ├─ ClaimButton (TextButton)
│  │          ├─ Icon (ImageLabel)
│  │          ├─ Claimed (TextLabel)
│  │          ├─ Quantity (TextLabel)
│  │          └─ Timer (TextLabel)
│  │
│  ├─ SlingArenaRemotes
│  │  └─ (RemoteEvents from *.model.json)
│  │     ├─ MoveRequest
│  │     ├─ StartCharge
│  │     ├─ ReleaseCharge
│  │     ├─ JoinArena
│  │     ├─ LeaveArena
│  │     ├─ TeleportRequest
│  │     ├─ AttributeUpgrade
│  │     ├─ RequestRespawn
│  │     ├─ PurchaseRespawn
│  │     ├─ PurchaseMatchBuff
│  │     ├─ PrestigeReset
│  │     ├─ ToggleSpecialUpgrade
│  │     ├─ DebugSpawnFood
│  │     ├─ DebugResetSling
│  │     ├─ StateUpdate
│  │     ├─ UIStateUpdate
│  │     ├─ GameplayFeedback
│  │     ├─ MatchStateUpdate
│  │     ├─ RoundResult
│  │     └─ PopupMessage
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
│  ├─ Tests
│  │  └─ CoreLoopTests.server.lua
│  │
│  └─ Services
│     ├─ EventBus.lua
│     ├─ PlayerStateService.lua
│     ├─ PlayerService.lua
│     ├─ SlingService.lua
│     ├─ SlingshotService.lua (adapter)
│     ├─ CollisionService.lua
│     ├─ CombatService.lua
│     ├─ DamagePipelineService.lua
│     ├─ GrowthService.lua
│     ├─ SkillService.lua
│     ├─ MonetizationService.lua
│     ├─ TrapService.lua
│     ├─ MapService.lua
│     ├─ MapLoader.lua
│     ├─ RoundService.lua
│     ├─ FoodService.lua        [INFERRED legacy/overlap]
│     ├─ MovementService.lua    [INFERRED deprecated/unused]
│     └─ ChargeService.lua      [KNOWN deprecated]
│
## 🟩 StarterPlayer
├─ StarterPlayer
│  └─ StarterPlayerScripts
│     └─ Client  -> src/StarterPlayer
│        └─ StarterPlayerScripts
│           ├─ SlingMovement.client.lua      (active input / charge script)
│           ├─ UIBinder.client.lua           (active UI bootstrap; event-driven rebinding)
│           ├─ SlingController.client.lua    [UNKNOWN active status]
│           └─ ClientController.client.lua   (legacy inert)
│
## 🟨 StarterGui
├─ StarterGui  -> src/StarterGui
│  ├─ LobbyUI (ScreenGui)
│  │  └─ RootFrame
│  │     ├─ UICorner
│  │     ├─ DebugFood
│  │     ├─ DebugReset
│  │     ├─ JoinButton
│  │     ├─ LeaveButton
│  │     ├─ HpLabel
│  │     ├─ LevelLabel
│  │     ├─ MapName
│  │     ├─ RespawnLabel
│  │     └─ StatusLabel
│  │
│  ├─ OnlineRewardUI (ScreenGui)
│  │  └─ Root
│  │     ├─ UICorner
│  │     ├─ Content
│  │     │  ├─ Grid (UIGridLayout)
│  │     │  └─ RewardSlotTemplate
│  │     ├─ Footer
│  │     │  ├─ ClaimAll (TextButton)
│  │     │  └─ SkipAll (TextButton)
│  │     └─ Header
│  │        ├─ UICorner
│  │        ├─ CloseButton (TextButton)
│  │        └─ Title (TextLabel)
│  │
│  ├─ DailyLoginUI (ScreenGui)
│  │  ├─ MainPanel (Frame)
│  │  │  ├─ UICorner
│  │  │  ├─ UIPadding
│  │  │  ├─ Content (Frame)
│  │  │  │  ├─ Day7Big (Frame)
│  │  │  │  │  ├─ UICorner
│  │  │  │  │  ├─ UIStroke
│  │  │  │  │  ├─ ClaimButton (TextButton)
│  │  │  │  │  ├─ Icon (ImageLabel)
│  │  │  │  │  ├─ Claimed (TextLabel)
│  │  │  │  │  ├─ Description (TextLabel)
│  │  │  │  │  ├─ Timer (TextLabel)
│  │  │  │  │  └─ Title (TextLabel)
│  │  │  │  └─ LeftGrid (Frame)
│  │  │  │     ├─ UIGridLayout
│  │  │  │     └─ SlotDailyLoginRewardTemplate -- Script Spawn in run time
│  │  │  └─ Header (Frame)
│  │  │     ├─ CloseButton (TextButton)
│  │  │     └─ Title (TextLabel)
│  │  └─ Overlay (Frame/TextButton)
│  │
│  ├─ ShopGui (ScreenGui)
│  │  └─ Main (ImageLabel)
│  │     ├─ UICorner
│  │     ├─ UIGradient
│  │     ├─ UIStroke
│  │     ├─ Buttons (Frame)
│  │     │  ├─ UIListLayout
│  │     │  ├─ Launcher (ImageButton/Frame)
│  │     │  ├─ Dinamonds (ImageButton/Frame)
│  │     │  └─ Items (ImageButton/Frame)
│  │     ├─ Dinamonds (Frame)
│  │     │  ├─ UIListLayout
│  │     │  └─ Content (Frame)
│  │     │     ├─ UICorner
│  │     │     ├─ UIListLayout
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
│  │     │  ├─ UIListLayout
│  │     │  ├─ Spin1 (TextButton)
│  │     │  └─ Spin2 (TextButton)
│  │     ├─ TurnsDisplay
│  │     ├─ WheelContainer
│  │     │  ├─ UICorner
│  │     │  ├─ UIStroke
│  │     │  ├─ Pointer
│  │     │  └─ GachaWheel (ImageLabel)
│  │     ├─ CloseButton (TextButton)
│  │     └─ Title (TextLabel)
│  │ 
│  ├─ InventoryUI (ScreenGui)
│  │  ├── Root (Frame)
│  │  │   ├── UICorner
│  │  │   ├── Header (Frame)
│  │  │   │   ├─ CloseButton (TextButton)
│  │  │   │   └─ Title (TextLabel)
│  │  │   ├── Tabs (Frame)
│  │  │   │   ├─ UIListLayout
│  │  │   │   ├─ ItemsTab (TextButton)
│  │  │   │   └─ SlingTab (TextButton)
│  │  │   ├── BodySling (Frame)
│  │  │   │   ├── Footer (Frame)
│  │  │   │   │   └─ CapacityLabel (TextLabel)
│  │  │   │   ├── GridContainer (Frame)
│  │  │   │   │   ├─ UIGridLayout
│  │  │   │   │   └─ Slot1, Slot2, Slot3, Slot4 (Frames) -- Script Spawn in run time
│  │  │   │   └── RightPanel (Frame)
│  │  │   │       ├─ UIListLayout
│  │  │   │       ├─ ActionButtons (Frame)
│  │  │   │       │   ├─ UIListLayout
│  │  │   │       │   ├─ DeleteButton (TextButton)
│  │  │   │       │   ├─ EquipButton (TextButton)
│  │  │   │       │   └─ UpgradeButton (TextButton)
│  │  │   │       ├─ Stats (Frame)
│  │  │   │       │   ├─ UIListLayout
│  │  │   │       │   └─ Damage, HP, Range, Regen (TextLabels)
│  │  │   │       └─ SelectedName (TextLabel)
│  │  │   └── BodyItems (Frame)
│  │  │       ├── GridContainer (Frame)
│  │  │       │   ├─ UIGridLayout
│  │  │       │   └─ Slot1, Slot2, Slot3, Slot4 (Frames) -- Script Spawn in run time
│  │  │       └── RightPanel (Frame)
│  │  │           ├─ UIListLayout
│  │  │           ├─ ActionButtons (Frame)
│  │  │           │   ├─ UIListLayout
│  │  │           │   ├─ DeleteButton (TextButton)
│  │  │           │   └─ UseButton (TextButton)
│  │  │           ├─ Stats (Frame)
│  │  │           │   ├─ UIListLayout
│  │  │           │   └─ ItemStat1, ItemStat2, ItemStat3 (TextLabels)
│  │  │           ├─ Description (TextLabel)
│  │  │           └─ SelectedName (TextLabel)
│  │  ├── Overlay (Frame)
│  │  └── UpgradePopup (Frame)
│  │      ├─ UICorner
│  │      ├─ Cancel (TextButton)
│  │      ├─ Confirm (TextButton)
│  │      ├─ ConfirmText (TextLabel)
│  │      └─ PopupTitle (TextLabel)
│  │
│  ├─ MatchUI (ScreenGui)
│  │  └─ RootFrame
│  │     ├─ UICorner
│  │     ├─ AlivePlayersLabel
│  │     ├─ StatusLabel
│  │     ├─ TimerLabel
│  │     └─ WinnerPopup
│  │
│  ├─ StatsUI (ScreenGui)
│  │   └─ RootFrame
│  │     ├─ UICorner
│  │     ├─ GoldLabel
│  │     ├─ ScoreLabel
│  │     ├─ TitleLabel
│  │     └─ WinsLabel
│  │
│  ├─ MainHUD (ScreenGui)
│  │  └─ Root
│  │     ├─ BuffContainer
│  │     │  ├─ UIListLayout
│  │     │  ├─ Buff1
│  │     │  └─ Buff2
│  │     ├─ ExpProress
│  │     │  ├─ ExpBarBackground
│  │     │  ├─ ExpBarFill
│  │     │  ├─ ExpValueLabel
│  │     │  └─ LevelOnBarLabel
│  │     ├─ LeftMenu
│  │     │  ├─ UIGridLayout
│  │     │  ├─ DailyButton (TextButton)
│  │     │  ├─ InventoryButton (TextButton)
│  │     │  ├─ OnlineRewardButton (TextButton)
│  │     │  ├─ SettingButton (TextButton)
│  │     │  └─ SpinButton (TextButton)
│  │     ├─ RankFrame
│  │     │  ├─ UICorner
│  │     │  ├─ UIPadding
│  │     │  ├─ List
│  │     │  │  ├─ UIListLayout
│  │     │  │  └─ Player1
│  │     │  └─ Title (TextLabel)
│  │     ├─ QuickHP (ImageButton)
│  │     └─ Home (TextButton)
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
├─ Workspace  -> src/Workspace
│  └─ Maps
│     ├─ LobbyMap
│     │  ├─ SpawnPoints
│     │  │  └─ LobbySpawn
│     │  ├─ GachaSpin
│     │  │  └─ Spinwheel
│     │  └─ Gate (optional join trigger)
│     │
│     └─ ArenaMap
│        ├─ SpawnPoints
│        │
│        ├─ FoodSpawns
│        │  ├─ EdgeZones
│        │  │  ├─ FoodSpawn_01
│        │  │  ├─ FoodSpawn_02
│        │  │  ├─ FoodSpawn_03
│        │  │  ├─ FoodSpawn_04
│        │  │  ├─ FoodSpawn_05
│        │  │  └─ FoodSpawn_..N
│        │  │
│        │  ├─ MidZones
│        │  │  ├─ FoodSpawn_01
│        │  │  ├─ FoodSpawn_02
│        │  │  ├─ FoodSpawn_03
│        │  │  ├─ FoodSpawn_04
│        │  │  ├─ FoodSpawn_05
│        │  │  └─ FoodSpawn_..N
│        │  │
│        │  └─ CenterZones
│        │     ├─ FoodSpawn_01
│        │     ├─ FoodSpawn_02
│        │     ├─ FoodSpawn_03
│        │     ├─ FoodSpawn_04
│        │     ├─ FoodSpawn_05
│        │     └─ FoodSpawn_..N
│        │
│        ├─ FoodContainer
│        ├─ Traps
│        │     ├─ Trap_01
│        │     ├─ Trap_02
│        │     └─ Trap_..N
│        ├─ TrapContainer
│        ├─ ExitZone
│        ├─ SafeSpawnZone
│        ├─ AntiGiantZone
│        ├─ SizeRestrictedCorridor
│        └─ WallContainer
│
## 🟪 ServerStorage
├─ ServerStorage [INFERRED runtime dependency]
│  ├─ FoodTemplates
│  │  ├─ Food1
│  │  ├─ Food2
│  │  ├─ Food3
│  │  ├─ Food4
│  │  ├─ Food5
│  │  ├─ Food6
│  │  └─ Food7
│  │
│  └─ TrapTemplates
│     ├─ MineTrap
│     └─ SpikeTrap
│
## ⚫ Runtime Workspace
└─ Workspace
   └─ Runtime
      └─ SlingPawns
         └─ SlingPawns  [INFERRED auto-created by PlayerService]


Notes:
- All production `ReplicatedStorage.SlingArenaRemotes.*` instances are defined statically through `src/ReplicatedStorage/SlingArenaRemotes/*.model.json`.
- Several runtime-critical map/template instances (e.g. `Workspace/Maps`, `ServerStorage/FoodTemplates`)
  are not present as files in the repo and must be created manually in Roblox Studio.
