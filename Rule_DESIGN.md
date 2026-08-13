1. Core game loop
2. Round Rules
3. FOOD SPAWN SYSTEM
4. PHYSICS & COMBAT
5. LAUNCHER SYSTEM
6. PROGRESSION & UPGRADE
   - Phase 1 Equipment foundation: Equipment definitions are shared config, owned Equipment is instance-based persistent data, equipped slots reference owned instance IDs only, and upgrade costs are computed server-side from `EquipmentUpgradeConfig`.
7. ITEM & TEAM
8. ENVIRONMENT & SAFE ZONE
9. ECONOMY & PROGRESSION
   - Diamonds are canonical in `PlayerDataService`; runtime player state only mirrors the value for snapshots and must not be used as an independent spending ledger.
10. STATE SYSTEM
11. FLAG SYSTEM
12. EQUIPMENT SYSTEM
   - Equipment is N-per-player and effect modules are orchestrated by `EquipmentEffectService` through one shared Heartbeat.
   - Phase 1 includes placeholder definitions/effects only; the full 20-Equipment catalog, production Equipment UI, and complex runtime effects are deferred.
# 🔥 LAUNCHER ARENA – MASTER GAME DESIGN SPECIFICATION (FINAL)

# 0. DESIGN GOAL
- Genre: Survival Physics Arena (Round-based)
- Core Experience: Farm Food to level up, use physics to collide with and push opponents into traps or the shrinking zone
- Philosophy: Skill & Coordination > Raw Stats
- Core Feeling: “Launch – Impact – Bounce – Slide” must feel strong and responsive

# 1. CORE GAME LOOP
1. Lobby: Select / Buy / Spin Launcher, Equip Items, Upgrade Stars
2. Start: Join Map, Farm Food, Level Up
3. Mid Game: Combat, Position Control, Use Traps
4. Late Game: Shrinking Zone, Forced Fights, Survival
5. End: Last player alive wins, rewards granted, round reset

# 2. ROUND RULES

## 2.1 World & Map
- Size: 700x700 studs (Square Arena)
- Boundary: Surrounded by walls
- Players: 12

Spawn Logic:
- Player: Random spawn near edges
- Food: Spawn in clusters (FoodSpawns)
- Traps: Fixed positions
- Launcher/Launcher: Can Move (WASD) and Launch

## 2.2 Early Game (0 → 8 minutes)
- Mechanic: Free farming + combat
Death:
- Respawn after 3s
- Random position inside Safe Zone
- -30% current EXP
Join:
- New players can join

## 2.3 Final Phase (8 → 10 minutes)
Death:
- No respawn → becomes Ghost
Ghost State:
- 0–5s: immobile
- After: Can only move (state = Ghost)

Team:
- No new team formation allowed during this phase
- Players without team play solo

Join Rule:
- Join after minute 8 → becomes Ghost immediately
- Can still farm + level
- Cannot Launch

## 2.3.1 FINAL PHASE + GHOST SYSTEM (DETAIL)

Ghost Activation
Trigger:
* Player dies during Final Phase
* Player joins after minute 8

Ghost State Rules

Movement
* Can move freely (no collision with players)
* No physics interaction

Combat
* Cannot Charge
* Cannot Launch
* Cannot deal damage

Visibility
* Invisible to normal players
* Visible to other Ghosts

Farming
* Can eat Normal Food
* Cannot interact with HP Food

Intro Delay

* First 5 seconds:
  * Cannot move
  * Fully disabled

## 2.4 State

Lobby:
- Cannot attack
- Active when player is in Lobby Map

Arena:
- Can attack
- Active when player is in Arena Map

Ghost:
- Can only move and farm foods, cannot Launch
- Cannot farm HP Foods (requires attack)
- Invisible to non-Ghost players
- Cannot deal damage
- Activated on death or joining during final phase

## 2.5 Flags
- Visibility:
  + True: Visible
  + False: Invisible (Ghost or skill effect)

- Stun:
  + Cannot move or Charge/Launch
  + Charging is interrupted immediately

## 2.6 Round Lifecycle

States: Lobby, Awaits, EarlyGame, FinalPhase, RoundEnd, PostRound
1. Lobby
   Players stay in the Lobby map
   Can open UI (Shop, Inventory, Spin)
   Players can join the Arena Map
   After leaving the Arena, there is a 15-second cooldown before rejoining
  -- Re-Round (PostRound States)
   When the round ends, all players are teleported back to the Lobby
   Reset the game state for the next round
   Reset: Map, Food, Player state, temporary flags and round data
   When the Map is ready, transition to the next state

