# 🔥 LAUNCHER ARENA – MASTER GAME DESIGN SPECIFICATION
# 0. DESIGN GOAL
* Genre: Survival Physics Arena (Round-based)
* Core Experience: Farm Food to level up, use physics to collide with and push opponents into traps or the shrinking zone
* Philosophy: Skill & Coordination > Raw Stats
* Core Feeling: **Launch – Impact – Bounce – Slide** must feel strong and responsive

# 1. CORE GAME LOOP
* Lobby: Select / Buy / Spin Launcher; Equip Items; Upgrade
* Start: Join Map; Farm Food; Level Up
* Mid Game: Combat; Position Control; Use Traps
* Late Game: Shrinking Zone; Forced Fights; Survival
* End: Last player alive wins; Rewards granted; Round reset

# 2. ROUND RULES
## 2.1 World & Map
* Arena size: 400 × 400 studs
* Shape: Square Arena
* Boundary: Surrounded by walls
* Maximum players: 20

### Spawn Logic
* Player: Random spawn near arena edges
* Food: Spawn in clusters using `FoodSpawn`
* Traps: Fixed positions
* Launcher: Moves with normal movement controls; Can Charge / Launch

## 2.2 Early Game
### Timing
* Main EarlyGame duration: 0 → 8 minutes
* Trigger: At least 3 players are in the map
* Once triggered: Safe Zone begins its normal shrink cycle; Full gameplay becomes active

### Gameplay
* Movement
* Charge
* Launch
* Food farming
* Combat
* Traps

### EXP
* Full EXP gain: 100%

### Death
* Respawn after **3 seconds**
* Respawn at a random position inside Safe Zone
* Lose 30% current EXP

### Joining
* New players may join during EarlyGame.

## 2.3 Final Phase
### Timing
* Target phase: 8 → 10 minutes
* Trigger: Safe Zone reaches its minimum-radius condition / Final Phase threshold

### Rules
* Respawn disabled
* New team creation disabled
* Ghost system becomes active
* Forced combat pressure increases as Safe Zone approaches its final condition

### Death
* Dead players do not respawn
* Player receives the `Ghost` flag

### Joining
* A player joining after the Final Phase has started immediately receives the `Ghost` flag.

### Team
* No new team formation
* Existing teams remain valid
* Players without a team play solo

## 2.4 Final Phase + Ghost Behavior
* `Ghost` is implemented as a **Flag**, not as a high-level `PlayerState`.

### Ghost Activation

* The `Ghost` flag is activated when:

  * Player dies during Final Phase
  * Player joins after Final Phase begins

### Movement

* Can move freely
* No player collision
* No physical interaction with normal players
* No combat physics interaction

### Combat

* Cannot Charge
* Cannot Launch
* Cannot deal damage
* Does not trigger combat collision effects

### Visibility

* Invisible to normal players
* Visible to other Ghosts

### Farming

* Can consume Normal / Common Food
* Cannot interact with HP Food

### Intro Delay

* For the first **5 seconds** after Ghost activation:

  * Cannot move
  * Fully disabled
* After the delay:

  * Movement enabled
  * Farming enabled according to Ghost rules

## 2.5 Round Lifecycle

* Round states: **Lobby → Awaits → EarlyGame → FinalPhase → RoundEnd → PostRound**

### 2.5.1 Lobby

* Players remain in Lobby map
* Can open: Shop; Inventory; Spin
* Players may join the Arena Map
* Cannot attack while remaining in Lobby

### Leaving / Rejoining

* After leaving the Arena, player has a **15-second cooldown** before rejoining

### PostRound Transition

* When the round ends:

  * All players are teleported back to Lobby
  * Reset round state
  * Reset map state
  * Reset Food
  * Reset temporary player state
  * Reset temporary flags
  * Reset round-specific data
  * Prepare the next round
* Once the next Map is ready:

  * Transition into the next round lifecycle

### 2.5.2 Awaits

* Purpose:

  * Wait for enough players to enter the Arena
  * Prepare the round before the main shrinking phase begins
* Gameplay:

  * Players can move
  * Players can Charge
  * Players can Launch
  * Players can farm Food
  * Players can attack normally
