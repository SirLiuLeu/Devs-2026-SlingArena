# Sling Arena – SYSTEM FREEZE Architecture Ownership (Safe Refactor Reference)

This document defines **final ownership boundaries** and **safe migration direction**.
All cross-service communication must go through EventBus where possible; no circular dependencies are allowed.

## Global Freeze Constraints
- No circular dependencies.
- No God Object services.
- Friendly Fire validation must be done only in `DamagePipelineService` using `TeamService`.
- `SlingService` keeps movement/charge logic via internal submodules.
- `MapLoader` remains a helper/legacy entrypoint under `MapService` ownership.

---

## Core

### PlayerStateService
- **Owns:** Canonical player runtime state (HP, EXP, level, map/state flags, movement flags, temporary effects).
- **Responsibilities:** State mutation APIs, state publish (`StateUpdate`), stat recomputation.
- **Called by:** SlingService, DamagePipelineService, GrowthService, RoundService, TeamService, PlayerService, SlingAbilityService, LeaderboardService, MonetizationService.
- **Dependencies:** Shared config/constants.

### PlayerService
- **Owns:** Pawn lifecycle and player↔pawn mapping.
- **Responsibilities:** spawn/respawn/despawn pawn, root resolver, alive checks.
- **Called by:** RoundService, DamagePipelineService, MapService, MonetizationService.
- **Dependencies:** PlayerStateService, MapService.

### RoundService
- **Owns:** Round phase lifecycle and participant roster.
- **Responsibilities:** Join/Leave flow, round transitions, round-end signaling.
- **Called by:** Round remotes + event triggers.
- **Dependencies:** PlayerService, PlayerStateService, MapService, LeaderboardService.

### MapService
- **Owns:** Active map selection and world resource indexing (spawns, traps, zones, gates).
- **Responsibilities:** Activate/generate map resources, world queries, teleport/debug map requests.
- **Called by:** RoundService, PlayerService, FoodService, TrapService, SafeZoneService.
- **Dependencies:** FoodService, TrapService; helper ownership includes MapLoader.

---

## Simulation

### SlingService
- **Owns:** Authoritative movement + charge + launch request pipeline.
- **Responsibilities:** Validate and process launch/move remotes, maintain movement/charge/recover state transitions, emit launch events.
- **Called by:** `MoveRequest`, `StartCharge`, `ReleaseCharge`, `RequestLaunch`.
- **Dependencies:** PlayerService, PlayerStateService, RoundService, internal submodules (`SlingMovement`, charge module).
- **Constraint:** Must not execute damage resolution directly.

### CollisionService
- **Owns:** Collision detection pass and collision candidate generation.
- **Responsibilities:** Detect player/trap/gate/zone interactions and emit normalized events.
- **Called by:** Heartbeat loop.
- **Dependencies:** PlayerService, PlayerStateService, MapService, EventBus.

### CombatService
- **Owns:** Pure formula calculations only.
- **Responsibilities:** Compute impact damage/knockback values.
- **Called by:** DamagePipelineService pipeline.
- **Dependencies:** Balance config.

### DamagePipelineService
- **Owns:** Final damage authority.
- **Responsibilities:** Apply all damage, enforce Friendly Fire OFF with TeamService, kill/assist context emission, feedback publication.
- **Called by:** CollisionService, TrapService, SafeZoneService, SlingAbilityService.
- **Dependencies:** PlayerStateService, PlayerService, CombatService, TeamService, EventBus.

### SafeZoneService
- **Owns:** Safe-zone shrink simulation and environment DOT.
- **Responsibilities:** Shrink visual/logic zone, compute outside-zone DOT from 1%→10% HP/s, forward damage events to DamagePipelineService, publish `ZoneUpdate`.
- **Called by:** RoundService phase scheduler.
- **Dependencies:** MapService, DamagePipelineService, EventBus.

---

## Gameplay

