# PROJECT_TREE.md

This tree describes current project organization and intended Roblox DataModel mapping
from `default.project.json` + source layout.

Legend:
- **** exact from code/config
- [INFERRED] likely runtime structure from patterns
- [UNKNOWN] not confirmed in repository assets


DataModel
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
│  ├─ SlingArenaRemotes
│  │  ├─ (RemoteEvents from *.model.json)
│  │  │  ├─ JoinArena
│  │  │  ├─ LeaveArena
│  │  │  ├─ MoveRequest
│  │  │  ├─ ActivateSkill
│  │  │  ├─ AttributeUpgrade
│  │  │  ├─ RequestRespawn
│  │  │  ├─ RequestMatchBuff
│  │  │  └─ UIStateUpdate
│  │  │
│  │  └─ (Auto-created at runtime if missing) [INFERRED]
│  │     ├─ StartCharge
│  │     ├─ ReleaseCharge
│  │     ├─ GameplayFeedback
│  │     ├─ StateUpdate
│  │     ├─ MatchStateUpdate
│  │     ├─ RoundResult
│  │     ├─ PopupMessage
│  │     ├─ PurchaseRespawn
│  │     ├─ PurchaseMatchBuff
│  │     ├─ PrestigeReset
│  │     ├─ ToggleSpecialUpgrade
│  │     ├─ TeleportRequest
│  │     ├─ DebugSpawnFood
│  │     └─ DebugResetSling
│  │
│  ├─ Client  -> src/ReplicatedStorage/Client
│  │  ├─ Controllers
│  │  │  └─ UIController.lua
│  │  └─ Services
│  │     └─ LobbyClientService.lua
│  │
│  └─ Assets
│     └─ SlingModel.model.json
│
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
├─ StarterPlayer
│  └─ StarterPlayerScripts
│     └─ Client  -> src/StarterPlayer
│        └─ StarterPlayerScripts
│           ├─ SlingMovement.client.lua      (active input / charge script)
│           ├─ UIBinder.client.lua           (active UI bootstrap)
│           ├─ SlingController.client.lua    [UNKNOWN active status]
│           └─ ClientController.client.lua   (legacy inert)
│
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
│  └─ SlingArenaUI [INFERRED legacy / alternative UI stack]
│        ├─ SlingUI (ScreenGui)
│        │   ├─ JoystickRoot (Frame)
│        │   │  ├─ Base (Frame)
│        │   │  └─ Thumb (Frame)
│        │   │
│        │   ├─ ChargeBar (Frame)
│        │   │  └─ Fill (Frame)
│        │   │
│        │   └─ DirectionArrow (ImageLabel)
│        ├─ MainUI.client.lua (deprecated)
│        ├─ UIController.lua
│        └─ Components/*
│
├─ Workspace  -> src/Workspace
│  └─ Maps
│     ├─ LobbyMap
│     │  ├─ SpawnPoints
│     │  │  └─ LobbySpawn
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
└─ Workspace
   └─ Runtime
      └─ SlingPawns
         └─ SlingPawns  [INFERRED auto-created by PlayerService]


Notes:
- Several runtime-critical instances (e.g. `Workspace/Maps`, `ServerStorage/FoodTemplates`)
  are not present as files in the repo and must be created manually in Roblox Studio.