* Temporary limitations:

  * EXP gain reduced by **50%**
  * No Diamonds rewarded
  * No special rewards spawn

### Damage Rule

* During Awaits:

  * Movement: enabled
  * Charge: enabled
  * Launch: enabled
  * Food farming: enabled
  * Launch damage against Players / HP Food remains subject to normal combat validation rules

### 2.5.3 EarlyGame

* Trigger:

  * At least **3 players** are in the map
* Actions:

  * Safe Zone begins shrinking
  * Display: `"Safe zone is shrinking. EXP gain is now 100%."`
* Enabled systems:

  * Movement
  * Charge
  * Launch
  * Food farming
  * Combat
  * Traps

### 2.5.4 FinalPhase

* Trigger:

  * Safe Zone reaches Final Phase threshold / minimum-radius condition
* Actions:

  * Disable respawn
  * Disable new team creation
  * Enable Ghost behavior

### 2.5.5 RoundEnd

* Trigger:

  * Only **1 player** or **1 team** remains alive
  * Win condition is checked while round state is `EarlyGame` or `FinalPhase`
* Flow:

  * **0–5s:** Freeze all active players; Determine winner; Stop normal round progression
  * **5–15s:** Show result UI; Show rank; Grant rewards
* After result flow:

  * Transition to `PostRound`

## 2.6 End Condition

### Winner

* Last player alive
* Or last surviving team

### After Win

* Safe Zone stops dealing damage
* Round enters `RoundEnd`

### Result Flow

* **0–5s:** Determine winner / freeze gameplay
* **5–15s:** Show rank and rewards
* After result phase: reset round

# 3. FOOD SPAWN SYSTEM

## 3.1 Food Structure

* Food rarity types:

  * Common
  * Uncommon
  * Rare
  * Epic
  * Legendary
* Spawn marker:

  * `FoodSpawn`

## 3.2 Spawn Rule

* Food spawn position:

  * Random offset within approximately ±5 studs on X/Z
* Conceptual rule:

  * `spawnPos = FoodSpawn.Position + Vector3.new(random(-5,5), 0, random(-5,5))`
* Density:

  * `1 FoodSpawn = 5 Common Food active`
  * Or `1 HP Food`
* Food should not overlap with another Food inside the same cluster.

## 3.3 Food Types

### 3.3.1 Common Food

* Interaction:

  * Touch / valid overlap
* Rules:

  * Disappears on valid contact
  * Grants EXP
  * Heals HP
* Server:

  * Validates the interaction
  * Grants rewards
  * Removes Food on Server
  * Replicates resulting state
* Respawn:

  * Each destroyed Common Food respawns **exactly 1**
  * Respawn delay: **10 seconds**

### 3.3.2 HP Food

* Types:
  * Uncommon
  * Rare
  * Epic
  * Legendary
* Interaction:

  * Requires an attack / valid hit
  * Does not disappear from a simple normal movement contact
* Rules:

  * Valid attack reduces Food HP
  * Grants EXP when destroyed
  * Has a chance to grant Diamonds
* Server:

  * Validates the hit
  * Reduces HP
  * Destroys Food only when HP reaches `0`
  * Replicates state
* Respawn:

  * Each destroyed HP Food respawns **exactly 1**
  * Respawn delay: **30 seconds**

## 3.4 Spatial Grid

* Food uses XZ spatial partitioning.
* Rules:

  * Food is indexed into grid cells using `GRID_CELL_SIZE`
  * Nearby queries only inspect neighboring cells
  * Standard nearby query checks the surrounding **3 × 3 cells**
  * Do not scan the entire Food collection for ordinary collision queries

## 3.5 Zone Spawn Rates

### Mid Zones

* Common: 70%
* Uncommon: 15%
* Rare: 10%
* Epic: 5%
* Legendary: 0%

### Edge Zones

* Common: 65%
* Uncommon: 15%
* Rare: 10%
* Epic: 5%
* Legendary: 5%

### Center Zones

* Common: 0%
* Uncommon: 0%
* Rare: 0%
* Epic: 70%
* Legendary: 30%

