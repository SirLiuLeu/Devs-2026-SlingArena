# Sling Arena — Sequential Refactor Roadmap (Safe Execution)

## Scope and source boundaries
- This roadmap is derived only from:
  - `AI_CONTEXT.md`
  - `Rule_DESIGN.md`
  - `PROJECT_TREE.md`
  - `Rule_Codex.md`
  - `SYSTEM_OWNERSHIP.md`
- Goal: sequential refactor from low dependency → high dependency, no big-bang rewrite.

---

## GROUP 1 — CONTRACTS, CANONICAL STATE, AND OWNERSHIP BOUNDARIES

### ✅ Purpose
- Freeze a single source of truth for runtime data, remote contracts, and service ownership before touching behavior.
- Eliminate hidden dependencies and contradictory definitions.

### ❌ What is wrong currently
- Remote contract mismatch:
  - `AI_CONTEXT.md` client→server list is compact.
  - `PROJECT_TREE.md` includes additional remotes (`AttributeUpgrade`, `RequestRespawn`, `PurchaseRespawn`, `PurchaseMatchBuff`, `PrestigeReset`, `ToggleSpecialUpgrade`) that are outside current core-loop ownership.
- Service inventory mismatch:
  - `AI_CONTEXT.md` lists `SlingMovement` service module.
  - `PROJECT_TREE.md` lists `MovementService` as inferred deprecated and `ChargeService` as deprecated.
- Team rule ambiguity:
  - Design says temporary teams max 2 then forced betrayal in last 2 minutes.
  - Ownership says TeamService is minimal friendly-check only, no full assignment model.
- Round/final-phase interpretation mismatch (join as ghost yet “still farm + level” in design) risks non-deterministic behavior if not concretely formalized.

### 🔧 What to CHANGE (modify)
- Define one canonical runtime contract doc for:
  - active remotes,
  - decommissioned remotes,
  - compatibility/deprecation window,
  - payload schemas.
- Define one canonical player state schema (Lobby/Arena/Ghost/Dead/Spectating, combat flags, farm flags, visibility flags).
- Convert ownership doc into enforceable module boundaries:
  - each service explicitly declares allowed dependencies.

### ➕ What to ADD
- `Contract Matrix` (RemoteName → Direction → OwnerService → PayloadSchema → Status: Active/Deprecated/Removed).
- `State Machine Spec` (player lifecycle + round lifecycle with legal transitions).
- `Dependency Rule Sheet` (who can call whom; forbidden cross-layer accesses).

### 🗑 What to REMOVE
- Any undocumented or orphan remotes from active runtime routing.
- Any stale references to deprecated movement/charge services once adapter path is confirmed.
- Ambiguous duplicated ownership statements across docs.

### 🔗 Dependencies
- None (must be first group).

### ▶️ Step-by-step execution order
1. Inventory all live remotes from runtime bootstrap and compare against both `AI_CONTEXT.md` and `PROJECT_TREE.md`.
2. Mark each remote as Active / Deprecated / Remove-candidate.
3. Lock canonical player state fields and legal transitions.
4. Publish dependency matrix per service (allowed inbound/outbound calls).
5. Freeze these artifacts; no behavioral refactor starts before sign-off.

---

## GROUP 2 — CORE ENTITY LIFECYCLE: PLAYER PAWN, SPAWN, AND ROUND PARTICIPATION

### ✅ Purpose
- Stabilize the most foundational runtime lifecycle (player representation and round membership) to prevent cascading bugs in movement/combat/food.

### ❌ What is wrong currently
- Spawn policy is strict (sling-only, no default character, CharacterAutoLoads off), but any legacy paths can still cause dual-lifecycle risks if not centralized.
- Join/leave/respawn/final-phase ghost behavior is distributed across docs/services and can drift.
- Potential conflict between early-game respawn rules and final-phase no-respawn/ghost conversion if transitions are not unified.

### 🔧 What to CHANGE (modify)
- Make `PlayerService + PlayerStateService + RoundService` the only path for lifecycle transitions.
- Encode explicit transition guards:
  - Lobby → ArenaAlive,
  - ArenaAlive → Respawning (early phase only),
  - ArenaAlive → Ghost (final phase),
  - Join after minute 8 → Ghost immediately.
