# Food Spawn Placement Guide (Level Designers)

## Required structure
For each map, place spawn centers at:

- `Workspace/Maps/<MapName>/FoodSpawns/`
- Each center must be a `BasePart` named **`FoodSpawn`**.

The runtime system uses every `FoodSpawn` as a food center and maintains **5 active foods per center**.

## Placement rules
- Place each `FoodSpawn` part on the ground.
- Keep at least **15 studs** between `FoodSpawn` parts.
- Avoid placing `FoodSpawn` parts near walls or map boundaries.
- Distribute `FoodSpawn` parts evenly across the arena.

## Zone setup (recommended)
Each `FoodSpawn` can define an attribute:

- `Zone = "Center" | "Middle" | "Edge"`

Allowed food types by zone:
- Center: `Food1`, `Food2`, `Food3`, `Food4`
- Middle: `Food2`, `Food3`, `Food4`, `Food5`, `Food6`, `Food7`
- Edge: `Food5`, `Food6`, `Food7`

If no `Zone` attribute is provided, the server auto-assigns zone by distance from map center.

## Spawn behavior summary
- Foods spawn randomly around the center within **±5 studs (X/Z)**.
- Spawn positions are randomized and attempt to avoid overlap.
- When one food is consumed, only that food respawns after **10 seconds**.
- Respawns always stay within the same `FoodSpawn` center radius.
