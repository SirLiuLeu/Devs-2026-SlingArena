# AI_CONTEXT.md

## Purpose
This document captures the **current observed implementation context** for Sling Arena so AI-assisted changes can be grounded in existing architecture.

Legend used in this file:
- **KNOWN**: explicitly confirmed in code/rules.
- **INFERRED**: deduced from patterns in code/docs.
- **UNKNOWN**: not clearly defined yet.
- **ASSUMED**: working assumption used by current code but not guaranteed by rules.

---

## 1) Game Overview
- **KNOWN**: The design target is a server-authoritative physics PvP arena with charge-and-launch combat, collisions, growth, and monetization systems. (Rule_DESIGN.md, Rule_BUILD_SPEC.md)
- **KNOWN**: Runtime implementation is service-based under `ServerScriptService/Services` and initialized from `Main.server.lua`.
- **INFERRED**: The shipped implementation currently mixes arena round flow + lobby flow + teleport flow + food/trap progression.

---

## 2) Core Gameplay Loop (Current)
- **KNOWN**: `RoundService` drives a loop: `Lobby -> PreRound -> Countdown -> ActiveRound -> RoundEnd -> PostRound -> Lobby`.
- **KNOWN**: Players join arena via `JoinArena` remote or `LobbyGateTouched` event.
- **KNOWN**: During active rounds, player-vs-player collisions produce damage and knockback via `CollisionService -> DamagePipelineService`.
- **KNOWN**: Food is consumed via touch and gives EXP + HP heal.
- **KNOWN**: Death triggers delayed respawn, with killer tracking and kill events.
- **INFERRED**: Map cycling across multiple arena maps is minimal; current default arena appears to be chosen from map names containing `Arena`.

---

## 3) Main Entities

### Player / Sling Pawn
- **KNOWN**: Runtime pawn models are cloned into `Workspace/SlingPawns` by `PlayerService`.
- **KNOWN**: Server owns velocity and network ownership (`SetNetworkOwner(nil)`).
- **KNOWN**: Player state includes level, EXP, size, HP, damage multipliers, movement/charging flags, diamonds, and per-attribute points.

### Food
- **KNOWN**: Food spawn centers are read from `Workspace/Maps/<Arena>/FoodSpawns` parts named `FoodSpawn`.
- **KNOWN**: Per center target is 5 active foods, radius ±5 studs, and per-food respawn delay 10s.
- **KNOWN**: Zone pools Center/Middle/Edge map to Food1..Food7 subsets.

### Trap
- **KNOWN**: Trap instances are cloned into map `TrapContainer` from template locations (preferred `ServerStorage/TrapTemplates`).
- **INFERRED**: Trap damage/penalty is event-driven (`TrapCollisionCandidate`, `TrapCollision`) and can apply EXP penalty.

### Gate / Corridor / Zone
- **KNOWN**: MapService tracks gates, exit zones, anti-giant zones, safe spawn zones, and size-restricted corridors.
- **KNOWN**: Corridor access checks compare player size to `BalanceConfig.CorridorSizeLimit`.

---

## 4) Server Services (Observed)
- **PlayerStateService**: canonical state storage, stat recalculation, EXP/leveling, buffs, diamonds, prestige, publish state.
- **PlayerService**: spawn/despawn pawn models, root lookup, teleport to spawn.
- **SlingshotService** (wrapper) -> **SlingService**: movement input, charge/release launch, movement state transitions.
- **CollisionService**: heartbeat collision detection (player-player, gate, trap, exit zones), emits events.
- **CombatService**: impact damage and knockback formulas.
- **DamagePipelineService**: applies damage, self-damage conditions, reflect, death handling, periodic regen.
- **GrowthService**: applies EXP rewards from food/combat/kill hooks.
- **TrapService**: trap collision outcomes (EXP penalties, etc.).
- **MapService**: map activation, spawn point lookup, food/trap spawning, teleport rules.
- **RoundService**: participant queue, round FSM, win conditions, UI-state publishing.
- **SkillService**: passive heal tick + special upgrade toggling.
- **MonetizationService**: paid/free respawn, match buff purchase, prestige reset.
- **EventBus**: intra-server service event transport.

