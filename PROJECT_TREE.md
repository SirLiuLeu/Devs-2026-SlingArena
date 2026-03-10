# PROJECT_TREE.md

This tree describes **current project organization and intended Roblox DataModel mapping** from `default.project.json` + source layout.

Legend:
- **[KNOWN]** exact from code/config.
- **[INFERRED]** likely runtime structure from patterns.
- **[UNKNOWN]** not confirmed in repository assets.

```text
DataModel [KNOWN]
├─ ReplicatedStorage [KNOWN]
│  ├─ Shared [KNOWN] -> src/ReplicatedStorage/Shared
│  │  ├─ Config [KNOWN]
│  │  │  ├─ BalanceConfig.lua
│  │  │  ├─ Config.lua
│  │  │  ├─ LevelConfig.lua
│  │  │  ├─ SlingshotConfig.lua
│  │  │  └─ TrapConfig.lua
│  │  ├─ Types [KNOWN]
│  │  │  ├─ PlayerState.lua
│  │  │  └─ CombatTypes.lua
│  │  ├─ Utils [KNOWN]
│  │  │  └─ PathResolver.lua
│  │  ├─ ProjectTreeSpec.lua [KNOWN]
│  │  └─ RemoteContracts.lua [KNOWN]
│  ├─ SlingArenaRemotes [KNOWN]
│  │  ├─ (RemoteEvents from *.model.json) [KNOWN]
│  │  │  ├─ JoinArena
│  │  │  ├─ LeaveArena
│  │  │  ├─ MoveRequest
│  │  │  ├─ ActivateSkill
│  │  │  ├─ AttributeUpgrade
│  │  │  ├─ RequestRespawn
│  │  │  ├─ RequestMatchBuff
│  │  │  └─ UIStateUpdate
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
│  ├─ Client [KNOWN] -> src/ReplicatedStorage/Client
│  │  ├─ Controllers/UIController.lua
│  │  └─ Services/LobbyClientService.lua
│  └─ Assets [KNOWN]
│     └─ SlingModel.model.json
│
├─ ServerScriptService [KNOWN] -> src/ServerScriptService
│  ├─ Main.server.lua [KNOWN]
│  ├─ MapLoader.server.lua [KNOWN]
│  ├─ SlingService.server.lua [KNOWN]
│  ├─ Tests
│  │  └─ CoreLoopTests.server.lua
│  └─ Services [KNOWN]
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
│     ├─ FoodService.lua [INFERRED legacy/overlap]
│     ├─ MovementService.lua [INFERRED deprecated/unused]
│     └─ ChargeService.lua [KNOWN deprecated]
│
├─ StarterPlayer [KNOWN]
│  └─ StarterPlayerScripts
│     └─ Client -> src/StarterPlayer [KNOWN by default.project.json]
│        └─ StarterPlayerScripts [KNOWN]
│           ├─ SlingMovement.client.lua (active input/charge script)
│           ├─ UIBinder.client.lua (active UI bootstrap)
│           ├─ SlingController.client.lua [UNKNOWN active status]
│           └─ ClientController.client.lua (legacy inert)
│
├─ StarterGui [KNOWN] -> src/StarterGui
│  ├─ LobbyUI [KNOWN]
│  ├─ MatchUI [KNOWN]
│  ├─ StatsUI [KNOWN]
│  ├─ SlingArenaDynamicUI [KNOWN]
│  └─ SlingArenaUI [INFERRED legacy/alternative UI stack]
│     ├─ MainUI.client.lua (deprecated)
│     ├─ UIController.lua
│     └─ Components/*
│
├─ Workspace [KNOWN] -> src/Workspace
│  └─ Maps [UNKNOWN in repo files; required at runtime]
│     ├─ LobbyMap [INFERRED required]
│     │  ├─ SpawnPoints/LobbySpawn
│     │  └─ Gate (optional join trigger)
│     ├─ Arena_01 [INFERRED required]
│     │  ├─ SpawnPoints/*
│     │  ├─ FoodSpawns/FoodSpawn* (Zone attrs optional)
│     │  ├─ FoodContainer
│     │  ├─ TrapSpawns/TrapSpawn* (optional)
│     │  ├─ TrapContainer
│     │  ├─ ExitZone / SafeSpawnZone / AntiGiantZone / SizeRestrictedCorridor (optional)
│     │  └─ WallContainer (optional)
│     └─ Arena_02 [INFERRED optional]
│
├─ ServerStorage [INFERRED runtime dependency]
│  ├─ FoodTemplates/*
│  └─ TrapTemplates/*
│
└─ Workspace/SlingPawns [INFERRED auto-created by PlayerService]
```

## Notes
- `default.project.json` maps `StarterPlayer/StarterPlayerScripts/Client` to `src/StarterPlayer`, then nested scripts exist under `src/StarterPlayer/StarterPlayerScripts`; this double nesting is intentional in current config but easy to misread.
- Several runtime-critical instances (e.g., `Workspace/Maps`, `ServerStorage/FoodTemplates`) are not present as files in repo and must be created in Roblox Studio.