- Standardize one spawn resolution path (map spawn points + safe-zone constraints).

### ➕ What to ADD
- Transition gate helpers (phase-aware validation utility).
- Centralized “phase policy” table consumed by RoundService and PlayerService.
- Runtime assertions/telemetry for illegal state transitions.

### 🗑 What to REMOVE
- Any direct character/pawn spawn side path outside PlayerService.
- Any phase checks duplicated in unrelated services.

### 🔗 Dependencies
- Requires GROUP 1 contract/state machine freeze.

### ▶️ Step-by-step execution order
1. Implement transition map in spec form (no behavior changes yet).
2. Route all join/leave/respawn/ghost decisions through RoundService policy gate.
3. Route all physical pawn spawn/despawn through PlayerService only.
4. Enforce PlayerStateService as single writer for player state mutations.
5. Add logging for illegal transition attempts and verify no invalid transitions during test rounds.

---

## GROUP 3 — CORE SIMULATION SERVICES: MOVEMENT, COLLISION, COMBAT, DAMAGE PIPELINE

### ✅ Purpose
- Make physics/combat deterministic and service responsibilities cleanly separated.

### ❌ What is wrong currently
- Movement lineage is ambiguous (`SlingService`, helper `SlingMovement`, deprecated `MovementService`/`ChargeService` references).
- Collision/combat/damage boundaries can blur (calculation vs side effects vs state mutation).
- Risk of duplicate authority between input handling and heartbeat application if caches/ticks are not singular.

### 🔧 What to CHANGE (modify)
- Enforce authoritative chain:
  - Input validation/cache in SlingService,
  - Movement apply only in heartbeat simulation loop,
  - Collision detection in CollisionService,
  - Pure formulas in CombatService,
  - All damage state mutations in DamagePipelineService.
- Formalize event contracts between services (collision result payloads, damage intent payloads).

### ➕ What to ADD
- Simulation tick contract doc (order of execution per frame).
- Deterministic cooldown/collision key strategy documentation.
- Integration checks for launch → movement → collision → damage sequence.

### 🗑 What to REMOVE
- Any direct HP/EXP mutation outside PlayerStateService/DamagePipelineService/GrowthService-defined flows.
- Any direct knockback/damage formula duplication outside CombatService.
- Legacy movement/charge entry points not in canonical chain.

### 🔗 Dependencies
- GROUP 1 (contracts + ownership)
- GROUP 2 (stable player lifecycle)

### ▶️ Step-by-step execution order
1. Freeze frame-order spec (input cache, simulate, detect, resolve).
2. Remove/disable legacy movement adapters from runtime path.
3. Route collision outputs to damage pipeline through one typed payload.
4. Ensure CombatService is pure and side-effect free.
5. Validate deterministic behavior with repeated fixed-seed simulation tests.

---

## GROUP 4 — PROGRESSION & WORLD SYSTEMS: FOOD, GROWTH, TRAPS, SAFE ZONE, MAP RESOURCES

### ✅ Purpose
- Refactor environmental/progression mechanics onto stable simulation backbone without leaking combat or UI responsibilities.

### ❌ What is wrong currently
- Design includes two food types (normal + HP food with last-hit reward), but ownership snapshot only guarantees consume-on-touch plus density maintenance; HP-food combat path may be incomplete or mixed.
- Safe-zone ramp damage is specified in design but ownership map does not clearly expose dedicated controller ownership.
- MapService currently coordinates multiple systems; risk of over-centralization and hidden side effects.

### 🔧 What to CHANGE (modify)
- Separate food subsystem into clear modes:
  - Touch-consume food,
  - HP-food entity with combat-driven last-hit rewards.
- Route all EXP grants through GrowthService event routing only.
- Make safe-zone damage a first-class round-phase/environment policy (not ad-hoc trap-like behavior).
- Restrict MapService to discovery/cache/spawn resolution, not gameplay logic.

