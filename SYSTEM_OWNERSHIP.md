# Sling Arena – SYSTEM FREEZE Architecture Ownership (Final)

This document is the frozen ownership reference for server-side architecture.
All services are categorized and constrained to prevent overlap, God Objects, and circular dependencies.
Cross-service communication must use `EventBus` for decoupled flow.

## Global architecture constraints (freeze)
- No circular dependencies between services.
- One service = one clear ownership boundary.
- Cross-service orchestration must use `EventBus` (direct calls allowed only for owned APIs that do not create cycles).
- `SlingService` must stay movement/launch focused and internally modularized (e.g., movement/charge submodules).
- Friendly Fire validation must be centralized in `DamagePipelineService` and use `TeamService` relationship queries.
- `MapLoader` is **not** a service; it remains a helper/legacy entrypoint under `MapService` ownership.

---

## 1) Core Services

### PlayerStateService
- **Owns:** Canonical runtime player state (HP, EXP, Level, movement flags, visibility/stun flags, arena state, temporary buffs).
- **Responsibilities:**
  - Read/write validated player state.
  - Publish `StateUpdate` snapshots.
  - Apply stat recalculation and derived values.
  - Provide state-query APIs to all gameplay systems.
- **Called by:** SlingService, DamagePipelineService, GrowthService, TeamService, RoundService, PlayerService, SlingAbilityService, LeaderboardService, Meta services.
- **Dependencies:** Shared config/constants, EventBus.

### PlayerService
- **Owns:** Sling pawn lifecycle and player-to-pawn mapping.
- **Responsibilities:** Spawn/despawn/respawn pawns, root accessors, alive checks, teleport support, avatar enforcement.
- **Called by:** RoundService, DamagePipelineService, MapService, MonetizationService.
- **Dependencies:** MapService, PlayerStateService.

### RoundService
- **Owns:** Round lifecycle state machine and arena participant roster.
- **Responsibilities:** Lobby → match start → active round → round end transitions; join/leave arena flow; round result trigger.
- **Called by:** Join/Leave remotes, lobby gate events, death/end events.
- **Dependencies:** MapService, PlayerService, PlayerStateService, LeaderboardService.

### MapService
- **Owns:** Active map selection and map resource indexing (spawns, gates, traps, zones).
- **Responsibilities:** Activate/generate map resources, expose world query APIs, route map-level debug/admin teleport.
- **Called by:** RoundService, PlayerService, FoodService, TrapService.
- **Dependencies:** Helper module (`MapLoader` legacy ownership), FoodService, TrapService.

---

## 2) Simulation Services

### SlingService
- **Owns:** Authoritative movement/charge/release input pipeline and launch state.
- **Responsibilities:**
  - Validate `MoveRequest`, `StartCharge`, `ReleaseCharge`.
  - Manage movement/charge/recovery state transitions.
  - Emit launch/collision-relevant signals on EventBus (e.g., `SlingLaunched`).
  - Keep movement and charge logic internally modularized (submodules); absorb removed MovementService/ChargeService logic.
- **Called by:** Client movement/launch remotes.
- **Dependencies:** PlayerService, PlayerStateService, RoundService, internal movement helper modules.
- **Constraint:** MUST NOT become a God Object; no combat resolution ownership.

### CollisionService
- **Owns:** Collision detection pass and collision candidate generation.
- **Responsibilities:** Detect player-player, trap, gate, wall, and exit-zone interactions; emit standardized collision events.
- **Called by:** Heartbeat loop.
- **Dependencies:** PlayerService, PlayerStateService, MapService, EventBus.

### CombatService
- **Owns:** Pure combat formulas only.
- **Responsibilities:** Compute impact damage/knockback values from state + velocity.
- **Called by:** DamagePipelineService (and collision preprocessing flow).
- **Dependencies:** Balance config.

### DamagePipelineService
- **Owns:** Final damage authority and damage rule enforcement.
- **Responsibilities:**
  - Single entry for applying player/environment damage.
  - Enforce Friendly Fire OFF via TeamService checks.
  - Handle kill attribution, assist context emission, and downstream EXP context events.
  - Apply knockback/effects and publish combat feedback.
- **Called by:** CollisionService, TrapService, SafeZoneService, SlingAbilityService.
- **Dependencies:** PlayerStateService, PlayerService, CombatService, TeamService, EventBus.

### SafeZoneService
- **Owns:** Shrinking safe-zone simulation and environment pressure.
- **Responsibilities:**
  - Visual + logical safe-zone shrink timeline.
  - Compute outside-zone DOT ramp from **1% → 10% HP/s**.
  - Forward environment damage events to `DamagePipelineService`.
- **Called by:** RoundService tick/phase orchestration.
- **Dependencies:** MapService, DamagePipelineService, EventBus.

---

## 3) Gameplay Services

### SlingAbilityService
- **Owns:** Sling passive/trigger ability orchestration.
- **Responsibilities (orchestrator only):**
  - Listen to SlingService/EventBus signals (e.g., launch/hit events).
  - Delegate invisibility/clone and EXP buff state effects to `PlayerStateService`.
  - Delegate stun/heal/damage-side effects to `DamagePipelineService` or state APIs.
  - Never execute direct combat/state mutation outside delegated service APIs.
