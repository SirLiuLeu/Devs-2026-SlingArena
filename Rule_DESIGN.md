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
- Defined via full state transitions and flow

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
- Container: Workspace/Maps/ArenaMap/FoodSpawns
- Naming: "FoodSpawn"
- Attribute: Zone = Edge | Middle | Center

## 3.2 Spawn Rule
- Radius: ±5 studs (X, Z)
- Formula: spawnPos = FoodSpawn.Position + Vector3.new(random(-5,5), 0, random(-5,5))
- Density: 1 FoodSpawn = 5 Food active, Thiếu → respawn sau 10s

## 3.3 Food Zones
-  Normal Food (Touch):
  + Disappears on contact
  + Grants EXP + heals HP

- HP Food (Must Hit):
  + Requires attack (last hit)
  + Grants EXP + chance for Diamonds

## 3.4 Maintenance
- Each destroyed Food → respawn exactly 1 after 10s
- No overlap within same cluster

# 4. PHYSICS & COMBAT

## 4.1 Formula
- ImpactDamage = BaseDamage × CollisionSpeedMultiplier
- Size = BaseSize × (1 + sqrt(Level) × 0.08)
- RequiredEXP = BaseEXP × (Level ^ 1.3)

## 4.2 Combat Flow
- Move → Charge → Launch → Move → Collision → Damage + Knockback
Physics: Gravity, Mass, Friction, Inertia, Knockback

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
- Shared Win: Highest rank of one applies to both
- Assist Reward:
  + Assist kill (Player or HP Food)
  + Gain +50% EXP and Diamonds
- Off-screen teammate:
  + Show direction marker (Arrow)
- Show real distance between teammates

# 8. ENVIRONMENT & SAFE ZONE

## 8.1 Safe Zone
- Shrinks over time → force combat

Outside:
- Lose % HP per second
- Damage increases over time (1%/s → 10%/s)


## 8.2 Traps
- Lava: Death after 3s
- Toxic Smoke / Fire: Damage over time
- Spike: Damage + Knockback
- Totem: Shoots projectiles to push players

# 9. ECONOMY & PROGRESSION

## 9.1 Income
- Kill:
  + Diamonds
  + EXP = 50% of target’s lost EXP
- Others: Chest, Event, Daily, Robux

## 9.2 VIP
- Price: 1000 Diamonds / 7 days
- Buff: +20% EXP from Food

# 10. BUILD ORDER
1. Round System
2. Physics Core
3. Food System
4. Leveling System
5. Sling System
6. Environment (Safe Zone + Traps)
7. Meta (Economy + Lobby + UI)