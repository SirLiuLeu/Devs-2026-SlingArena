# 🔥 SLING ARENA – MASTER GAME DESIGN SPECIFICATION (FINAL)

# 0. DESIGN GOAL
- Genre: Survival Physics Arena (Round-based)
- Core Experience: Farm Food to level up, use physics to collide with and push opponents into traps or the shrinking zone
- Philosophy: Skill & Coordination > Raw Stats
- Core Feeling: “Launch – Impact – Bounce – Slide” must feel strong and responsive

# 1. CORE GAME LOOP
1. Lobby: Select / Buy / Spin Sling, Equip Items, Upgrade Stars
2. Start: Join Map, Farm Food, Level Up
3. Mid Game: Combat, Position Control, Use Traps
4. Late Game: Shrinking Zone, Forced Fights, Survival
5. End: Last player alive wins, rewards granted, round reset

# 2. ROUND RULES

## 2.1 World & Map
- Size: 700x700 studs (Square Arena)
- Boundary: Surrounded by walls
- Players: 12
- Traps: 10 (fixed)

Spawn Logic:
- Player: Random spawn near edges
- Food: Spawn in clusters (FoodSpawns)
- Traps: Fixed positions
- Sling/Launcher: Can Move (WASD) and Launch

## 2.2 Early Game (0 → 8 minutes)
- Mechanic: Free farming + combat
Death:
- Respawn after 5s
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
- Invisible
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
- Foods type: Common, Uncommon, Rare, Epic, Legendary, Mythic, Unique Naming: "FoodSpawn"

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
- Type: Uncommon, Rare, Epic, Legendary, Mythic, Unique
- Behavior:
  + Requires attack (last hit)
  + Grants EXP + chance for Diamonds

- Server Rules:
  + On valid server-confirmed hit, reduce HP on the Server
  + Destroy only when HP reaches 0

- Respawn:
  + Each destroyed Food → respawn exactly 1 after 30 seconds
  + Each destroyed "Unique" Food → respawn exactly 1 after 90 seconds

## 3.4 Maintenance
- No overlap within same cluster
- Rate Spawn:
+ MidZones: Common (20%), Uncommon(20%), Rare (20%), Epic (20%), Legendary(10%), Mythic (10%)
+ EdgeZones: Common (40%), Uncommon(30%), Rare(30%)
+ CenterZones: Unique (20%), Mythic(80%)

# 4. PHYSICS & COMBAT

## 4.1 Formula
- ImpactDamage = BaseDamage × CollisionSpeedMultiplier
- Size = BaseSize × (1 + sqrt(Level) × 0.08)
- RequiredEXP = BaseEXP × (Level ^ 1.3)

## 4.2 Combat Flow
- Move → Charge → Launch → Move → Collision → Damage + Knockback
- Physics rules: Gravity, Mass, Friction, Inertia, Knockback
- Prevent multi-hit spam during a single contact window
- Any applied force must be clamped by `PhysicsConfig.lua`

## 4.3 Collision Architecture
- Collision is **server authoritative**
- Client may detect potential overlap and send a hit trigger, but **client touch events are not the source of truth**
- Use **Client-Side + Server Check**:
  + Client detects possible contact
  + Server validates distance, state, cooldown, and plausibility
- Server manages the positions/state of Food and Player
- Use a fixed server check interval of `task.wait(0.1)` for broad polling
- Use **spatial grid / zone filtering** so the server only checks nearby foods

## 4.4 Collision Math (Player / Sling vs Food)

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
- When Sling / Player moves very fast, use swept collision to avoid missing hits:
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

## 4.5 Collision Types

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

## 4.6 Hitbox Shapes
- Player: Sphere
- Common Food: Sphere
- HP Food: Sphere preferred, Box allowed if the food shape requires it
- Use simplified hitboxes only; do not rely on mesh collision for core gameplay

## 4.7 Anti-Hack / Validation Rules
- Server must reject hit if:
  + distance is invalid
  + velocity exceeds allowed threshold
  + cooldown has not expired
  + food no longer exists
  + food is not active
  + player is dead / invalid

### E) Collision Type Rules

#### 1) Player vs Common Food
- Common Food has `CanCollide = false`
- Client may predict overlap and hide the food locally for instant feedback
- Server verifies the hit and then:
  + destroy / despawn the food
  + award reward / exp
  + replicate state to all clients

