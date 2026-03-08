# Food Spawn Developer Guide

## 1) How food spawn works

Food spawning is **event-driven**:

1. Map loads -> server builds a fixed set of spawn cells and spawns one food per selected cell.
2. Food stays in place until a valid player pawn touches it.
3. On consume, the food instance is destroyed.
4. A delayed respawn spawns a replacement **only for that consumed cell**.

This prevents continuous cloning loops and keeps total food stable.

## 2) How grid cells are calculated

When `FoodSpawns/FoodSpawn` anchors are not provided, the server generates a grid from map bounds:

- Uses `ArenaBounds` (or `Bounds`) part of the map.
- Cell count by axis:
  - `xCellCount = floor(boundsSize.X / FoodGridCellSize)`
  - `zCellCount = floor(boundsSize.Z / FoodGridCellSize)`
  - each axis is clamped to at least 1
- Cell centers are distributed uniformly across bounds and converted to world positions.

If map creators provide `FoodSpawns/FoodSpawn` parts, those anchors are used as cell positions.

## 3) How to configure spawn density

Use `ReplicatedStorage/Shared/Config/BalanceConfig.lua`:

- `FoodSpawnCountPerMap`: target number of spawned food instances per map.
- `FoodGridCellSize`: smaller value = denser candidate grid.
- `FoodRespawnDelay`: delay before respawning consumed food.

Notes:

- If `FoodSpawnCountPerMap` is less than available cells, the system picks evenly spaced cells.
- If it is greater than available cells, all available cells are used.

## 4) How floor alignment works

Food floor placement uses downward raycast:

- Ray origin: spawn position + Y offset.
- Ray direction: straight downward.
- Filter: current map model only.
- Spawn Y = `rayHitY + foodHalfHeight`.

Fallback behavior when raycast misses:

- Spawn Y uses map pivot height + food half-height.

This ensures food rests on floor surfaces instead of floating.

## 5) How map creators should position food spawn zones

Recommended setup per map model:

- `FoodContainer` (Folder): runtime food instances parent here.
- `FoodSpawns` (Folder) with `FoodSpawn` parts for handcrafted placement (optional but recommended).
- `ArenaBounds` or `Bounds` (Part): required for automatic grid generation fallback.

Best practices:

- Spread `FoodSpawn` anchors across full playable area.
- Keep anchors above visible floor so raycast can resolve correct floor height.
- Avoid placing anchors in blocked geometry or inaccessible regions.