# 4. PHYSICS & MOVEMENT

## 4.1 Movement Ownership

* Normal horizontal movement uses:

  * `LinearVelocity`
  * Attachment-based constraint
  * Server-owned movement configuration
* Server controls:

  * `PlaneVelocity`
  * Constraint `Enabled` state
  * Movement state transitions
* Client must not:

  * Create its own authoritative movement constraint
  * Manually override server movement using CFrame-based movement logic

## 4.2 Rotation Ownership

* Character rotation uses:

  * `AlignOrientation`
* Server owns the orientation path.
* Rule:

  * Only `LauncherService` may update `AlignOrientation.CFrame` on the server.
  * Other services must not independently write the authoritative orientation.

## 4.3 Physics Source of Truth

* All physical constants must come from `PhysicsConfig.lua`.
* This includes categories such as:

  * Movement
  * World
  * Charge
  * Knockback
  * Launch
  * Lag Compensation
  * Collision
  * Stability
* Do not hardcode physics constants inside service logic.

## 4.4 Core Formulas

### Impact Damage

* `ImpactDamage = BaseDamage × CollisionSpeedMultiplier`

### Launcher Size

* `Size = BaseSize × (1 + sqrt(Level) × 0.08)`

### Required EXP

* `RequiredEXP = BaseEXP × (Level ^ 1.3)`

## 4.5 State-Based Physics Rules

### State = Moving

* Goal:

  * Smooth movement
  * Avoid unnecessary physics interference
* Rules:

  * Player-to-player contact does not cause combat damage
  * Normal movement contact does not cause launch bounce
  * Food collision should not create unwanted physical resistance
  * HP Food physical resistance is ignored for normal movement logic

### Ghost Flag

* When `Ghost` is active:

  * Passes through normal players
  * No combat collision
  * No physical interaction
  * Can only consume allowed Common Food

### State = Charging

* Player prepares a Launch
* Normal movement is disabled
* Launch can be triggered by release
* Active hard CC can interrupt charging

### State = Launching

* Goal:

  * Strong impact
  * Controlled physics
  * Predictable knockback
  * Precise damage resolution
* Rules:

  * Physics movement is active
  * Velocity, knockback and reaction forces apply
  * Damage is resolved through the server collision pipeline
  * Damage against the same target is not repeatedly applied during one contact window
  * Velocity and force must remain within `PhysicsConfig.lua` limits
  * Drag gradually reduces excessive velocity

## 4.6 Physics Reconciliation

* Client simulates its predicted motion.
* Server remains authoritative.

### Minor Desync

* Smooth correction
* Lerp / interpolation

### Large Desync

* Immediately resynchronize to server state

### False Client Collision

* If client predicts a hit but the server rejects it:

  * Cancel local knockback prediction
  * Resynchronize position
  * Resynchronize velocity
  * Continue from authoritative server state

# 5. COLLISION & COMBAT VALIDATION

## 5.1 Event-Driven Collision Model

* Collision is **event-driven**, not fixed-interval Food/Player polling.
* Pipeline:

  * **Client Detects → Client Reports → Server Validates → Server Resolves → Replicate**
* Client may:

  * Detect possible collision
  * Predict local impact
  * Play immediate VFX/SFX
  * Apply local hitstop / bounce prediction
  * Send hit request
* Client does not:

  * Decide final damage
  * Decide death
  * Decide kill
  * Decide reward
  * Remove authoritative Food state
* Server:

  * Validates collision
  * Validates combat state
  * Applies damage
  * Applies knockback result
  * Handles HP / death / elimination
  * Updates authoritative state
  * Replicates result

## 5.2 Clock Sync & Lag Compensation

* Hit validation uses synchronized client/server timing.
* Infrastructure includes:

  * `ClockSyncRequest`
  * `ClockSyncResponse`
* Validation must account for:

  * Accepted client latency
  * Future timestamp tolerance
  * Server/client clock difference
* Lag compensation values are defined in:

  * `PhysicsConfig.LagCompensation`

## 5.3 Rate Limiting & Hit Deduplication

* Every client combat report is protected by validation infrastructure.

