# Trap Setup Developer Guide (Manual Placement)

Use this guide to create **fixed, permanent traps** for Sling Arena.

## Required hierarchy

Create traps under this exact path:

- `Workspace`
  - `ArenaMap` (Model)
    - `Traps` (Folder)
      - `Trap_01` (Part or Model)
      - `Trap_02` (Part or Model)
      - `Trap_03` (Part or Model)

The runtime reads traps from `Workspace.ArenaMap.Traps`.

## Naming rules

- Trap folder name must be exactly: `Traps`
- Each trap child should use a stable name such as:
  - `Trap_01`
  - `Trap_02`
  - `Trap_03`
- Do not hardcode names in code; the service iterates every child under `Traps`.

## Required trap properties

Each trap can be either:

1. **Part**
   - `Anchored = true`
   - `CanCollide = true`
   - Positioned where players can collide with it

2. **Model**
   - Must contain at least one `BasePart`
   - All physical hit parts should have:
     - `Anchored = true`
     - `CanCollide = true`

## Runtime behavior

- When a Sling touches a trap:
  - trap damage and pushback are applied
- Traps are **not destroyed** on collision
- Traps remain active permanently while server runs

## Example Studio tree

```text
Workspace
 └─ ArenaMap (Model)
    └─ Traps (Folder)
       ├─ Trap_01 (Part)
       ├─ Trap_02 (Part)
       └─ Trap_03 (Model)
          └─ Hitbox (Part)
```
