# Manual Data Object Guide (Icons + Items)

This guide explains how to manually create and link icon assets with item data objects used by the inventory system.

## 1) Asset placement

Place icon images in Roblox Studio under:

```
ReplicatedStorage
  Assets
    Icons
      hp_potion
      gacha_ticket
      exp_buff_x2
```

Use image assets (Decal/ImageLabel sources) and store final `rbxassetid://...` IDs in `ItemConfig.lua`.

## 2) Naming convention

- Icon asset name should match the data `id` exactly when possible.
- Keep lowercase snake_case IDs for consistency.

Examples:
- `hp_potion`
- `gacha_ticket`
- `exp_buff_x2`

## 3) How linking works (DataConfig ↔ Asset)

Linking is done by the `icon` field in `src/ReplicatedStorage/Shared/Config/ItemConfig.lua`.

- Data side: `id = "hp_potion"`
- Asset side: matching image ID in `icon`
- UI side: `InventoryUIController` reads `itemDef.icon` and assigns it to slot `Icon.Image`

## 4) Example DataConfig entries

```lua
{
    id = "hp_potion",
    name = "HP Potion",
    effect = "Restores HP over 5 seconds; interrupted when damaged.",
    icon = "rbxassetid://10000001",
    stackable = true,
},
{
    id = "gacha_ticket",
    name = "Gacha Ticket",
    effect = "Used to roll random sling and item rewards.",
    icon = "rbxassetid://10000003",
    stackable = true,
},
{
    id = "exp_buff_x2",
    name = "x2 EXP Buff",
    effect = "Doubles EXP gain for a limited duration.",
    icon = "rbxassetid://10000002",
    stackable = true,
},
```

## 5) Common mistakes

- Wrong path: creating icons outside `ReplicatedStorage/Assets/Icons`.
- Missing asset ID: `icon` left empty or invalid.
- ID mismatch: config `id` does not match intended icon naming.
- Typo in `rbxassetid://` string format.

## 6) Best practices

- Keep icons lightweight (small resolution, compressed).
- Reuse icon assets when visuals are identical.
- Keep one source-of-truth in `ItemConfig.lua` for item-to-icon mapping.
- Test with Inventory UI to confirm image loads and no missing entries warnings.