### Rate Limiting

* Use `RateLimiter` to:

  * Limit remote frequency per player
  * Prevent remote-event spam
  * Reject excessive request rates

### Hit Deduplication

* Use `HitCooldownDedupe` to:

  * Prevent duplicate hits
  * Track launch/target combinations
  * Deduplicate repeated collision events
  * Prevent multiple resolutions from the same attack window

## 5.4 Collision Validation

* All common collision validation should be centralized in:

  * `CollisionValidation`
* Do not duplicate manual distance / swept collision formulas inside individual services.
* Validation may include:

  * Distance check
  * Horizontal distance check
  * Swept collision check for high-speed movement
  * Position plausibility
  * Velocity threshold
  * Collision radius
  * Timestamp / lag compensation
  * State validation
  * Target validity

## 5.5 Hitbox Shapes

* Simplified gameplay hitboxes only.

### Player / Launcher

* Sphere

### Common Food

* Sphere

### HP Food

* Sphere preferred
* Box allowed where Food shape requires it
* Do not rely on complex mesh collision for core gameplay validation.

## 5.6 Server Validation Rules

* The server must reject a hit when:

  * Attacker does not exist
  * Attacker is dead
  * Target does not exist
  * Target is invalid
  * Food no longer exists
  * Food is inactive
  * Attacker is not in a valid combat state
  * Distance is invalid
  * Swept collision fails
  * Timestamp is invalid
  * Request exceeds rate limit
  * Hit is duplicated
  * Cooldown / dedupe rule rejects the event
  * Velocity exceeds allowed threshold
  * Ghost / invulnerability / other rules block the interaction

## 5.7 Collision Types

### A. Player vs Common Food

* Common Food:

  * `CanCollide = false`
  * `CanTouch = false`
* Client:

  * May detect overlap locally
  * May hide Food immediately for feedback
  * Sends interaction request
* Server:

  * Validates request
  * Grants EXP
  * Applies HP recovery
  * Removes Food
  * Replicates state

### B. Player vs HP Food

* HP Food:

  * `CanCollide = true`
* Rules:

  * Requires an actual attack
  * Normal movement should not consume it
* Server:

  * Validates attack
  * Reduces Food HP
  * Destroys Food only at HP `0`
  * Applies valid physical impact where configured
* Client:

  * Provides visual feedback
  * Does not authoritatively modify Food HP

### C. Player vs Player

* `CanCollide = true`
* Server resolves combat result
* Server may apply controlled `ApplyImpulse`
* Force is clamped by `PhysicsConfig`
* Friendly-fire damage rules still apply

## 5.8 Launch Combat Feel

* The client may perform immediate local feedback when predicting a valid collision.

### Step 1 – Impact Absorption

* `Velocity *= 0.6`
* Purpose:

  * Simulate impact against a heavy object

### Step 2 – Compression / Hitstop

* Pause predicted physics for approximately **50 ms**
* Purpose:

  * Add impact weight
  * Improve hit readability

### Step 3 – Bounce

* `Velocity = Reflect(Velocity, Normal) × 0.7`
* Purpose:

  * Reduce rebound energy
  * Produce a more controlled trajectory
* The server remains authoritative over the actual combat result.

## 5.9 Standard Hit Processing Pipeline

* Initiate:

  * Client enters `Launching`
  * Launch begins
* Simulate:

  * Client predicts trajectory
  * Client applies predicted drag / reaction forces
* Detect & Request:

  * Client detects possible collision
  * Executes local impact feedback
  * Sends hit request containing target information and timing data
* Validate:

  * Server verifies:

    * State
    * Timestamp
    * Distance / sweep
    * Cooldown
    * Rate limit
    * Plausibility
    * Other combat restrictions
* Resolve & Replicate:

  * Valid:

    * Apply combat result
    * Apply damage
    * Handle death
    * Handle elimination
    * Handle effects
    * Replicate state
  * Invalid:

    * Ignore request
    * Client resynchronizes to server state

# 6. LAUNCHER SYSTEM – STATS & ROLES

## 6.1 Launcher Ownership