2. Awaits
   The safe zone only starts shrinking when enough players have joined the map
   During this phase, players can farm and attack other players normally
   However:

* EXP gain is reduced by 50%
* No Diamonds are rewarded
* No special rewards spawn in the map

Limit gameplay systems are enabled: Movement, Charge, Launch, Food farming, (No Damge when Launch, Applly for Player + Hp Foods)

3. EarlyGame (0 → 8 minutes)
   Trigger: At least 3 players are in the map
   The safe zone starts shrinking

Display message: “Safe zone is shrinking. EXP gain is now 100%.”
Full gameplay systems are enabled: Movement, Charge, Launch, Food farming, Combat

4. FinalPhase (8 → 10 minutes)
   Trigger: Safe zone reaches minimum radius
Disable: Respawn, New team creation
Enable: Ghost system

5. RoundEnd
- Trigger: Only 1 player or 1 team remains alive ( if state == EarlyGame or FinalPhase then check win condition)
- Flow:
0–5s: Freeze all players, determine winner
5–15s: Show result UI, grant rewards


## 2.7 End Condition
- Winner: Last player alive
After Win:
- Safe zone stops dealing damage
Flow:
- 5s: Determine winner
- 15s: Show rank + reward,
- Reset round

# 3. FOOD SPAWN SYSTEM (TECHNICAL)

## 3.1 Structure
- Foods type: Common, Uncommon, Rare, Epic, Legendary. Spawn marker naming: "FoodSpawn"

## 3.2 Spawn Rule
- Radius: ±5 studs (X, Z)
- Formula: spawnPos = FoodSpawn.Position + Vector3.new(random(-5,5), 0, random(-5,5))
- Density: 1 FoodSpawn = 5 Common Food active or 1 Hp Food

## 3.3 Food Zones

### A) Common Food (Touch)
- Type: Common
- Behavior:
  + Disappears on valid contact
  + Grants EXP + heals HP

- Server Rules:
  + On valid server-confirmed collision, remove the Food on the Server

- Respawn:
  + Each destroyed Food → respawn exactly 1 after 10 seconds

### B) HP Food (Must Hit)
- Type: Uncommon, Rare, Epic, Legendary
- Behavior:
  + Requires attack (last hit)
  + Grants EXP + chance for Diamonds

- Server Rules:
  + On valid server-confirmed hit, reduce HP on the Server
  + Destroy only when HP reaches 0

- Respawn:
  + Each destroyed Food → respawn exactly 1 after 30 seconds

## 3.4 Maintenance
- No overlap within same cluster
- Rate Spawn:
+ MidZones: Common (70%), Uncommon (15%), Rare (10%), Epic (5%), Legendary (0%)
+ EdgeZones: Common (65%), Uncommon (15%), Rare (10%), Epic (5%), Legendary (5%)
+ CenterZones: Common (0%), Uncommon (0%), Rare (0%), Epic (70%), Legendary (30%)
# 4. PHYSICS & COMBAT

## 4.1 Core Philosophy & Architecture
The physics and collision system strictly follows the **Client-Side Prediction + Server Authoritative** model. The goal is to eliminate the noise of "fake physics" during normal movement, while maximizing collision feel (game feel) during combat.

*   **Client (The "Feel" Layer):**
    *   Responsible for simulating movement, velocity, bounce, and effects (VFX/SFX).
    *   Each client only simulates physics for itself.
    *   Predicts collision and knockback for immediate feedback, but does not decide the final outcome.
*   **Server (The "Truth" Layer):**
    *   Holds the final authority.
    *   Validates collisions using Distance Check / Threshold.
    *   Controls Damage, HP, Kill, and State logic.
    *   Replicates valid results to all clients.

## 4.2 Formula
- ImpactDamage = BaseDamage × CollisionSpeedMultiplier
- Size = BaseSize × (1 + sqrt(Level) × 0.08)
- RequiredEXP = BaseEXP × (Level ^ 1.3)

## 4.3 Combat Flow
- Move → Charge → Launch → Collision → Damage + Knockback
- Physics rules: Gravity, Mass, Friction, Inertia, Knockback
- Prevent multi-hit spam during a single contact window
- Any applied force must be clamped by `PhysicsConfig.lua`


## 4.4 State-Based Physics Rules
Physics rules change entirely based on the player’s current `PlayerState`.

