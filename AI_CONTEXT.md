# Sling Arena – AI Context (Compact Source of Truth)

This file replaces prior split references from `Rule_BUILD_SPEC.md` and `REMOTE_CONTRACTS.md` for day-to-day implementation context.

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

### Removed from active contract
- `AttributeUpgrade`, `ToggleSpecialUpgrade`
- `RequestRespawn`, `PurchaseRespawn`, `PurchaseMatchBuff`, `PrestigeReset`

## 4) Progression and scaling rules (implemented target)
- Level EXP requirement follows config curve.
- Level-up auto scaling: increase **HP, Damage, Size, Regen** by 3% per level.
- Do **not** scale Move Speed.
- Do **not** scale Launch Range.
- Manual point allocation UI/flow removed.

## 5) Team/game-loop updates
- TeamRed/TeamBlue fixed-team flow removed.
- Spawn routing no longer branches by TeamRed/TeamBlue spawn names.
- Friendly checks are state-based only when explicit TeamId is present.

## 6) Runtime-created RemoteEvents audit note
- Current codebase creates **no RemoteEvent instances at runtime**.
- All remotes are expected from `ReplicatedStorage/SlingArenaRemotes` model assets.

## 7) Known cleanup status
- DirectionArrow compatibility path removed; `DirectionIndicator` is required.
- Inventory test button script/UI paths removed (GiveSlingButton/GiveItemButton/InventoryTestUI).
- SlingStatsUI/manual stat allocation path removed from active UI controller flows.

## 8) Implementation guardrails for future sessions
- Keep server authoritative for physics/combat and state mutation.
- Avoid introducing new remotes unless explicitly required by design.
- Keep docs (`AI_CONTEXT.md`, `SYSTEM_OWNERSHIP.md`) synchronized with real code paths.
- Remove dead references when removing features (UI spec, remotes, services, tests).
