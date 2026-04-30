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
   Players stay in the lobby map
   Can open UI (Shop, Inventory, Spin)
   Players can join the Arena Map
   After leaving the Arena, there is a 15-second cooldown before rejoining

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

6. PostRound (Reset)
   Reset the game state for the next round
Reset: Map, Food, Player state
Teleport back to Lobby

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
-  Common Food (Touch): Common
  + Disappears on contact
  + Grants EXP + heals HP
  + Each destroyed Food → respawn exactly 1 after 10s

- HP Food (Must Hit): Uncommon, Rare, Epic, Legendary, Mythic, Unique
  + Requires attack (last hit)
  + Grants EXP + chance for Diamonds
  + Each destroyed Food → respawn exactly 1 after 30s
  + Each destroyed "Unique" Food → respawn exactly 1 after 90s

## 3.4 Maintenance
- No overlap within same cluster
- Rate Spawn:
+ MidZones: Common (20%), Uncommon(20%), Rare (20%), Epic (20%), Legendary(10%), Mythic (10%)
+ EdgeZones: Common (40%), Uncommon(30%), Rare(30%)
+ CenterZones: Unique (20%), Mythic(80%)

## 3.5 Collision Math (Player/Sling vs Food)
- Collision is calculated on the Server only.
- Do not use client touch events as source of truth.
- task.wait(0.1) -- 10 lần/giây là đủ

### A) Basic Distance Check
- Let:
  + P = Player root position
  + F = Food position
  + rP = Player collision radius
  + rF = Food collision radius

- Distance formula:
  + d = sqrt((Px - Fx)^2 + (Py - Fy)^2 + (Pz - Fz)^2)

- Collision condition:
  + d <= (rP + rF)

### B) Horizontal Check (recommended for ground-based food)
- Use XZ plane distance to ignore small Y offset:
  + dXZ = sqrt((Px - Fx)^2 + (Pz - Fz)^2)

- Optional vertical tolerance:
  + |Py - Fy| <= YTolerance

- Collision condition:
  + dXZ <= (rP + rF)
  + AND |Py - Fy| <= YTolerance

### C) Fast Movement / Sling Check (segment check, chỉ dùng khi Launch)
- To avoid missing collision when Player moves too fast, check the shortest distance from Food to the movement segment:
  + A = previous player position
  + B = current player position
  + F = Food position

- Compute:
  + t = clamp(((F - A) · (B - A)) / |B - A|^2, 0, 1)
  + ClosestPoint = A + t * (B - A)
  + d = |F - ClosestPoint|

- Collision condition:
  + d <= (rP + rF)

### D) Server Validation
- Server must verify:
  + food exists
  + food is active
  + player is alive
  + distance check passes
  + cooldown / anti-spam passes

### E) Despawn / Eat Rules
- Common Food:
  + On collision, destroy on Server
  + Respawn exactly 1 after 10s

- HP Food:
  + On valid hit, destroy on Server
  + Respawn exactly 1 after 30s
  + Unique respawn after 90s

# 4. PHYSICS & COMBAT

## 4.1 Formula
- ImpactDamage = BaseDamage × CollisionSpeedMultiplier
- Size = BaseSize × (1 + sqrt(Level) × 0.08)
- RequiredEXP = BaseEXP × (Level ^ 1.3)

## 4.2 Combat Flow
- Move → Charge → Launch → Move → Collision → Damage + Knockback
- Physics: Gravity, Mass, Friction, Inertia, Knockback
- Prevent multi-hit spam in single contact
## 4.3 Collision
- Collision  must be math-based, not physics-event-based. Server handles logic, client only renders visuals
- Use sphere check: dist <= (r1 + r2)
- Ignore .Touched for core logic
- Run in server loop (Heartbeat / interval)
- Only valid if:Not Ghost, Speed > threshold, In active state (Launch/Move)

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

# 10. BUILD ORDER
1. Round System
2. Physics Core
3. Food System
4. Leveling System
5. Sling System
6. Environment (Safe Zone + Traps)
7. Meta (Economy + Lobby + UI)