### A. State = "Moving" (Normal Movement)
*   **Goal:** Smooth movement, not affected by junk physics.
*   **Collision Rules:**
    *   **No Damage & No Bounce:** Contact with other players or Food is purely visual (visual overlap), with no force applied or impact on match outcomes.
    *   **Ignore physics with Solid Objects:** If colliding with Food that has HP (Type != "Common"), the system completely IGNORES physical resistance.
*   **Interaction with Flag "Ghost":**
    *   The player passes through everything (other players, Food with HP).
    *   Can only interact (consume) Food marked as `Common`.

### B. State = "Launching" (Attack / Launch State)
*   **Goal:** Realistic weight, compression, and precise damage.
*   **Collision Rules:**
    *   Applies real physics (Velocity, Knockback, Damage, Reaction force).
    *   Damage is applied **only once** at the moment of impact.
    *   Maximum velocity must be limited by Drag to gradually slow down, preventing uncontrollable high-speed movement.

## 4.5 Reconciliation Rules
Client collision and knockback should follow the same logic as the Server as closely as possible, but the Server always has the final result.

- If the desync is small (minor desync):
  + use Lerp / Smooth correction

- If the desync is large:
  + immediately update the client to the Server state

- If the client already applied knockback, but the Server later confirms that no collision happened:
  + cancel the local knockback immediately
  + resync position and velocity from the Server

## 4.6 Collision Architecture
- Collision is **server authoritative**
- Client may detect potential overlap and send a hit trigger, but **client touch events are not the source of truth**
- Use **Client-Side + Server Check**:
  + Client detects possible contact
  + Server validates distance, state, cooldown, and plausibility
- Server manages the positions/state of Food and Player
- Use a fixed server check interval of `task.wait(0.1)` for broad polling
- Use **spatial grid / zone filtering** so the server only checks nearby foods

## 4.7 Collision Math (Player / Launcher vs Food)

### A) Core Distance Check
Let:
  + P = Player root position
  + F = Food position
  + rP = Player collision radius
  + rF = Food collision radius
  + Ping = estimated round-trip / 2
  + ε = small tolerance margin

Lag-compensated effective radius:
  + rEffective = rP + rF + (PlayerSpeed * Ping) + ε

Collision condition:
  + d <= rEffective

Where:
  + d = |P - F|

### B) Horizontal Check (recommended for ground-based food)
- Use XZ plane distance to ignore small Y offsets:
  + dXZ = sqrt((Px - Fx)^2 + (Pz - Fz)^2)

- Optional vertical tolerance:
  + |Py - Fy| <= YTolerance

- Collision condition:
  + dXZ <= rEffective
  + AND |Py - Fy| <= YTolerance

### C) Fast Movement / Launch Check
- When Launcher / Player moves very fast, use swept collision to avoid missing hits:
  + A = previous player position
  + B = current player position
  + F = Food position

- Compute:
  + t = clamp(((F - A) · (B - A)) / |B - A|^2, 0, 1)
  + ClosestPoint = A + t * (B - A)
  + d = |F - ClosestPoint|

- Collision condition:
  + d <= rEffective

### D) Server Validation
- Server must verify:
  + food exists
  + food is active
  + player exists and is alive
  + cooldown / anti-spam passes
  + distance / horizontal / swept check passes
  + client-reported hit is plausible, if a client trigger is used
  + player velocity is within allowed threshold

## 4.8 Collision Types

### A) Player vs Common Food
- Common Food:
  + `CanCollide = false`
  + `CanTouch = false`
- Client:
  + may detect overlap locally using distance or spatial query
  + may hide the Common Food immediately for instant feedback
  + sends a trigger to the server
- Server:
  + validates the hit
  + grants EXP / heals HP
  + removes the Food on the server
  + replicates the state change to all clients

### B) Player vs HP Food
- HP Food:
  + `CanCollide = true`
  + does not allow the player to pass through
- Server:
  + handles the real hit
  + reduces HP
  + destroys the Food only when HP reaches 0
  + may apply `ApplyImpulse` on the server to create a strong impact feel
- Client:
  + only plays visual feedback
  + must not decide damage or destroy state

### C) Player vs Player
- `CanCollide = true`
- Server resolves the impact
- Use `ApplyImpulse` on the server to create a strong controlled bounce / hit
- Clamp force to avoid unstable physics

---

## 4.9 The "Launch" Combat Feel (Hitstop & Bounce Logic)
To fix collisions feeling too "light" or "instant", the event sequence when a Client detects a collision (in Launching state) is split into 3 steps to create a "Compression Feeling":

