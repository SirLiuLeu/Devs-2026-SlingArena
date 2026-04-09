A. Map
1. World Spec
Arena:
- size: 1000x1000 studs
- boundary: wall
- Shape: square arena

Entities:
- food: 100, food respawn: 10s
- traps: 10
- players: 12

Spawn points:
- Players: random near edge
- Food: distributed across map
- Traps: fixed positions

B. Food
FOOD SPAWN SYSTEM SPEC

This document defines the authoritative rules for the Food Spawn System. Implementation must follow these rules.

1. FoodSpawn Parts
- Spawn centers are Parts located in: Workspace/FoodSpawns
- Each Part is named "FoodSpawn".
- Each FoodSpawn acts as a center point for spawning foods.

2. Spawn Radius
- Foods spawn randomly around the FoodSpawn position.
- Radius: ±5 studs on X and Z.
Example:
spawnPos = FoodSpawn.Position + Vector3.new(random(-5,5), 0, random(-5,5))

3. Spawn Count
- Each FoodSpawn maintains exactly 5 active foods.
- Foods must spawn at random positions within the radius and should not overlap.
- Each FoodSpawn manages its own food instances.

4. Food Types
There are 7 food types:
Food1, Food2, Food3, Food4, Food5, Food6, Food7

Each type has different:
- EXP reward
- HP value

5. Food Respawn
- When a food is consumed or destroyed:
  - The instance is removed.
  - It respawns after 10 seconds.
- Respawn position must remain within the same FoodSpawn radius.

6. Spawn Zones
FoodSpawn parts belong to one of three zones which determine allowed food types.

Edge Zone:
Food5, Food6, Food7

Middle Zone:
Food2, Food3, Food4, Food5, Food6, Food7

Center Zone:
Food1, Food2, Food3, Food4

7. Zone Assignment
Each FoodSpawn part must define an Attribute:
Zone = "Edge" | "Middle" | "Center"

The spawn system reads this attribute to determine which food types can spawn.

8. Reliability Rules
- Each FoodSpawn must always maintain 5 foods.
- If a food is destroyed, only that food respawns after 10s.
- Fix issues where only one food is cloned or spawning fails.

9. Placement Guide
- Place FoodSpawn parts on the ground.
- Minimum distance between FoodSpawns: 15 studs.
- Avoid placing near walls.
- Distribute zones across the arena:
  Center (low-tier foods), Middle (mixed foods), Edge (high-tier foods).

C. Game Core Loop (Team Control Mode)**

### Arena Mode
* Mode: 2 Teams (Sling vs Sling)
* Objective: Control Center Zone to gain points
* Win Condition:
  * First team reaches **1000 points**
  * Or match ends when one team dominates
* Match Duration: ~10–15 minutes

---

### Zones

**Center Zone:**
* Capture Rule:
  * Team with more players enters **capture state**
  * After **5s → zone captured → +1 point/sec**
* Effects:
  * Enter → **Invincible 3s**
  * Gain **Rage Buff (1 min, persists outside)**
* Hazards:
  * Air Blower (push players away)
  * Lava pits (instant death)
* Events:
  * Every **90s → spawn Chest (5 diamonds, last hit)**
---
**Outer Zone:**
* Purpose: Farming & recovery
* Contains:
  * High-density food → fast EXP + heal
  * Mini Robots:
    * Slow movement, attackable
    * Reward: **2 diamonds**
  * Large Food (rare):

    * Chance: **+1 diamond**
---

### Combat Rules

* Collision:
  * Apply **stun: 2s**
* Release:
  * Apply **knockback + stun**
  * Enemy: **damage**
  * Ally: **no damage (only CC)**
* Cooldown:
  * Trigger immediately after release

---

### Respawn System

* Each team has:
  * Dedicated spawn zone
* On death:
  * Respawn at base
  * Full heal inside base
* Protection:
  * **30s spawn protection**
  * Removed when entering Center Zone

---

### Reward System
* Kill / Lava push:
  * **Diamonds + EXP**
* Assist:
  * **EXP + 1 diamond**
* Match End:
  * Win: **10–15 diamonds**
  * Lose: **5–10 diamonds**
---
### Core Loop Flow

1. Spawn → Farm (Outer Zone)
2. Move to Center → Fight
3. Capture → Gain Points
4. Contest:
   * Center (main objective)
   * Outer (resources & mini objectives)
5. Repeat until win condition reached
---
### Design Intent
* Clear objective: **Control Center**
* Risk vs Reward:
  * Center = High risk, fast win
  * Outer = Safe farm
* Encourage:
  * Team play
  * Positioning
  * Physics-based combat
