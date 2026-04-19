# 🔥 SYSTEM OWNERSHIP MATRIX (ALIGNED WITH DESIGN)

# PlayerStateService
- Responsibility: canonical player state (progression + combat + round state)
- Owns: Level, EXP, Size, MaxHP, CurrentHP, BaseDamage, MoveSpeed, LaunchRange, ReflectDamage, Mass, CurrentVelocity, SlingType, IsAlive, IsGhost, IsCharging, TeamId
- Controls: Level up, Stat scaling (+3% per level), Size scaling (sqrt formula), State mutation (HP, EXP)
- Called by: LevelService, CollisionService, SlingService, RoundService, TeamService
- Depends on: BalanceConfig, LevelConfig, SlingConfig

# PlayerService
- Responsibility: player pawn lifecycle
- Owns: Player ↔ Character mapping
- Controls: Spawn / Respawn, Teleport to map, Ghost transform (visual + collision off)
- Called by: RoundService, MapService
- Depends on: PlayerStateService

# RoundService
- Responsibility: match lifecycle & phase control
- Owns: CurrentPhase (Lobby / Early / Final / End), RoundTimer, ActivePlayers
- Controls: Phase transitions, Respawn rules, Ghost rules, Join rules (late join → ghost), Winner detection, Round reset
- Called by: Player join/leave events
- Depends on: PlayerService, PlayerStateService, MapService, TeamService

# SlingService
- Responsibility: charge & launch mechanics
- Owns: ChargeStartTime per player
- Controls: StartCharge / ReleaseCharge, Launch force calculation, ApplyImpulse
- Called by: Client (Remote)
- Depends on: PlayerStateService, RoundService

# CollisionService
- Responsibility: collision detection & resolution
- Owns: Collision debounce cache
- Controls: Player vs Player collision, Player vs Trap, Player vs Environment
- Called by: Heartbeat
- Depends on: PlayerService, PlayerStateService, CombatService, MapService, SlingService

# CombatService
- Responsibility: combat formulas (stateless)
- Owns: None
- Controls: ImpactDamage calculation, Knockback calculation
- Called by: CollisionService
- Depends on: BalanceConfig

# LevelService
- Responsibility: EXP & leveling system
- Owns: None (event-driven)
- Controls: Add EXP, Check LevelUp, Trigger stat scaling
- Called by: FoodService, CollisionService (on kill)
- Depends on: PlayerStateService, LevelConfig

# FoodService
- Responsibility: food spawn & consumption
- Owns: Active food instances, Spawn timers
- Controls: Spawn Food theo FoodSpawns, Maintain 5 Food / spawn, Respawn after 10s, Zone-based food distribution
- Called by: MapService
- Depends on: PlayerStateService, LevelService

# MapService
- Responsibility: map data & environment setup
- Owns: Active map, Spawn points, FoodSpawns, Trap locations
- Controls: Load map, Provide spawn positions
- Called by: RoundService
- Depends on: FoodService

# SafeZoneService
- Responsibility: shrinking zone & damage
- Owns: Current zone radius, Shrink timer
- Controls: Shrink over time, Detect players outside zone, Apply %HP damage scaling
- Called by: Heartbeat
- Depends on: PlayerStateService, RoundService

# SlingService (Archetype / Passive)
- Responsibility: Sling passive abilities
- Owns: Passive state (stack, cooldown nếu có)
- Controls: Trigger passive: - On launch - On collision - Passive loop
- Examples: Stun, Clone, Vacuum, Speed stack
- Called by: SlingService, CollisionService
- Depends on: PlayerStateService

# TeamService
- Responsibility: team logic
- Owns: Team mapping
- Controls: Create team (max 2 players), Disable friendly fire, Disband team in Final Phase
- Called by: RoundService
- Depends on: PlayerStateService

# TrapService
- Responsibility: trap behavior
- Owns: Trap cooldown states
- Controls: Lava (kill after 3s), Toxic (DOT), Spike (damage + knockback), Totem (projectile force)
- Called by: CollisionService
- Depends on: PlayerStateService, CombatService

# FINAL NOTES
- No DamagePipelineService → gộp trực tiếp vào CollisionService + PlayerStateService
- No MonetizationService → không thuộc core gameplay
- No global regen system → không có trong design
- Services giao tiếp qua event / call rõ ràng
- PlayerStateService là nguồn dữ liệu duy nhất (single source of truth)