1.  **Impact Absorption:**
    *   Immediately upon collision detection: `Velocity *= 0.6`
    *   *Purpose:* Instantly reduce velocity to simulate hitting a massive object.
2.  **Compression / Hitstop:**
    *   Pause physics (Delay) for `50ms`.
    *   *Purpose:* Create artificial "impact time" to give weight and depth to the hit.
3.  **Realistic Bounce:**
    *   Bounce handling: `Velocity = Reflect(Velocity, Normal) * 0.7`
    *   *Purpose:* Reduce 30% of energy after collision to simulate energy loss, making the rebound trajectory more realistic and controllable.

---

## 4.10 Standardized Execution Flow (Hit Processing Pipeline)
All collision (Hit) phases in the game must strictly follow this lifecycle:

1.  **Initiate:** Client switches to `PlayerState.Launching` and begins movement.
2.  **Simulate:** Client simulates trajectory, calculates Drag and reaction forces for smooth feel.
3.  **Detect & Request:** Client detects collision with Food/Player -> Immediately executes Hitstop & Bounce (Section 4.9) -> Sends Hit Request (including Target ID, Moment) to Server.
4.  **Validate:** Server receives the request and validates:
    *   Is the player in `Launching` state?
    *   Is the distance check valid?
5.  **Resolve & Replicate:**
    *   If valid: Server applies HP reduction, handles death/elimination, updates state, and replicates results to all clients.
    *   If invalid (Lag/Hack): Server ignores the request, and the client automatically resyncs to the correct position from the server.

---

## 4.11 Hitbox Shapes
- Player: Sphere
- Common Food: Sphere
- HP Food: Sphere preferred, Box allowed if the food shape requires it
- Use simplified hitboxes only; do not rely on mesh collision for core gameplay

---

## 4.12 Anti-Hack / Validation Rules
- Server must reject hit if:
  + distance is invalid
  + velocity exceeds allowed threshold
  + cooldown has not expired
  + food no longer exists
  + food is not active
  + player is dead / invalid
  
# 5. LAUNCHER SYSTEM (CHARACTERS)

## 5.1 Core Stats
- MaxHP: 10,000 → 30,000
- BaseDamage: 500 → 3,000
- MoveSpeed: depends on type, scales by archetype
- LaunchRange: base launch distance / force
- ReflectDamage: % of damage reflected under certain effects
- Armor: % damage reduction
- Regen: % health regeneration (conditional or passive)
- EXPBonus: % bonus experience gained
- CollisionCC: crowd control duration on collision
- StealthTime: duration of invisibility
- DoT: damage over time (Fire / Poison)
- DOTStack: max stack count for DoT
- SlowAmount: % movement slow
- SlowDuration: duration of slow effect

## 5.2 Archetypes (Passive / Type Launcher)

- StunLauncher:
  + Collision applies 1s stun to enemies
  + Used for engage / control

- NormalLauncher:
  + +50% EXP gain
  + No special combat effect

- VacuumLauncher:
  + Pulls nearby Mini Foods
  + Uses distance check on Client
  + Only requires tuning scan radius in existing system
  + Optimized for farming

- StealthLauncher:
  + Invisible during charge
  + Remains invisible for 1s after launch
  + Revealed on collision / dealing damage / other reveal logic

- HealLauncher:
  + Heals 5% MaxHP on each launch
  + Triggered on OnLaunch

- PetrifyLauncher:
  + Collision petrify enemy for 1.5s

- FireLauncher:
  + Applies burn damage over time
  + Max 3 stacks
  + Each stack deals damage per tick

- PoisonLauncher:
  + Applies poison damage over time
  + Max 5 stacks
  + Each stack deals damage per tick
  + Applies slow effect

## 5.3 Launcher Ability

### 5.3.1 Trigger Type
Each ability must define:

- OnInit(launcherModel):
  + Runs once when Launcher is spawned
  + Used to initialize stats (HP, Speed, Armor, Damage, flags)

- OnLaunch(target/direction):
  + Triggered when player releases
  + Handles launch behavior (buffs, heal, speed, effects)

- OnCollision(hitPart, hitPosition):
  + Triggered when Server detects collision
  + Handles damage, heal, CC, DoT, reflect, reveal

- OnTick(deltaTime):
  + Optional
  + Runs every frame on Server for continuous logic
  + Managed centrally via Heartbeat loop
  + Do NOT create individual Heartbeat connections per ability

