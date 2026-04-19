# 🔥 SLING ARENA – CODEX BUILD SPEC (ALIGNED WITH DESIGN)

# 0. BUILD GOAL

Build a server-authoritative physics PvP arena system:

Core Gameplay:
- Charge → Launch → Collision → Knockback → Damage
- Farm Food → Gain EXP → Level up → Increase Size
- Survive until last player alive

Key Principles:
- Physics-first combat (force, velocity, inertia)
- Skill-based > stat-based
- Server authoritative
- Modular service architecture
- All balance in Config


# 1. SYSTEM ARCHITECTURE

ServerScriptService/
  Services/
    PlayerStateService
    RoundService
    SlingshotService
    CollisionService
    CombatService
    FoodService
    LevelService
    SlingService (Archetype/Passive)
    MapService
    SafeZoneService
    TeamService

ReplicatedStorage/
  Shared/
    Config/
      BalanceConfig.lua
      SlingConfig.lua
      LevelConfig.lua
      FoodConfig.lua
      MapConfig.lua

    Types/
      PlayerState.lua
      CombatTypes.lua


# 2. DATA CONTRACTS

PlayerState = {

    UserId: number,

    -- Progression
    Level: number,
    Exp: number,
    Size: number,

    -- Core Stats
    MaxHP: number,
    CurrentHP: number,

    BaseDamage: number,
    MoveSpeed: number,
    LaunchRange: number,
    ReflectDamage: number,

    -- Physics
    CurrentVelocity: Vector3,
    Mass: number,

    -- Sling
    SlingType: string,
    ChargeStartTime: number,

    -- Combat
    LastDamageTime: number,

    -- Round State
    IsAlive: boolean,
    IsGhost: boolean,

    -- Team
    TeamId: number?,

    -- Flags
    IsCharging: boolean
}


# 4. CHARGE & LAUNCH PIPELINE

OnStartCharge(player):
    PlayerState.IsCharging = true
    PlayerState.ChargeStartTime = now

OnReleaseCharge(player):

    ChargeTime = now - ChargeStartTime
    ChargeRatio = clamp(ChargeTime / MaxChargeTime)

    LaunchForce =
        BaseForce
        × ChargeRatio
        × sqrt(Level scaling)
        × MassFactor

    ApplyImpulse(Character, LaunchForce)

    PlayerState.IsCharging = false


# 5. COLLISION & COMBAT

Server-only resolution

CollisionService.Resolve(attacker, defender):

1 Validate both alive
2 Ignore Ghost
3 Calculate velocity at impact
4 Compute damage
5 Apply damage
6 Apply knockback


## DAMAGE FORMULA (FROM DESIGN)

ImpactDamage =
BaseDamage × CollisionSpeedMultiplier

Apply:
- Level scaling
- Clamp max damage


## KNOCKBACK

Knockback =
BaseForce × (AttackerMass / DefenderMass)

Apply impulse to defender


# 6. LEVEL & GROWTH SYSTEM

OnFoodConsumed(player):

    Add EXP
    Check Level Up


Level Up:

- Increase Size:
  Size = BaseSize × (1 + sqrt(Level) × 0.08)

- Increase stats:
  +3% all stats


EXP Formula:
RequiredEXP = BaseEXP × (Level ^ 1.3)



# 10. TEAM SYSTEM

- Max 2 players
- Friendly fire OFF

Final Phase:
- Auto disband team

Win condition:
- Still last man standing


# 12. ANTI-EXPLOIT

Server enforces:

- All physics applied server-side
- Client cannot set velocity
- Client cannot modify PlayerState
- Validate all remote calls

Clamp:
- Force
- Speed
- Damage


# 13. BUILD ORDER

1 PlayerStateService
2 RoundService
3 SlingshotService
4 CollisionService
5 CombatService
6 FoodService
7 LevelService
8 SlingService
9 SafeZoneService
10 MapService
11 TeamService


# FINAL NOTE

- No hard-coded values
- All balance in Config
- Services communicate via events
- No cross-service direct mutation