* Launcher defines the player's base combat platform.
* Launcher is responsible for:

  * Base stats
  * Size
  * Movement profile
  * Launch profile
  * Physics characteristics
  * Role / archetype
* Launcher is **not** the source of individual combat status effects.
* Combat effects such as:

  * Stun
  * Slow
  * DoT
  * Petrify
  * Heal
  * Reflect
  * Special collision effects
* belong to the Equipment system.

## 6.2 Current Launcher Set

* Current launchers:

  * `NormalLauncher`
  * `TitanBulwarkLauncher`
  * `ZephyrDartLauncher`
  * `RavagerCoreLauncher`
* Launcher roles are based on stat / role characteristics such as:

  * Normal
  * Tank
  * Speed
  * Burst
* The exact numeric values are configuration data, not rules duplicated in this document.

## 6.3 Core Stats

* Launcher core stats may include:

  * MaxHP
  * BaseDamage
  * MoveSpeed
  * LaunchRange
  * Armor
  * Regen
  * EXPBonus
  * BaseSize
  * LaunchForce
  * Other physics-related baseline stats
* Combat effects are not implemented as Launcher archetype abilities.

## 6.4 Star Upgrade

* 3 identical Launchers → +1★
* Maximum: **3★**
* Balance principle:

  * A high-star common Launcher may have stronger raw statistics than a lower-star rare Launcher
  * Rare / higher-tier content may provide stronger or more specialized characteristics through configuration

## 6.5 In-Match Scaling

* Level up increases:

  * Size
  * Damage
  * Overall stats
* Base rule:

  * **+3% all stats** per defined level progression
* UI rule:

  * No direct stat-adjustment UI during a match

# 7. EQUIPMENT SYSTEM

## 7.1 Definition vs Owned Instance

* Equipment has two separate concepts.

### Definition

* Static configuration:

  * Equipment ID
  * Name
  * Rarity
  * Category
  * Ability definition
  * Base parameters
* Stored in:

  * `EquipmentConfig.Definitions`

### Owned Instance

* Persistent player-owned data:

  * Unique `instanceId`
  * Associated definition
  * Player ownership
  * Upgrade / instance-specific data where applicable
* Owned Equipment is persistent.
* Rule:

  * The client must never use `definitionId` as proof of ownership.
  * Server only accepts an `instanceId` that already exists in authoritative player data.

## 7.2 Equipped Slots

* Each player may equip multiple Equipment items.
* Current maximum:

  * **3 Equipment slots**
* Configured through:

  * `EquipmentConfig.EquippedSlotCount`
* Equipment architecture is therefore:

  * **1 Launcher + N Equipment**
* rather than:

  * **1 Launcher = 1 combat ability**

## 7.3 Equipment Effect Ownership

* All runtime combat effects are owned and orchestrated by:

  * `EquipmentEffectService`
* Examples include:

  * Stun
  * Slow
  * Fire / Burn
  * Poison
  * Petrify
  * Ghost-Flame
  * Heal
  * Reflect
  * Other equipment-defined effects
* Launcher code must not independently recreate Equipment effect logic.

## 7.4 Effect Lifecycle

* Every Equipment effect follows the common lifecycle where supported.

### `OnInit(launcherModel)`

* Runs when the Equipment effect is initialized
* Initializes required runtime state

### `OnLaunch(target / direction)`

* Triggered when Launch occurs
* Applies launch-based effects

### `OnAttack(...)`

* Triggered by attack-specific behavior
* Used for effects that require an attack event

### `OnCollision(hitPart, hitPosition)`

* Triggered when a valid server collision is resolved
* Applies combat effects

### `OnTick(deltaTime)`

* Optional
* Used for continuous effects
* Centrally managed
* Do not create separate Heartbeat connections for every effect

### `OnDestroy()`

* Cleans up:

  * Timers
  * Connections
  * Effects
  * Runtime state

* Lifecycle:

  * **OnInit → OnLaunch → OnAttack → OnCollision → OnTick → OnDestroy**

## 7.5 Equipment Rules

* Each Equipment has a defined scope
* Equipment cannot modify systems outside its contract
* Server is authoritative
* Client is responsible for:

  * VFX
  * UI
  * Prediction