- OnDestroy():
  + Cleanup
  + Remove connections, timers, effects, states

### 5.3.2 Ability Rule
- Each Launcher has only ONE main type
- Type defines core behavior
- Buffs / modifiers can extend but NOT override core rules
- Server is authoritative for all logic
- Client handles VFX / UI / prediction only
- Abilities must not operate outside their defined scope

### 5.3.3 Base Class Rule
- All abilities inherit from a base class
- Shared interface across all abilities
- Base class provides:
  + Init
  + Launch
  + Collision
  + Tick
  + Destroy
  + Config access
  + State access
- Child classes override specific behaviors only

## 5.4 Conflict Resolution Rule
Effects resolve in the following priority:

1. Invulnerable  
2. Ghost  
3. Hard CC (Freeze / Stun)  
4. Damage / Heal  
5. DoT / Slow  
6. Visual-only effects  

- Invulnerable:
  + Blocks all damage
  + Immune to DoT
  + No reflect triggered

- Ghost:
  + Ignores collision logic
  + Does not trigger OnCollision effects
  + No CC from collision

- Hard CC:
  + No infinite stacking
  + Only strongest or longest effect applies
  + Priority: Freeze > Stun

- Damage Resolution:
  + If blocked (e.g. Invulnerable), skip all damage logic
  + Collision must be valid before applying effects
  + Reflect only applies if base damage is accepted

- DoT Resolution:
  + Fire max stack = 3
  + Poison max stack = 5
  + Same-type DoT can refresh duration or stack (config-based)
  + Server clamps to max stack

- Slow Resolution:
  + Poison may apply slow
  + Slow cannot override Hard CC
  + Hard CC always takes priority

- Special Interaction:
  + FreezeLauncher cannot freeze FireLauncher
  + SupportLauncher heals allies, never damages
  + VacuumLauncher uses client-side scan only

## 5.5 Suggested Balance Rules
- 10k–30k HP for tank / control types
- Lower HP + higher damage for burst types
- 500–3k damage baseline
- Support = lower damage, higher utility
- Control = limited CC chaining
- SpeedLauncher should have cap or diminishing return
- CC / DoT should have limits or cooldowns
- VacuumLauncher should not introduce heavy server logic

## 5.6 Final Resolution Order
- OnInit → set stats
- OnLaunch → apply launch logic
- OnCollision → apply combat logic
- OnTick → continuous logic
- OnDestroy → cleanup
- Conflict Resolution → final server decision

# 6. PROGRESSION & UPGRADE

## 6.1 Star Upgrade
- 3 identical Launchers → +1★
- Max: 3★

Balance:
- 3★ common can be stronger than 2★ rare (stats)
- Rare has unique skills

## 6.2 In-match Scaling
- Level up:
  + Increase Size
  + Increase Damage
  + +3% all stats
- UI Rule: No stat adjustment UI during match

# 7. ITEM & TEAM

## 7.1 Items
- HP Potion: 300 HP/s × 5s = 1500 HP (with cooldown)
- Others: Scale potion, EXP buff, Gacha ticket
Sources:
- Daily Login, Chest, Shop, Event


## 7.2 Team
- Max: 2 players
- Friendly fire: OFF (no damage, still knockback)
- Shared Win: If 1 teammate wins -> Both receive same rank
- Assist Reward:
  + Condition: Deal damage within last 10s before target death
  + Assist kill (Player or HP Food)
  + Gain +50% EXP and Diamonds
- Off-screen teammate:
  + Show direction marker (Arrow)
- Show real distance between teammates
- If teammate disconnects: Player becomes solo

# 8. ENVIRONMENT & SAFE ZONE

## 8.1 Safe Zone
- Behavior
  Shape: SimulatorCircle (Model)
  Center: Map center
  Shrink: Continuous over time
- Shrinks over time → force combat
Outside:
- Lose % HP per second, (Check liên tục bằng math)
- Damage increases over time (1%/s → 10%/s)

## 8.1.1 Safe Zone- Teach Rule
- Safe Zone Detection
  Use distance check (2D): distance = (pos - center).Magnitude
  Outside if: distance > radius
  Loop check every 0.1–0.25s (server authoritative)

- Safe Zone Damage
  Apply damage if outside zone
  Scale over time: damage = MaxHP × %
  Increase % per interval (1% → 10%), +1% every 30s

