🔥 SLING ARENA – MASTER GAME DESIGN SPEC

1. CORE COMBAT SYSTEM

Damage Formula
ImpactDamage =
    VelocityMagnitude
    × log(Size + 1)
    × SlingshotModifier
    × DamageMultiplier

Rules:
- Damage per hit must be clamped.
- No slingshot may increase base damage more than 15%.


Self Damage Rule
Self damage only applies when:

ChargeRatio == 1
AND SpecialUpgradeActive == true

Logic:
if ImpactDamage > 1.5 * SelfHP then
    ImpactDamage = 1.5 * SelfHP
end

SelfDamage = ImpactDamage * 0.5
Size Dominance Rule
Large players have natural advantage but must not become unstoppable.

If AttackerSize > DefenderSize:
    DamageMultiplier += SizeAdvantageFactor

Counterplay for small players:
If DefenderSize < AttackerSize:
    DefenderKnockbackMultiplier = 1.5
    DefenderBounceDistance = High

Meaning:
Small players can:
- deal chip damage
- escape safely
- perform hit-and-run attacks

Purpose: Prevent large players from endlessly farming smaller players.


2. PHYSICS SYSTEM

Knockback Formula
SizeRatio = AttackerSize / DefenderSize

KnockbackForce = BaseImpactForce × SizeRatio

Special rule:
    If SizeRatio < 1
    Reverse knockback direction to attacker

Meaning:
    Small player hitting large player gets pushed away.
    All knockback must be clamped to a maximum limit.
    Force Decay

After each collision: RemainingVelocity *= 0.6
Stop motion if: Velocity < Threshold
Purpose: Prevent infinite bouncing.

HitCooldown = 0.2s per target
LaunchRecoverTime = 3s (Cộng dồng 2 lần Launch)

3. PLAYER GROWTH SYSTEM

EXP Sources

Players gain EXP from:
- Consuming food
- Damaging players
- Killing players
- Destroying objects


Level Formula

RequiredEXP =
    BaseEXP × (Level ^ 1.3)


Size Growth Formula

Size =
    BaseSize × (1 + sqrt(Level) × 0.08)

After Level 30:
    SizeGrowthReducedBy = 70%

Purpose:
Prevent late-game giants from dominating.
Attribute System
Each level grants:
    AttributePoints += 1

Attributes:
- MaxHP
- MoveSpeed
- LaunchForce
- ChargeSpeed
- RegenRate
- ReflectDamage
- LaunchRange
- DamageMultiplier

Rule: Every attribute must have a maximum cap.
Purpose: Prevent infinite stat scaling.


4. SKILLS & ITEMS SYSTEM

Passive Heal System
Players regenerate HP by staying still.
Activation condition:
    PlayerVelocity < MovementThreshold
    AND PlayerNotCharging
    AND PlayerNotAttacking
    for 1 second

Then: StartPassiveHeal()

Healing formula:
    HealPerSecond = MaxHP × PassiveHealPercent

Cancel conditions:
- Player moves
- Player charges sling
- Player receives damage

Purpose: Create tactical retreat opportunities.


HP Potion System
HP Potions are emergency combat consumables.

Sources:
- Daily Login Reward
- Treasure Chest
- Diamond Shop

Usage: 
    Heal = 100 HP / second
    Duration = 5 seconds
    TotalHeal = 500 HP

Cooldown: PotionCooldown = 5 seconds

Cancel condition:
    If player receives damage
    PotionEffect stops

Limit: MaxPotionsPerMatch = configurable
Purpose: Prevent potion spam while allowing clutch healing.


5. SLINGSHOT SYSTEM

All slingshots must be defined inside: SlingshotConfig
Each slingshot defines base stats and passive abilities that determine its playstyle.

BASE STAT SYSTEM
Each slingshot must define the following base attributes:
    HP
    BaseDamage
    RegenRate
    ReflectDamage
    LaunchSpeed
    LaunchRange
    ChargeSpeed
    MoveSpeed

Example:
FireSling = {

    HP = 150,
    BaseDamage = 20,
    RegenRate = 2,
    ReflectDamage = 0.05,

    LaunchSpeed = 50,
    LaunchRange = 35,
    ChargeSpeed = 1.0,
    MoveSpeed = 16,

    Passive = "BurnTrail"
}
These base stats define the default combat behavior of the slingshot.