* Multiple Equipment effects may coexist
* Equipment effects must pass through the common conflict-resolution rules

## 7.6 Effect Conflict Resolution

* Priority:

  * 1. Invulnerable
  * 2. Ghost
  * 3. Hard CC
  * 4. Damage / Heal
  * 5. DoT / Slow
  * 6. Visual-only effects

### Invulnerable

* Blocks incoming damage
* Immune to DoT
* Does not trigger reflected damage

### Ghost

* Ignores combat collision logic
* Does not trigger collision effects
* Receives no combat CC from collision

### Hard CC

* No infinite stacking
* Strongest / longest valid effect wins
* Priority:

  * Freeze > Stun

### Damage

* Collision must be valid before damage
* Blocked damage does not continue into downstream damage effects
* Reflect only occurs when the triggering damage is valid

### DoT

* Fire:

  * Maximum 3 stacks
* Poison:

  * Maximum 5 stacks
* Same-type DoT may:

  * Refresh duration
  * Add stack
  * Replace stack
* Exact behavior is configuration-driven

### Slow

* Slow modifies movement speed
* Slow does not override Hard CC
* Hard CC always takes priority

# 8. ITEM & TEAM

## 8.1 Items

### HP Potion

* `300 HP/s × 5s`

* Total: **1500 HP**

* Subject to cooldown

* Other item types may include:

  * Scale potion
  * EXP buff
  * Gacha ticket

### Sources

* Daily Login
* Chest
* Shop
* Event

## 8.2 Team

* Maximum:

  * **2 players**

### Friendly Fire

* Damage: OFF
* Knockback: still allowed

### Shared Win

* If one teammate wins:

  * Both teammates receive the same rank

### Assist Reward

* Assist condition:

  * Dealt damage within the last **10 seconds** before target death
* Assist may apply to:

  * Player kill
  * HP Food destruction
* Reward:

  * +50% EXP
  * +50% Diamonds

### Teammate Tracking

* When teammate is off-screen:

  * Show direction marker / Arrow
* Display:

  * Real distance between teammates

### Disconnect

* If teammate disconnects:

  * Remaining player becomes solo

# 9. ENVIRONMENT & SAFE ZONE

## 9.1 Safe Zone

* Safe Zone is represented by:

  * `SimulatorCircle` model
* Center:

  * Map center initially
* Behavior:

  * Shrinks continuously over time
  * Forces combat and positional pressure
* Outside Safe Zone:

  * Player loses HP over time
* Damage:

  * Percentage of MaxHP
  * Damage percentage increases over time
  * Example progression:

    * 1%/s → 10%/s
    * +1% every 30 seconds

## 9.2 Safe Zone Detection

* Server-authoritative distance check.
* Conceptual rule:

  * `distance = (position - center).Magnitude`
* Outside when:

  * `distance > radius`
* Check frequency:

  * Continuous server-side evaluation
  * Approximately every **0.1–0.25s** where periodic evaluation is used
* Safe Zone damage must not depend on client authority.

## 9.3 Safe Zone Relocation

* Safe Zone does not only shrink around a permanently fixed center.
* When configured threshold is reached:

  * Safe Zone may relocate its center
* Configuration:

  * `RelocationScaleThreshold`
  * `RelocationDurationSeconds`
* During relocation:

  * Safe Zone center moves
  * Safe Zone remains part of the authoritative round state
  * `IsRelocating` attribute identifies relocation activity
* This mechanism is separate from normal radius shrinking.

## 9.4 Traps

### Toxic Smoke / Fire / Lava

* Damage over time

### Spike

* Damage

### Totem

* Fires projectiles
* Pushes players

### General Trap Rules

* Fixed positions
* Always active
* Affect normal players
* Do not affect Ghosts

# 10. ECONOMY & PROGRESSION

## 10.1 Income

### Kill Reward

* Diamonds:

  * Depends on target level
  * Possible reward range: **0–6 Diamonds**
* EXP:

  * `50% of target's lost EXP`

### Other Sources

* Chest
* Event
* Daily rewards
* Robux



## 10.2 Diamonds Ledger