### ➕ What to ADD
- Environmental event taxonomy (`FoodConsumed`, `FoodDestroyedLastHit`, `SafeZoneTick`, `TrapTriggered`).
- Explicit safe-zone controller ownership (likely RoundService policy + DamagePipeline apply).
- Spawn density and overlap invariants for food clusters.

### 🗑 What to REMOVE
- Any EXP award logic inside unrelated services bypassing GrowthService.
- Any environmental damage paths bypassing DamagePipelineService.

### 🔗 Dependencies
- GROUP 1–3 complete.

### ▶️ Step-by-step execution order
1. Define food entity model and event outputs per food type.
2. Normalize trap and safe-zone damage to same damage pipeline entry.
3. Move all EXP rewards into GrowthService subscriptions.
4. Limit MapService to map resource indexing and spawn queries.
5. Run long-round stability checks (spawn density, respawn timing, zone damage ramp).

---

## GROUP 5 — MATCH FLOW ORCHESTRATION (ROUND TIMELINE)

### ✅ Purpose
- Align actual runtime loop with design timeline: Lobby → Early (respawn) → Final (no respawn/ghost) → Winner → Result → Reset.

### ❌ What is wrong currently
- Current ownership describes phase handling but not full timeline contract with exact transition triggers and lockouts.
- Team dissolve timing (last 2 minutes) and final phase rules can conflict if not encoded as explicit schedule events.
- Winner determination and post-match windows (5s winner detect, 15s rank/reward, 15s reset) require synchronized orchestration.

### 🔧 What to CHANGE (modify)
- Promote timeline to explicit state machine with timestamps and one scheduler owner (RoundService).
- Enforce phase-specific capability gates (can launch, can interact, can be targeted, visibility rules).
- Integrate team betrayal trigger with phase timeline deterministically.

### ➕ What to ADD
- Round timeline config table (minute markers, lockouts, callbacks).
- Match capability matrix per player mode (Alive/Ghost/Spectator/Lobby).
- End-of-round snapshot contract for LeaderboardService and reward output.

### 🗑 What to REMOVE
- Hard-coded scattered time checks in unrelated services.
- Implicit winner resolution side paths outside RoundService orchestration.

### 🔗 Dependencies
- GROUP 1–4 complete.

### ▶️ Step-by-step execution order
1. Define canonical timeline milestones and callbacks.
2. Attach capability gates to each phase transition.
3. Trigger team dissolve exactly at configured late-phase marker.
4. Route winner lock, reward snapshot, and reset through one RoundService flow.
5. Validate with scripted full-match scenario tests (including late joiners).

---

## GROUP 6 — CLIENT GAMEPLAY CONTROLLERS (INPUT, STATE SYNC, LOCAL FEEDBACK)

### ✅ Purpose
- Ensure client is thin, predictable, and fully server-authoritative for gameplay decisions.

### ❌ What is wrong currently
- Multiple client scripts with ambiguous active status (`SlingMovement.client.lua`, `SlingController.client.lua`, legacy `ClientController.client.lua`) create drift risk.
- Potential duplicate remote sends or duplicated state bindings.
- UI binder/controller boundaries can accidentally absorb gameplay logic.

### 🔧 What to CHANGE (modify)
- Consolidate gameplay input ownership to one active controller path.
- Keep client responsibilities limited to:
  - input capture,
  - remote invocation,
  - rendering/presentation of server state.
- Ensure all gameplay authority remains server-side.

### ➕ What to ADD
- Client controller ownership map (which script owns input, which owns UI binding, which is legacy).
- Remote call throttling/debounce policy per input channel.
- Desync diagnostics (client predicted intent vs server authoritative state updates).

### 🗑 What to REMOVE
- Legacy inert client scripts from startup path.
- Any client-side gameplay rule evaluation (damage, phase eligibility, authoritative collision outcomes).

### 🔗 Dependencies
- GROUP 1–5 complete.

### ▶️ Step-by-step execution order
1. Mark one gameplay input script as canonical; retire others.
2. Verify one remote path per input action (move/charge/release/join/leave).
3. Bind all HUD/feedback from server push events only.
4. Add client diagnostics for duplicate send/state bind events.
5. Validate under reconnect/latency scenarios.

---

## GROUP 7 — UI LAYER PURIFICATION (VISUAL ONLY)