PLAYER ATTRIBUTE SCALING
Players gain Attribute Points when leveling up.
Attributes increase slingshot stats using percentage scaling.

Formula:
FinalStat =
BaseStat × (1 + AttributeBonus)

Example:
BaseHP = 150
AttributeHPBonus = 0.30
FinalHP = 150 × 1.30

Rules:
- Attribute bonuses must have maximum caps
- Attributes must scale multiplicatively, not additively

Example caps:
MaxHPBonus = 100%
MaxDamageBonus = 80%
MaxRegenBonus = 60%
MaxLaunchSpeedBonus = 50%

Purpose: Prevent infinite stat scaling.

SLINGSHOT PASSIVE ABILITY
Each slingshot may define one passive ability.
Passive abilities should change gameplay style, not significantly increase raw power.

Example: FireSling
Passive = BurnTrail

Effect:
Creates fire trail after launch
Applies damage over time to enemies

Example: StealthSling
Passive:
PlayerInvisible = true
Duration = 1 second
After launch


SLINGSHOT BALANCE RULES
All slingshots must follow these balance constraints:
Damage bonus from slingshot ≤ 15%

Passive abilities must:
- modify gameplay
- provide situational advantages
- avoid large stat boosts

Effect stacking rules:

Multiple effects must be limited
Effect duration must be capped

Purpose: Ensure slingshots change playstyle, not raw combat power.
EXAMPLE SLINGSHOT ARCHETYPES

TankSling
High HP
High reflect damage
Slow launch speed

SpeedSling
Low HP
High launch speed
High mobility

BounceSling
Launch attacks bounce between players

GhostSling
Temporary invisibility after launch

FastFarmSling
Bonus EXP from food

DESIGN GOAL

Slingshots should create distinct playstyles while maintaining fair PvP balance.
Core principle: Playstyle diversity > Raw stat advantage

6. MAP SYSTEM

MapService must manage:
- Safe Spawn Zones
- Anti-Giant Zones
- Size Restricted Corridors

Corridor rule:
    If Size > CorridorLimit
    PlayerCannotEnter

Purpose: Prevent giant players from dominating the entire map.

7. ARENA GAMEPLAY LOOP

Core player actions:
    - Move freely
    - Charge sling
    - Launch to attack or escape
    - Collect food
    - Level up, grow size
    - Fight players
    - Earn rewards

Gameplay loop:

Spawn
→ Explore Map
→ Eat Food
→ Gain Level
→ Grow Size
→ Fight Players
→ Earn Rewards
→ Prestige Reset


8. PRESTIGE SYSTEM

Players may reset their progress.
Level → 0
Reward: Diamonds

Purpose:
- Long term progression
- Repeatable diamond farming
- Reset match power curve


9. DIAMOND ECONOMY

Diamonds may be purchased with Robux.
Design goal: Avoid hard Pay-to-Win.

Diamond Sources:

- KillPlayer
- TreasureChest
- MapEvents

Restrictions:

DiamondDropFromFood = false
DiamondPerMatchCap = configurable

Purpose: Prevent infinite diamond farming.

Respawn System
Respawn costs: [10, 15, 20] diamonds

Limit: MaxRespawnPerMatch = 3

Respawn retains:
70% Size
70% Level

Match Buffs
Cost: 20 diamonds
Possible buffs:
- EXP boost ≤ 10%
- HP boost ≤ 10%
- Damage boost ≤ 10%
- Charge speed ≤ 10%


No Respawn Option
If player does NOT respawn:
Player may restart for free but retains:
    30% Level
    30% Size


Cosmetics

- Slingshot trails
- Kill effects
- Size aura effects

Cosmetics must NOT affect gameplay stats.


10. VIP STATUS

VIP provides a soft progression bonus.
Effect: EXPFromFood × 1.10

VIP must NOT increase:
- Damage
- HP
- Combat stats

Sources:
- Daily Login
- Temporary Events
- Shop

Purpose:
Allow monetization without Pay-to-Win.

11. MATCHMAKING

Players should be matched with similar progression players.
Purpose:Prevent veteran players from farming new players.

12. COMBAT DESIGN PRINCIPLES

All gameplay systems must follow:

Skill > Size
Strategy > Stats
Positioning > Raw Damage

Hard limits:
- Stat scaling must be capped
- Economy must be controlled
- Infinite farming loops must not exist