* `PlayerDataService` is the **single authoritative ledger** for Diamonds.
* Rule:

  * Persistent Diamonds are stored and modified through the player data authority
  * Runtime snapshots sent to the client are mirrors only
  * UI state / runtime cache must never become an independent spending source
* All Diamond transactions must resolve against the authoritative ledger.


# 11. STATE & FLAG SYSTEM – PLAYER

## 11.1 Player States

* High-level PlayerState values:

  * `Idle`
  * `Moving`
  * `Charging`
  * `Launching`
  * `Dead`

### Idle

* Default state
* No active movement input

### Moving

* Normal player movement

### Charging

* Holding input to prepare Launch
* Cannot normal-move

### Launching

* Physics-controlled movement
* Cannot re-enter Charging until Launch resolves

### Dead

* No actions
* Input ignored

## 11.2 State Transition

* Core transitions:

  * `Idle → Moving`
  * `Moving → Charging`
  * `Charging → Launching`
  * `Launching → Idle`
  * `Any → Dead` when HP ≤ 0
* Launch completion may occur when:

  * Velocity falls below configured threshold
  * Collision resolves Launch
  * Other configured resolution condition occurs

## 11.3 Movement Rule

* A player may move only when:

  * State is not `Dead`
  * State is not `Charging`
  * State is not `Launching`
  * No active `Stun`
  * No active `Freeze`
* Flags may override otherwise-valid state behavior.

## 11.4 Flags

* Flags are modifiers layered on top of PlayerState.
* Supported flag types:

  * `Ghost`
  * `Slow`
  * `Stun`
  * `Freeze`
  * `PoisonTrap`
  * `Invisible`
  * `Recovering`
  * `Invulnerable`

### Ghost

* No combat collision
* No combat damage
* Invisible to normal players
* Visible to other Ghosts
* Can move after intro delay
* Can consume allowed Common Food
* Cannot use Launch
* Cannot consume HP Food

### Slow

* Reduces movement speed

### Stun

* Disable input
* Disable movement
* Interrupt Charging

### Freeze

* Strong Hard CC
* Disable movement
* Disable rotation
* Interrupt Charging / Launch preparation as required

### PoisonTrap

* Periodic damage

### Invisible

* Hidden from enemy UI / targeting according to visibility rules

### Recovering

* Periodic healing

### Invulnerable

* Ignore incoming damage
* Ignore DoT
* Prevent reflect caused by blocked damage

## 11.5 Flag Properties

* Each flag may define:

  * Duration
  * Stackability
  * Maximum stack
  * Source
  * Runtime state

## 11.6 Flag Priority

* Priority:

  * **Freeze > Stun > Slow**
* General conflict resolution:

  * Hard CC overrides movement
  * Ghost overrides combat collision behavior
  * Invulnerable overrides damage intake
  * Invisible modifies visibility
  * Recovering modifies HP
  * Other flags operate without overriding higher-priority rules

## 11.7 State + Flag Resolution Pipeline

* Core principle:

  * **State defines intent.**
  * **Flag modifies or overrides behavior.**
  * **Server resolves the final result.**
* Example:

  * State = `Moving`
  * Flag = `Stun`
  * Final result = cannot move
* Example:

  * State = `Launching`
  * Flag = `Invulnerable`
  * Final result = Launch continues, but incoming damage is blocked
* Example:

  * Player dies in FinalPhase
  * State = `Dead`
  * `Ghost` flag is applied according to round rules
  * Ghost behavior is then controlled by the Flag system, not by creating a separate `Ghost` PlayerState

# 12. SESSION & ARCHITECTURE PRINCIPLES

## 12.1 Session States

* Session-level location states:

  * `Lobby`
  * `Loading`
  * `InGame`

### Lobby

* Player is in Lobby
* Can interact with Lobby systems
* Cannot deal combat damage

### Loading

* Preparing player / map
* Disable inappropriate interaction until ready

### InGame

* Player is bound to active Arena

* Full gameplay rules are available according to RoundState and PlayerState

* Flow:

  * **Lobby → Loading → InGame → Lobby**

## 12.2 Player Data & Map Binding