### ✅ Purpose
- Move UI to pure presentation and user intent dispatch; remove gameplay ownership from UI.

### ❌ What is wrong currently
- Large GUI surface (lobby + rewards + shop + daily + sling UI) increases chance of logic leakage.
- Rule_Codex constraints require runtime-safe missing-instance handling; ad-hoc UI checks can silently skip logic or break consistency.

### 🔧 What to CHANGE (modify)
- Enforce UI pattern:
  - UI reads server state (`UIStateUpdate`, `MatchStateUpdate`, `StateUpdate`, `PopupMessage`, `GameplayFeedback`),
  - UI sends intent events only,
  - no game-rule decisions in UI scripts.
- Standardize missing-instance handling with warnings and non-crashing continuity.

### ➕ What to ADD
- UI binding spec per screen: required paths, consumed payloads, emitted intents.
- Shared defensive UI accessor utility (warn + continue behavior).
- UI smoke checklist per screen for missing node resilience.

### 🗑 What to REMOVE
- Any gameplay state mutation from UI handlers.
- Any early-return patterns that kill feature flow due to missing UI nodes.

### 🔗 Dependencies
- GROUP 1 and GROUP 6 complete (contracts + clean client controller boundary).

### ▶️ Step-by-step execution order
1. Map each screen to server payload dependencies.
2. Strip gameplay logic from UI modules; keep rendering + intent wiring.
3. Apply standardized missing-instance warning pattern everywhere.
4. Run per-screen smoke tests with intentionally missing optional nodes.
5. Confirm no runtime crashes and no gameplay behavior regressions.

---

## GROUP 8 — INTEGRATION SAFETY NET, MIGRATION CONTROL, AND CLEANUP

### ✅ Purpose
- Prevent bug stacking during rollout; guarantee reversible and measurable refactor progress.

### ❌ What is wrong currently
- Without staged gates, legacy and new paths may run in parallel and produce nondeterministic results.
- Refactor can regress gameplay loop silently if acceptance checks are not attached to each group.

### 🔧 What to CHANGE (modify)
- Use group-level feature flags / migration toggles where needed.
- Attach explicit acceptance criteria and rollback criteria per group.
- Enforce “one subsystem at a time” merge policy.

### ➕ What to ADD
- Refactor scoreboard:
  - group status,
  - blocker list,
  - regression checklist,
  - rollback switch references.
- End-to-end scenario pack:
  - early respawn flow,
  - final phase ghost behavior,
  - late join as ghost,
  - winner + reward + reset,
  - team dissolve timing.

### 🗑 What to REMOVE
- Dead remotes/modules/config entries after migration completion.
- Temporary adapters and compatibility shims once no callers remain.

### 🔗 Dependencies
- GROUP 1–7 complete incrementally.

### ▶️ Step-by-step execution order
1. Define acceptance/rollback criteria for each group before implementation.
2. Execute groups sequentially; do not overlap major subsystem refactors.
3. Run scenario pack after every group completion.
4. Remove legacy code only after zero-call verification.
5. Finalize documentation snapshots (`AI_CONTEXT`, ownership, contract matrix).

---

## Explicit architecture conflicts detected (must be resolved in refactor)

1. **Remote contract drift** between compact active list and expanded tree remotes.
2. **Movement service naming drift** (`SlingMovement` helper vs deprecated `MovementService/ChargeService`).
3. **Team system direction conflict** (design includes temporary teams + forced betrayal; ownership currently minimal friendly-check only).
4. **Final-phase/ghost rules need strict capability matrix** to avoid contradictory behaviors (farm allowed, launch forbidden, visibility rules).
5. **Food system spec gap** (HP-food + last-hit path in design vs touch-consume-focused ownership summary).
6. **Safe-zone ownership gap** (design has explicit escalating zone damage; ownership mapping not yet explicit as dedicated controller path).

---

## Execution policy (non-negotiable)
- Always refactor in group order (1 → 8).
- Do not start a group until previous group acceptance checks pass.
- No UI refactor before core contracts/state/lifecycle are stabilized.
- No service may depend on UI modules.
- No gameplay authority may exist on client/UI.