## 8.2 Traps
- Lava: Death after 3s
- Toxic Smoke / Fire: Damage over time
- Spike: Damage + Knockback
- Totem: Shoots projectiles to push players
- General Rule
  Fixed positions
  Always active
  Affect all players (except Ghost)

# 9. ECONOMY & PROGRESSION

## 9.1 Income
- Kill:
  + Diamonds (tùy vào Level của đối thủ bị kill, có thể nhận từ 0-6 dinamonds)
  + EXP = 50% of target’s lost EXP
- Others: Chest, Event, Daily, Robux
- Assist +50% reward (EXP + Diamonds)
## 9.2 VIP
- Price: 1000 Diamonds / 7 days
- Buff: +20% EXP from Food
(Does NOT stack, Only refresh duration)
# 10. STATE SYSTEM (PLAYER)

## 10.1 Player States
- Idle: Default state, no active input
- Moving: Player is moving normally
- Charging: Holding input to prepare launch
- Launching: Player is in launched physics state
- Dead: Player is eliminated, no actions allowed

## 10.2 State Rules
- Dead:
  + Disable all actions
  + Ignore input
- Charging:
  + Cannot move
  + Can transition to Launching
- Launching:
  + Movement controlled by physics
  + Cannot re-enter Charging until resolved
- Idle / Moving:
  + Normal control allowed

## 10.3 State Transition
- Idle → Moving (input)
- Moving → Charging (hold input)
- Charging → Launching (release input)
- Launching → Idle (velocity below threshold or collision resolve)
- Any → Dead (HP <= 0)

## 10.4 STATE + FLAG RESOLUTION

### 10.4.1 Movement Rule
A player can move only if:

- State != Dead
- State != Charging
- State != Launching
- No active Stun
- No active Freeze

### 10.4.2 Final Behavior Pipeline
- State defines intent (what player is doing)
- Flag modifies or overrides behavior
- Final result is resolved on server

---

# 11. FLAG SYSTEM (MODIFIERS)

## 11.1 Flag Types
- Ghost: Ignore collision, ignore damage
- Slow: Reduce movement speed
- Stun: Disable input and movement
- Freeze: Strong CC, disable move + rotate
- PoisonTrap: Damage over time
- Invisible: Hidden from enemy UI
- Recovering: Heal over time
- Invulnerable: Ignore incoming damage

## 11.2 Flag Properties
- Duration: Time the flag is active
- Stackable: Whether multiple stacks are allowed
- MaxStack: Maximum stack count (if applicable)

## 11.3 Flag Rules
- Stun / Freeze:
  + Override movement (cannot move)
- Slow:
  + Modify movement speed (stack if allowed)
- Ghost:
  + Ignore collision checks
- Invulnerable:
  + Ignore all damage sources
- Invisible:
  + Hide UI / targeting
- PoisonTrap:
  + Apply periodic damage
- Recovering:
  + Apply periodic healing

## 11.4 Priority Rule
- Freeze > Stun > Slow
- Hard CC overrides all movement-related states

---

## 11.5 SESSION SYSTEM

### 11.5.1 Session States
- Lobby: Pre-game state
- Loading: Preparing player / map
- InGame: Active gameplay

### 11.5.2 Session Rules
- Lobby:
  + Players can interact but cannot deal damage
- Loading:
  + Disable spawn / interaction until ready
- InGame:
  + Full gameplay enabled

### 11.5.3 Flow
Lobby → Loading → InGame → Lobby

## 11.6 MAP / ROUND SYSTEM

### 11.6.1 Round States
- Lobby: No active round
- Awaits: Waiting for players or timer
- EarlyGame: Main gameplay phase
- FinalPhase: Endgame pressure phase
- RoundEnd: Round finished
- PostRound: Cleanup / transition

### 11.6.2 Rules
- PostRound is treated as Lobby at player/session level
- Round logic handled by Round Service (server authority)

## 11.7 PLAYER DATA & MAP BINDING

### 11.7.1 PlayerData
- LocationState: Lobby | Loading | InGame
- CurrentMap: nil or map reference

### 11.7.2 Join Map
- playerData.CurrentMap = map
- map.Players[player] = true
- playerData.LocationState = InGame

### 11.7.3 Leave Map
- Remove player from map.Players
- playerData.CurrentMap = nil
- playerData.LocationState = Lobby

## 11.8 DESIGN PRINCIPLES

- Server is authoritative for State and Flag
- Client only reads and renders
- Config contains data only (no logic)
- All behavior resolved via State + Flag pipeline
- Avoid conflicting logic between State and Flag