### SlingAbilityService
- **Owns:** Ability orchestration only.
- **Responsibilities:** Listen to sling/combat events and delegate effects:
  - Invisibility/Clone/EXP buff → PlayerStateService.
  - Stun/Ally-heal/combat effects → DamagePipelineService.
- **Called by:** EventBus signals from SlingService + collision/damage flow.
- **Dependencies:** SlingService signals, PlayerStateService, DamagePipelineService, EventBus.
- **Constraint:** No direct low-level combat/state mutation outside owner APIs.

### GrowthService
- **Owns:** EXP progression routing.
- **Responsibilities:** Receive EXP intents from FoodService + DamagePipelineService combat context; process assist EXP (50%).
- **Called by:** EventBus (`FoodConsumed`, `DamageDealt`, `PlayerKilled`, assist events).
- **Dependencies:** PlayerStateService, EventBus.
- **Constraint:** Must not depend directly on TeamService.

### FoodService
- **Owns:** Food spawn/despawn/respawn and food type classification.
- **Responsibilities:**
  - Mini Food: touch-based consume path.
  - HP Food: combat-based consume path.
  - Emit reward intents only.
- **Called by:** MapService and touch/collision hooks.
- **Dependencies:** MapService, PlayerService, EventBus.
- **Constraint:** Must not grant EXP directly; GrowthService is the only EXP owner.

### TrapService
- **Owns:** Trap trigger handling and trap damage context.
- **Responsibilities:** Trap cooldown/rules and damage event emission.
- **Called by:** Collision/Map events.
- **Dependencies:** MapService, DamagePipelineService, EventBus.

### TeamService
- **Owns:** Team relationship domain.
- **Responsibilities:** Team creation/management (max size 2), relationship query `IsTeammate(playerA, playerB)`.
- **Called by:** DamagePipelineService, RoundService.
- **Dependencies:** PlayerStateService.

---

## World

### World ownership boundary
- Collision sensing: CollisionService.
- Hazard/zone logic: TrapService + SafeZoneService.
- Map topology/resources: MapService.

---

## Meta

### LeaderboardService
- **Owns:** End-of-round ranking and reward sequencing.
- **Responsibilities:** winner/rank resolve, reward trigger (EXP/Gems), enforce 15-second reward delay after round end.
- **Called by:** Round end flow.
- **Dependencies:** RoundService, PlayerStateService, GrowthService.

### MonetizationService
- **Owns:** Monetization actions (respawn purchase, match buff purchase, prestige reset).
- **Responsibilities:** Validate and execute monetization remotes against player state APIs.
- **Called by:** Monetization remotes.
- **Dependencies:** PlayerStateService, PlayerService.

---

## Infrastructure

### EventBus
- **Owns:** Pub/sub messaging for service decoupling.
- **Responsibilities:** register/listen/dispatch events.
- **Called by:** All services.
- **Dependencies:** none.

### RemoteContracts
- **Owns:** Remote name registry and validators.
- **Responsibilities:** single source for remote contract keys + payload validation hooks.
- **Called by:** Remote-owning services.
- **Dependencies:** Shared constants/types.

---

## Frozen Consolidation Decisions
- SlingshotService ownership merged into SlingService.
- MovementService removed (absorbed by SlingService internal module).
- ChargeService removed (absorbed by SlingService internal module).
- SkillService removed:
  - Attribute upgrade ownership → PlayerStateService/GrowthService boundary.
  - Ability toggle ownership → SlingAbilityService.
  - Consumables ownership → PlayerStateService (until Inventory system takes ownership).

---

## Deprecated / Pending Review

### Deprecated
- Fixed TeamRed/TeamBlue auto-balance as primary team model.
- EXP mutation from non-Growth services.
- Friendly-fire checks outside DamagePipelineService.

### Pending Review
- Runtime still contains legacy `SkillService.lua` and wiring in `Main.server.lua`; remove after remote-owner reassignment.
- SafeZoneService/SlingAbilityService are not yet implemented as runtime modules.
- Ghost/Spectating state machine is not yet enforced in runtime constants/services.
