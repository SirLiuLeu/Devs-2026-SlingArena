🔥 SLING ARENA – CODEX BUILD SPEC

0. BUILD GOAL

Build a physics PvP arena system where:

Player charge → launch
Collision → damage + knockback
Players grow by consuming entities
Self-damage risk system
Diamond monetization

System requirements:

Server authoritative
Anti-exploit
Modular service-based architecture
All balance values stored in Config


1. SYSTEM ARCHITECTURE (Roblox Service Pattern)

Required Services

ServerScriptService/
  Services/
    PlayerStateService
    SlingshotService
    CombatService
    CollisionService
    GrowthService
    SkillService
    MonetizationService
    MapService


Shared Modules

ReplicatedStorage/
  Shared/
    Config/
      BalanceConfig.lua
      SlingshotConfig.lua
      LevelConfig.lua

    Types/
      PlayerState.lua
      CombatTypes.lua


2. DATA CONTRACTS

Codex must strictly follow these schemas.

PlayerState Schema

PlayerState = {

    UserId: number,

    -- Progression
    Level: number,
    Exp: number,
    Size: number,

    -- Core Stats
    MaxHP: number,
    CurrentHP: number,

    -- Base Slingshot Stats (from SlingshotConfig)
    BaseDamage: number,
    RegenRate: number,
    ReflectDamage: number,
    LaunchSpeed: number,
    LaunchRange: number,
    ChargeSpeed: number,
    MoveSpeed: number,

    -- Attribute Scaling
    DamageMultiplier: number,
    HPBonus: number,
    LaunchSpeedBonus: number,
    RegenBonus: number,

    -- Physics
    CurrentVelocity: Vector3,

    -- Slingshot
    SlingshotType: string,
    ChargeValue: number,

    -- Combat State
    InvulnerableUntil: number,
    LastDamageTime: number,

    -- Monetization
    Diamonds: number,
    RespawnCountThisMatch: number,

    -- Flags
    IsAlive: boolean,
    IsCharging: boolean
}


3. CORE SYSTEM PIPELINES


A. CHARGE & LAUNCH PIPELINE

Client actions:

Send StartCharge
Send ReleaseCharge


Server pipeline:

OnStartCharge(player):

    PlayerState.IsCharging = true
    Record ChargeStartTime


OnReleaseCharge(player):

    ChargeTime = clamp(now - ChargeStartTime)
    ChargeRatio = ChargeTime / MaxChargeTime

    LaunchForce =
        BaseLaunchForce
        × ChargeRatio
        × SizeModifier
        × PlayerState.LaunchSpeed

    ApplyImpulse(player.Character, LaunchForce)

    PlayerState.IsCharging = false


Purpose:

Convert player charge input into physical launch velocity.



B. COLLISION RESOLUTION PIPELINE

Server only.

When character touches another entity:

CollisionService.ResolveCollision(attacker, defender)


Pipeline order:

1 Validate attacker alive
2 Validate defender alive
3 Check invulnerability state
4 Compute ImpactDamage
5 Apply self-damage if conditions met
6 Apply defender damage
7 Apply knockback force
8 Apply force decay


Purpose:

Ensure consistent server-authoritative combat resolution.



C. DAMAGE CALCULATION

Damage formula must follow Game Design Spec:

ImpactDamage =
VelocityMagnitude
× log(Size + 1)
× SlingshotModifier
× DamageMultiplier

Rules:

Clamp damage to prevent one-hit kills.
Apply attribute scaling after base calculation.



D. KNOCKBACK RESOLUTION

SizeRatio = AttackerSize / DefenderSize

KnockbackForce =
BaseImpactForce × SizeRatio

Clamp knockback to maximum safe value.

If SizeRatio < 1:
Small attacker receives partial rebound force.



E. FORCE DECAY

After each collision:

RemainingVelocity *= ForceDecayFactor

Stop motion if:

VelocityMagnitude < VelocityStopThreshold



4. SKILL SYSTEM PIPELINE

PassiveHealSystem

Activation:

If PlayerVelocity < MovementThreshold
AND now - LastDamageTime > HealDelay
AND PlayerNotCharging

StartPassiveHeal()


Healing formula:

HealPerSecond =
MaxHP × PassiveHealPercent


Cancel healing if:

Player moves
Player charges sling
Player receives damage



5. ANTI-EXPLOIT RULES

Server must enforce:

All damage calculations server-side
Client never sets velocity directly
Client cannot modify PlayerState
All diamond transactions server-only
Clamp all physics and stat values

Reject invalid remote requests.



6. BUILD PRIORITY ORDER FOR CODEX

Build services in this order:

1 PlayerStateService
2 SlingshotService
3 CollisionService
4 CombatService
5 GrowthService
6 SkillService
7 MonetizationService
8 MapService



FINAL NOTE FOR CODEX

System requirements:

Services must remain modular.
No hard-coded balance values.
All balancing stored in Config modules.

Services communicate via events
instead of directly mutating other services.