---

## 5) Client Controllers / Scripts
- **KNOWN**: `SlingMovement.client.lua` sends movement + charge/remotes and updates charge UI/feedback labels.
- **KNOWN**: `UIBinder.client.lua` boots `LobbyClientService` + shared `UIController` (lobby/match/stats UI flow).
- **KNOWN**: `ClientController.client.lua` and `StarterGui/SlingArenaUI/MainUI.client.lua` are marked deprecated/inert.
- **INFERRED**: There are two UI approaches in repo (legacy StarterGui component tree + current shared controller), causing onboarding ambiguity.

---

## 6) Remote Events (Current Contract Surface)
Defined in `RemoteContracts.Names` and auto-created in `Main.server.lua` if missing.

### Gameplay control
- MoveRequest, StartCharge, ReleaseCharge

### State/UI
- StateUpdate, UIStateUpdate, MatchStateUpdate, RoundResult, GameplayFeedback, PopupMessage

### Progression / skill / economy
- AttributeUpgrade, ActivateSkill, RequestRespawn, RequestMatchBuff, PurchaseRespawn, PurchaseMatchBuff, PrestigeReset, ToggleSpecialUpgrade

### Arena / map / debug
- JoinArena, LeaveArena, TeleportRequest, DebugSpawnFood, DebugResetSling

**UNKNOWN**: stable payload schemas/versioning for each remote beyond basic validator checks.

---

## 7) Entity Lifecycle (Current)

### Player lifecycle
1. Player joins -> default state initialized.
2. Pawn spawned from `ReplicatedStorage/Assets/SlingModel`.
3. JoinArena places player in arena map spawn and marks state `InArena`.
4. During collisions, damage pipeline mutates HP and may set dead.
5. On death, delayed respawn occurs; monetization paths can alter retention.

### Food lifecycle
1. On map activation for arena maps, `FoodContainer` gets foods spawned from centers.
2. Food touch by owning pawn fires food consumed flow.
3. Food is destroyed; center active count decremented.
4. Respawn timer replenishes only missing count for same center.

### Trap lifecycle
1. Trap templates cloned into `TrapContainer`.
2. Collision emits trap candidate event.
3. Trap service validates/debounces and emits penalty events.

---

## 8) Map System (Current)
- **KNOWN**: map root expected at `Workspace/Maps`.
- **KNOWN**: lobby map name is `LobbyMap` (or `Lobby` in helper checks).
- **KNOWN**: arena maps are inferred by map names containing `Arena`.
- **KNOWN**: `ActivateMap(mapName)` toggles active map and repopulates map caches.
- **UNKNOWN**: authoritative map authoring convention for multi-map production (naming, metadata, duration overrides).

---

## 9) Game State Flow (Current FSM)
- Boot -> Lobby (idle, join allowed)
- PreRound (initialization)
- Countdown
- ActiveRound (combat + timer)
- RoundEnd (winner/no winner/timeout winner)
- PostRound (reset/return lobby)

**ASSUMED**: single global round state for all players in the server.

---

## 10) Known Architectural Mismatches to Rules (for future cleanup)
- **Rule conflict**: `Rule_Codex` forbids creating UI/instances in code, but `Main.server.lua` auto-creates remotes with `Instance.new`.
- **Naming drift**: build spec requires `LaunchRecoverTime = 3s`; code uses `RECOVER_TIME` fallback and movement-state cooldown logic.
- **Service drift**: build spec lists a smaller required service set, but code contains additional services (`RoundService`, `DamagePipelineService`, `PlayerService`, `TrapService`, etc.).
- **Movement ambiguity**: repo still includes deprecated `MovementService` and `ChargeService` while active logic is in `SlingService`.