#### 2) Player vs HP Food
- HP Food has `CanCollide = true`
- Server handles the real hit, HP reduction, and physics response
- On valid hit, server may apply a controlled `ApplyImpulse` to create a strong impact feel
- Client may only play visual feedback; it must not decide damage or destroy state

#### 3) Player vs Player
- `CanCollide = true`
- Server resolves the impact
- Use `ApplyImpulse` on the server to create a strong and controlled bounce / hit feeling
- Clamp impulse force to avoid unstable physics


# 5. SLING SYSTEM (CHARACTERS)

## 5.1 Core Stats
- MaxHP, BaseDamage, MoveSpeed, LaunchRange, ReflectDamage

## 5.2 Archetypes (Passive)
- CloneSling: Spawn clone (50% HP, 15s duration)
- SupportSling: Collision with ally → heal
- SplitSling: Split direction left/right on launch
- StunSling: Apply 1s stun on collision
- VacuumSling: Pull nearby Mini Food
- StealthSling: Invisible 1s before launch
- HealSling: Heal on launch
- SpeedSling: +5% speed per launch (stack)

## 5.2.1 SLING ABILITY SYSTEM
1. Trigger Type
- Each ability must define: OnLaunch, OnCollision, Passive

# 6. PROGRESSION & UPGRADE

## 6.1 Star Upgrade
- 3 identical Slings → +1★
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

---

# 10.4 FLAG SYSTEM (MODIFIERS)

## 10.4.1 Flag Types
- Ghost: Ignore collision, ignore damage
- Slow: Reduce movement speed
- Stun: Disable input and movement
- Freeze: Strong CC, disable move + rotate
- PoisonSpike: Damage over time
- Invisible: Hidden from enemy UI
- Recovering: Heal over time
- Invulnerable: Ignore incoming damage

## 10.4.2 Flag Properties
- Duration: Time the flag is active
- Stackable: Whether multiple stacks are allowed
- MaxStack: Maximum stack count (if applicable)

## 10.4.3 Flag Rules
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
- PoisonSpike:
  + Apply periodic damage
- Recovering:
  + Apply periodic healing

## 10.4.4 Priority Rule
- Freeze > Stun > Slow
- Hard CC overrides all movement-related states

---

# 10.5 STATE + FLAG RESOLUTION

## 10.5.1 Movement Rule
A player can move only if:

- State != Dead
- State != Charging
- State != Launching
- No active Stun
- No active Freeze

## 10.5.2 Final Behavior Pipeline
- State defines intent (what player is doing)
- Flag modifies or overrides behavior
- Final result is resolved on server

---

# 10.6 SESSION SYSTEM

## 10.6.1 Session States
- Lobby: Pre-game state
- Loading: Preparing player / map
- InGame: Active gameplay

## 10.6.2 Session Rules
- Lobby:
  + Players can interact but cannot deal damage
- Loading:
  + Disable spawn / interaction until ready
- InGame:
  + Full gameplay enabled

## 10.6.3 Flow
Lobby → Loading → InGame → Lobby

---

# 10.7 MAP / ROUND SYSTEM

## 10.7.1 Round States
- Lobby: No active round
- Awaits: Waiting for players or timer
- EarlyGame: Main gameplay phase
- FinalPhase: Endgame pressure phase
- RoundEnd: Round finished
- PostRound: Cleanup / transition

## 10.7.2 Rules
- PostRound is treated as Lobby at player/session level
- Round logic handled by Round Service (server authority)

---

# 10.8 PLAYER DATA & MAP BINDING

## 10.8.1 PlayerData
- LocationState: Lobby | Loading | InGame
- CurrentMap: nil or map reference

## 10.8.2 Join Map
- playerData.CurrentMap = map
- map.Players[player] = true
- playerData.LocationState = InGame

## 10.8.3 Leave Map
- Remove player from map.Players
- playerData.CurrentMap = nil
- playerData.LocationState = Lobby

---

# 10.9 DESIGN PRINCIPLES

- Server is authoritative for State and Flag
- Client only reads and renders
- Config contains data only (no logic)
- All behavior resolved via State + Flag pipeline
- Avoid conflicting logic between State and Flag

# 11. BUILD ORDER
1. Round System
2. Physics Core
3. Food System
4. Leveling System
5. Sling System
6. Environment (Safe Zone + Traps)
7. Meta (Economy + Lobby + UI)