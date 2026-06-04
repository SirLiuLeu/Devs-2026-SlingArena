# Food Spawn Placement Guide (Level Designers)

## Required structure
For each arena map, place spawn centers under zone folders at:

- `Workspace/Maps/<MapName>/FoodSpawns/CenterZones/`
- `Workspace/Maps/<MapName>/FoodSpawns/MidZones/`
- `Workspace/Maps/<MapName>/FoodSpawns/EdgeZones/`

Each center must be a `BasePart` named **`FoodSpawn`** or another descriptive `BasePart` name.

The runtime system uses the zone folder name, `FoodConfig.ZoneWeights`, and `FoodConfig.ZoneRules` to choose valid food rarity pools for that area.

## Placement rules
- Place each `FoodSpawn` part on the ground.
- Keep enough spacing between `FoodSpawn` parts for each zone's scatter radius and food hitbox size.
- Avoid placing `FoodSpawn` parts near walls or map boundaries.
- Distribute `FoodSpawn` parts evenly across the arena.

## Zone behavior summary
- `CenterZones`: each `FoodSpawn` creates exactly **1 active food** at the exact spawn position.
- `MidZones`: each `FoodSpawn` creates up to **10 active foods** within a **20-stud radius**.
- `EdgeZones`: each `FoodSpawn` creates up to **10 active foods** within a **20-stud radius**.
- Spawn positions are validated against existing food hitboxes and the configured no-overlap spacing before placement.
- If a valid non-overlapping position cannot be found within the bounded retry limit, the server skips that food and warns instead of forcing an unsafe overlap.
- When one food is consumed, only that food respawns after its configured respawn time and stays in the same zone/spawn center rules.
