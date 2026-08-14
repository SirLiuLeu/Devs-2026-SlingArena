# Launcher Arena – SYSTEM FREEZE Architecture Ownership (Final)

This document is the frozen ownership reference for server-side architecture.
All services are categorized and constrained to prevent overlap, God Objects, and circular dependencies.
Cross-service communication must use `EventBus` for decoupled flow.

## Global architecture constraints (freeze)
- No circular dependencies between services.
- One service = one clear ownership boundary.
- Cross-service orchestration must use `EventBus` (direct calls allowed only for owned APIs that do not create cycles).
- `LauncherService` must stay movement/launch focused and internally modularized (e.g., movement/charge submodules).
- Friendly Fire validation must be centralized in `DamagePipelineService` and use `TeamService` relationship queries.
- `MapLoader` is **not** a service; it remains a helper/legacy entrypoint under `MapService` ownership.

---

## 1) Core Services

### PlayerStateService
- **Owns:** Canonical runtime player state (HP, EXP, Level, movement flags, visibility/stun flags, arena state, temporary buffs, final derived stats after launcher + Equipment modifiers).
- **Responsibilities:**
  - Read/write validated player state.
  - Publish `StateUpdate` snapshots.
  - Apply stat recalculation and derived values.
  - Provide state-query APIs to all gameplay systems.
- **Called by:** LauncherService, DamagePipelineService, GrowthService, TeamService, RoundService, PlayerService, LauncherAbilityService, LeaderboardService, Meta services.
- **Dependencies:** Shared config/constants, EventBus, `EquipmentStatResolver`, `PlayerDataService` for persistent Equipment and Diamond reads.

### PlayerDataService
- **Owns:** Persistent-oriented player profile data, including Diamonds, OwnedItems, instance-based `OwnedEquipment`, `EquippedEquipment`, quests, and progress points.
- **Responsibilities:** Normalize/default profile schema, act as the canonical Diamond ledger, route Diamond spending/grants, and expose Equipment ownership/equipped state to server services.
- **Called by:** EquipmentService, QuestService, FoodService, progression/meta reward services, PlayerStateService read-through synchronization.
- **Dependencies:** Data provider boundary and EventBus.

### PlayerService
- **Owns:** Launcher pawn lifecycle and player-to-pawn mapping.
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

### LauncherService
- **Owns:** Authoritative movement/charge/release input pipeline and launch state.
- **Responsibilities:**
  - Validate `MoveRequest`, `StartCharge`, `ReleaseCharge`.
  - Manage movement/charge/recovery state transitions.
  - Emit launch/collision-relevant signals on EventBus (e.g., `LauncherLaunched`).
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
- **Called by:** CollisionService, TrapService, SafeZoneService, LauncherAbilityService.
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

### LauncherAbilityService
- **Owns:** Launcher passive/trigger ability orchestration.
- **Responsibilities (orchestrator only):**
  - Listen to LauncherService/EventBus signals (e.g., launch/hit events).
  - Delegate invisibility/clone and EXP buff state effects to `PlayerStateService`.
  - Delegate stun/heal/damage-side effects to `DamagePipelineService` or state APIs.
  - Never execute direct combat/state mutation outside delegated service APIs.
- **Called by:** EventBus signals from LauncherService and collision/damage flow.
- **Dependencies:** LauncherService signals, PlayerStateService, DamagePipelineService, EventBus.
- **Constraint:** MUST NOT directly modify combat or player state bypassing owner services.

### EquipmentService
- **Owns:** Server-authoritative Equipment lifecycle and ownership mutations.
- **Responsibilities:** Read owned/equipped Equipment from PlayerDataService, validate fail-closed instance ownership, equip/unequip by owned instance ID, expose upgrade/pity entry points, and publish `EquipmentEquipped`, `EquipmentUnequipped`, and `EquipmentUpdated`.
- **Called by:** Equipment remotes and future shop/grant systems.
- **Dependencies:** PlayerDataService, EventBus, EquipmentConfig, EquipmentUpgradeConfig.
- **Constraint:** Client-supplied definition IDs are never accepted as proof of ownership.

### EquipmentEffectService
- **Owns:** Runtime orchestration of active Equipment effects.
- **Responsibilities:** Maintain multiple active effects per player, register modules under `EquipmentEffects`, dispatch `OnInit`, `OnLaunch`, `OnCollision`, `OnTick`, `OnAttack`, and `OnDestroy`, and use one shared Heartbeat connection for all Equipment effects.
- **Called by:** EventBus Equipment and gameplay signals.
- **Dependencies:** EventBus, EquipmentConfig, FlagService, PlayerStateService.

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


## 8) Deprecated / Pending Review

### Deprecated
- Fixed `TeamRed/TeamBlue` auto-balance as primary team model (conflicts with team-size-2 design).
- Any direct EXP mutation from non-Growth services.
- Any Friendly Fire checks outside DamagePipelineService.

### Pending review (not core freeze blockers)

- `CombatService` currently invoked from collision-stage flow; formalize DamagePipelineService as the sole combat gate while preserving CombatService as pure formula module.
- Existing respawn timing/flow in damage pipeline and monetization should be reconciled with round-phase ghost/final-phase restrictions before implementation lock.

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
- LaunchershotService ownership merged into LauncherService.
- MovementService removed (absorbed by LauncherService internal module).
- ChargeService removed (absorbed by LauncherService internal module).
- SkillService removed:
  - Attribute upgrade ownership → PlayerStateService/GrowthService boundary.
  - Ability toggle ownership → LauncherAbilityService.


---

## Deprecated / Pending Review

### Deprecated
- Fixed TeamRed/TeamBlue auto-balance as primary team model.
- EXP mutation from non-Growth services.
- Friendly-fire checks outside DamagePipelineService.

### Pending Review
- Runtime still contains legacy `SkillService.lua` and wiring in `Main.server.lua`; remove after remote-owner reassignment.
- SafeZoneService/LauncherAbilityService are not yet implemented as runtime modules.
- Ghost/Spectating state machine is not yet enforced in runtime constants/services.

## Equipment Ability Migration Re-ratification (2026-08-14)

Equipment abilities are now owned by `EquipmentAbilityService`. Launchers remain responsible for core launcher stats and movement compatibility only; Equipment owns active combat effects, passive abilities, and visual equipment model attachment state through `PlayerStateService`, `EquipmentService`, and `PlayerService`.
