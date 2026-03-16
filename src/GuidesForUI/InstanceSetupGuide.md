# Instance Setup Guide

This guide defines the required Roblox Instances for gameplay spawning so `MapService`, `FoodService`, and `PlayerService` can run without runtime path failures.

## 1) Where to place map models

### Primary runtime map root
Create all playable maps under:

- `Workspace/Maps` *(Folder)*

Required map models:

- `Workspace/Maps/LobbyMap` *(Model)*
- `Workspace/Maps/Arena_01` *(Model)*
- `Workspace/Maps/Arena_02` *(Model)*

## 2) Where food templates must be stored

### Preferred location
- `ServerStorage/FoodTemplates` *(Folder)*
  - Add one or more food models, e.g.:
    - `AppleFood` *(Model)*
    - `MeatFood` *(Model)*
    - `BerryFood` *(Model)*

### Supported fallback locations
- `ServerStorage/Food` *(Model)*
- `ReplicatedStorage/Prefabs/Food` *(Model)*
- `ReplicatedStorage/Assets/Food/BasicFood` *(Model)*

---

## 3) Where trap templates must be stored

### Preferred location
- `ServerStorage/TrapTemplates` *(Folder)*
  - Add one or more trap models, e.g.:
    - `SpikeTrap` *(Model)*
    - `MineTrap` *(Model)*

### Supported fallback locations
- `ReplicatedStorage/Prefabs/Trap` *(Model)*
- `ReplicatedStorage/Assets/Trap/BasicTrap` *(Model)*

---

## 4) How MapService clones these objects

### Map activation flow
1. `MapService:ActivateMap(mapName)` toggles map visibility/collision.
2. `MapService:Generate()` collects gates, traps, spawn points, and zone parts.
3. `MapService:_spawnMapFoodAndTraps(mapName)` performs spawn operations.

### Food clone flow
- Arena maps (`Arena_01`, `Arena_02`, or any map name containing `Arena`): cloned into `[MapModel]/FoodContainer`.
- Lobby map (`LobbyMap`): no food or trap spawning is executed.
- Source templates:
  1. `ServerStorage/FoodTemplates/*`
  2. fallback chain listed above.
- Positioning:
  - If `[MapModel]/FoodSpawns/FoodSpawn_*` exists, food clones use these anchor points.
  - Otherwise random map-relative positions are used.

### Trap runtime flow
- Traps are fixed map content (not runtime-cloned).
- Expected path: `Workspace/ArenaMap/Traps/*`.
- TrapService iterates all children under `Traps` and treats every `BasePart` descendant as collidable trap geometry.

---

## 5) Required folders inside each map

## Minimum required per playable map (`ForestMap`, `DesertMap`)

- `SpawnPoints` *(Folder)*
  - Contains one or more `Part` spawn positions.
- `FoodContainer` *(Folder)*
  - Runtime parent for spawned food models.
- `Traps` *(Folder)*
  - Manual trap placement folder.
  - Contains `Trap_01..N` as `Part` or `Model`.

## Recommended for deterministic placement

- `FoodSpawns` *(Folder)*
  - `FoodSpawn_01..N` *(Part)*

## Optional but used by map/round logic

- `WallContainer` *(Folder)* for collidable map walls.
- `Gate` *(Part)*, `ExitZone` *(Part)*.
- `AntiGiantZone` *(Part)*, `SafeSpawnZone` *(Part)*, `SizeRestrictedCorridor` *(Part)*.

---

## Lobby and player spawn requirements

- `Workspace/Maps/LobbyMap/SpawnPoints/LobbySpawn` *(Part)* for lobby teleports.
- `LobbyMap` should contain at least one descendant part named `SpawnPoint`.
- `Workspace/SlingPawns` *(Folder)* is auto-created by `PlayerService` if missing.

---

## Quick checklist

- [ ] `Workspace/Maps` exists with required map models.
- [ ] Arena map has `SpawnPoints`, `FoodContainer`, and `Traps`.
- [ ] `ServerStorage/FoodTemplates` has at least one food model.
- [ ] `ReplicatedStorage/Assets/SlingModel` exists and has valid root part.