- **Called by:** EventBus signals from SlingService and collision/damage flow.
- **Dependencies:** SlingService signals, PlayerStateService, DamagePipelineService, EventBus.
- **Constraint:** MUST NOT directly modify combat or player state bypassing owner services.

### FoodService
- **Owns:** Food entity lifecycle and food-type classification.
- **Responsibilities:**
  - Spawn/despawn/respawn food.
  - Classify food:
    - Mini Food = touch-based.
    - HP Food = combat-based resolution.
  - Publish reward intents/events only; no direct EXP grants.
- **Called by:** MapService load/resource activation, collision/touch hooks.
- **Dependencies:** MapService, PlayerService, EventBus, GrowthService (event route).
- **Constraint:** MUST NOT grant EXP directly; all EXP reward flow goes through `GrowthService`.

### GrowthService
- **Owns:** EXP and level progression event routing.
- **Responsibilities:**
  - Receive EXP intents from FoodService and Combat/DamagePipeline events.
  - Process assist EXP (50%) from combat context emitted by DamagePipelineService.
  - Apply progression through `PlayerStateService` only.
- **Called by:** EventBus (`FoodConsumed`, `DamageDealt`, `PlayerKilled`, assist events).
- **Dependencies:** PlayerStateService, EventBus.
- **Constraint:** MUST NOT directly depend on `TeamService`.

### TrapService
- **Owns:** Trap trigger handling and trap context generation.
- **Responsibilities:** Map trap interpretation, trap cooldowning, trap damage event emit to damage pipeline.
- **Called by:** CollisionService/MapService events.
- **Dependencies:** MapService, DamagePipelineService, EventBus.

### TeamService
- **Owns:** Team relationship model (party semantics), not combat resolution.
- **Responsibilities:**
  - Team creation/management with **max team size = 2**.
  - Relationship queries: `IsTeammate(playerA, playerB)`.
  - Provide relationship data for DamagePipelineService and indirect growth context.
- **Called by:** DamagePipelineService, RoundService/team UX flows.
- **Dependencies:** PlayerStateService.
- **Constraints:** Friendly Fire is OFF and enforced only by DamagePipelineService.

---

## 4) World Services

### World interaction ownership boundary
- World collision sensing remains in `CollisionService`.
- World hazards/zones are interpreted by `TrapService` and `SafeZoneService`.
- Map topology remains owned by `MapService`.

(Freeze note: no standalone WorldService module exists yet; ownership is intentionally distributed across the above world-facing services.)

---

## 5) Meta Services

### LeaderboardService
- **Owns:** End-of-round ranking pipeline and reward presentation sequencing.
- **Responsibilities:**
  - Winner/rank calculation from round completion context.
  - Rank display and reward distribution trigger (EXP/Gems).
  - Enforce **15-second delay** after round end before reward sequence execution.
- **Called by:** RoundService and EventBus round-end/death signals.
- **Dependencies:** RoundService, PlayerStateService, GrowthService/Meta reward adapters.

### MonetizationService
- **Owns:** Match monetization actions (respawn purchase, match buff purchase, prestige reset flow).
- **Responsibilities:** Validate and execute paid/free monetization requests through player-state APIs.
- **Called by:** monetization remotes.
- **Dependencies:** PlayerStateService, PlayerService.

---

## 6) Infrastructure Services

### EventBus
- **Owns:** Pub/sub backbone for decoupled cross-service communication.
- **Responsibilities:** Service event registration and event fan-out.
- **Called by:** All server services.
- **Dependencies:** None.

### RemoteContracts (shared infrastructure contract)
- **Owns:** Remote name registry and payload validators.
- **Responsibilities:** Centralized remote key consistency and input schema validation hooks.
- **Called by:** Services handling remotes.
- **Dependencies:** Shared constants/types.

---

## 7) Consolidation decisions (frozen)
- `SlingshotService` ownership is merged into `SlingService` (canonical movement/launch owner).
- `MovementService` removed (logic consolidated as SlingService internal movement module).
- `ChargeService` removed (logic consolidated as SlingService internal charge module).
- `MapLoader` converted to helper ownership under `MapService` (legacy entrypoint only).

---

## 8) Deprecated / Pending Review

### Deprecated
- Fixed `TeamRed/TeamBlue` auto-balance as primary team model (conflicts with team-size-2 design).
- Any direct EXP mutation from non-Growth services.
- Any Friendly Fire checks outside DamagePipelineService.

### Pending review (not core freeze blockers)
- `SkillService` overlaps with `SlingAbilityService` orchestration responsibilities; migrate SkillService-owned gameplay passives into SlingAbilityService ownership boundary.
- `CombatService` currently invoked from collision-stage flow; formalize DamagePipelineService as the sole combat gate while preserving CombatService as pure formula module.
- Existing respawn timing/flow in damage pipeline and monetization should be reconciled with round-phase ghost/final-phase restrictions before implementation lock.

