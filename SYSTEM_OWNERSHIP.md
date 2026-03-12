# System Ownership Matrix

## PlayerStateService
- Responsibility: canonical player progression/combat state.
- Owns: Level, EXP, HP, size, attributes, buffs, diamonds, alive/charge/movement flags.
- Controls: stat recomputation, level-up progression, publish state.
- Called by: GrowthService, DamagePipelineService, SkillService, RoundService, MonetizationService, LeaderboardService.
- Depends on: BalanceConfig, LevelConfig, SlingshotConfig.

## PlayerService
- Responsibility: pawn spawning, pawn lookup, spawn teleport.
- Owns: player->pawn mapping, character reset handling.
- Controls: physical pawn lifecycle.
- Called by: RoundService, MapService, DamagePipelineService.
- Depends on: MapService, PlayerStateService.

## SlingService
- Responsibility: movement input + charge/release sling mechanics.
- Owns: per-player movement input, charge state, release cooldown.
- Controls: MoveRequest/StartCharge/ReleaseCharge handling and velocity application.
- Called by: client via remotes only.
- Depends on: RoundService, PlayerService, PlayerStateService.

## MapService
- Responsibility: map loading/lifecycle, active map metadata, map object references, spawn points, teleport rules.
- Owns: active map name, cached gate/trap/zone/spawn references.
- Controls: ActivateMap/Generate and teleport validation.
- Called by: RoundService, CollisionService, PlayerService.
- Depends on: FoodService, TrapService, RoundService.

## FoodService
- Responsibility: map food spawn lifecycle and food-consume handling.
- Owns: spawned food instances, respawn timers, food center state.
- Controls: per-map food generation and refill to design counts.
- Called by: MapService.
- Depends on: PlayerService, PlayerStateService, EventBus.

## TrapService
- Responsibility: trap spawn lifecycle + trap collision outcomes.
- Owns: trap trigger cooldown cache.
- Controls: map trap generation and trap hit effects.
- Called by: MapService (spawn), CollisionService (collision events).
- Depends on: DamagePipelineService, PlayerService.

## CollisionService
- Responsibility: heartbeat collision detection and physical collision resolution.
- Owns: collision debounce caches.
- Controls: player-player, wall, gate, trap, exit-zone collision event emission.
- Called by: runtime heartbeat.
- Depends on: MapService, CombatService, PlayerService, PlayerStateService.

## CombatService
- Responsibility: pure combat formulas.
- Owns: none (stateless).
- Controls: impact damage and knockback calculations.
- Called by: CollisionService, DamagePipelineService.
- Depends on: configs only.

## DamagePipelineService
- Responsibility: authoritative damage application pipeline.
- Owns: regen timers and last attacker tracking integration.
- Controls: hitpoint mutation, death flow, feedback remotes.
- Called by: CollisionService, TrapService, EventBus.
- Depends on: PlayerStateService, PlayerService, MapService.

## GrowthService
- Responsibility: growth hooks from gameplay outcomes.
- Owns: none (event-driven).
- Controls: EXP grants from food, kills, combat milestones.
- Called by: EventBus events.
- Depends on: PlayerStateService.

## RoundService
- Responsibility: round state machine and participation flow.
- Owns: round state, participants, round id.
- Controls: join/leave, round transitions, match UI broadcasts.
- Called by: client remotes and lobby gate events.
- Depends on: MapService, PlayerService, PlayerStateService.

## SkillService
- Responsibility: attribute spending and special upgrade toggles.
- Owns: special-upgrade active state.
- Controls: server-side skill upgrades and passive healing tick.
- Called by: client remotes.
- Depends on: PlayerStateService.

## MonetizationService
- Responsibility: paid/free respawn and match buff purchases.
- Owns: transaction decision logic.
- Controls: respawn/buff/prestige remote handlers.
- Called by: client remotes.
- Depends on: PlayerStateService, PlayerService, RoundService.

## LeaderboardService
- Responsibility: live per-map leaderboard for level/rank.
- Owns: cached rank table and `leaderstats` projection.
- Controls: rank recomputation on join/leave/level-up.
- Called by: EventBus (`LevelUp`) and player join/leave events.
- Depends on: PlayerStateService.
