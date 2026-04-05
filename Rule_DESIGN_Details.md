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