# Sling Arena – AI Context (Compact Source of Truth)

## 1) Design pillars (from Rule_DESIGN)
- Round-based physics survival arena.
- Loop: Lobby → Early combat/farm → Final phase pressure → Last alive wins → result/reset.
- Server-authoritative movement/combat/state.
- Food farming drives EXP/level; collision/launch is core combat.

## 2) Active architecture snapshot

### Server (`src/ServerScriptService/Services`)
- EventBus
- PlayerStateService
- PlayerService
- TeamService (friendly-check helper; no fixed red/blue allocation)
- SlingService
- SlingMovement
- MapService
- FoodService
- CollisionService
- CombatService
- DamagePipelineService
- GrowthService
- TrapService
- RoundService
- SkillService
- LeaderboardService

### Client
- StarterPlayer scripts: `SlingMovement.client.lua`, `SlingController.client.lua`, `UIBinder.client.lua`.
- UI controllers/services under `ReplicatedStorage/Client` (Inventory, Shop, DailyLogin, OnlineReward, Spin, Lobby client service).
- Sling touch UI bootstrap: `StarterGui/SlingArenaUI/SlingUIController.client.lua`.

## 3) Current remotes contract (single list)

### Client → Server
- `MoveRequest(Vector3)`
- `StartCharge(Vector3)`
- `ReleaseCharge(Vector3)`
- `JoinArena()`
- `LeaveArena()`
- `TeleportRequest(mapName, spawnName)`
- `DebugSpawnFood(mapName)` *(debug)*
- `DebugResetSling()` *(debug)*
- `ConsumeHpPotion()`

### Server → Client
- `StateUpdate(state)`
- `UIStateUpdate(payload)`
- `MatchStateUpdate(payload)`
- `RoundResult(payload)`
- `GameplayFeedback(payload)`
- `PopupMessage(payload)`

# SPAWN RULE

- Roblox default character MUST NOT be used
- Players are represented by Sling models only
- CharacterAutoLoads must be disabled
- SlingService is responsible for spawning player representation