* Authoritative PlayerData includes:

  * `LocationState`

    * Lobby
    * Loading
    * InGame
  * `CurrentMap`

    * nil or map reference

### Join Map

* When joining:

  * `playerData.CurrentMap = map`
  * `map.Players[player] = true`
  * `playerData.LocationState = InGame`

### Leave Map

* When leaving:

  * Remove player from `map.Players`
  * `playerData.CurrentMap = nil`
  * `playerData.LocationState = Lobby`

## 12.3 Round State vs Player State

* These are separate concepts.

### RoundState

* Lobby
* Awaits
* EarlyGame
* FinalPhase
* RoundEnd
* PostRound

### PlayerState

* Idle
* Moving
* Charging
* Launching
* Dead

### Flags

* Modify PlayerState behavior:

  * Ghost
  * Slow
  * Stun
  * Freeze
  * Invisible
  * Invulnerable
  * Recovering
  * Other supported flags
* Ghost is **not** a RoundState or high-level PlayerState.

## 12.4 Service Resolution

* Services must not directly require each other when doing runtime service lookup.
* Use:

  * `ServiceRegistry`
  * `ServiceResolver.Get(context, "ServiceName")`
* Purpose:

  * Centralized service registration
  * Avoid circular dependency
  * Standardize service access
  * Keep service ownership explicit

## 12.5 Server-Authoritative Boundaries

### Server Owns

* Player authoritative state
* Player data
* Player ownership
* Equipment ownership
* Diamonds ledger
* Combat result
* Damage
* HP
* Death
* Elimination
* Food authoritative state
* Safe Zone
* Team state
* Round state
* Validation
* Physics constants
* Authoritative movement constraints
* Authoritative orientation
* Equipment effect resolution

### Client Owns

* Input
* Local presentation
* UI
* VFX / SFX
* Local prediction
* Potential collision detection
* Local responsiveness
* Client must never become the source of truth for:
  * Damage
  * Kill
  * Rewards
  * Diamonds
  * Equipment ownership
  * Food authoritative state
  * Final collision result

## 12.6 Configuration Source of Truth

### Physics

* `PhysicsConfig.lua`
* Source of truth for:

  * Movement
  * World physics
  * Charge
  * Launch
  * Knockback
  * Collision
  * Stability
  * Lag compensation

### Launcher

* `LauncherConfig.lua`
* Source of truth for:

  * Launcher definitions
  * Base statistics
  * Launcher role characteristics

### Equipment

* `EquipmentConfig.lua`
* Source of truth for:

  * Equipment definitions
  * Equipped slot count
  * Equipment metadata
  * Effect configuration

### Safe Zone

* `SafeZoneConfig.lua`
* Source of truth for:

  * Safe Zone configuration
  * Shrink behavior
  * Relocation threshold
  * Relocation duration
  * Relocation state attributes

### Balance

* Balance-specific numbers should remain in the appropriate configuration / balance source rather than being duplicated as architecture rules in this document.

## 12.7 Architecture Principles

* 1. **Server is authoritative for gameplay truth.**
* 2. **Client predicts for responsiveness, but prediction never becomes authority.**
* 3. **State defines intent; Flags modify behavior.**
* 4. **Ghost is a Flag, not a high-level PlayerState.**
* 5. **Launcher defines base stats / movement role; Equipment defines combat effects.**
* 6. **Equipment ownership is instance-based and persistent.**
* 7. **Diamonds have one authoritative ledger.**
* 8. **Collision is event-driven, not fixed Food/Player polling.**
* 9. **Collision validation is centralized in** **`CollisionValidation`**.
* 10. **Rate limiting, hit deduplication and clock synchronization are mandatory parts of combat validation.**
* 11. **Food queries use spatial partitioning rather than full-list scans.**
* 12. **Physics constants come from** **`PhysicsConfig.lua`**.
* 13. **Runtime services resolve dependencies through** **`ServiceResolver`** **/** **`ServiceRegistry`**.
* 14. **Configuration contains data; gameplay logic belongs in services / systems.**
* 15. **Avoid conflicting ownership where two systems independently modify the same authoritative state.**
