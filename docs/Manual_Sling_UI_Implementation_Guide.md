# Sling Arena – Manual UI Implementation Guide (Roblox Studio)

This guide explains how to **manually build** a clean and scalable Sling UI stack in Roblox Studio for multiplayer usage.

> Scope covered:
> 1) World UI above each Sling (HP + Level)  
> 2) Level-up + Stat Point flow (conceptual integration)  
> 3) Sling size design rules  
> 4) Main Stats Popup (allocation UI)  
> 5) Dropdown/toggle behavior and recommended animation pattern

---

## 0) Prerequisites and constraints

- Build all UI manually in Studio (Explorer + Properties).
- Do **not** auto-generate ScreenGui trees via runtime code.
- Keep UI and gameplay/server logic separated:
  - UI = display + local interaction state.
  - Server = authoritative values (stats, level, HP, upgrade validation).
- Use existing architecture and remotes from this project:
  - `ReplicatedStorage.SlingArenaRemotes.StateUpdate`
  - `ReplicatedStorage.SlingArenaRemotes.UIStateUpdate`
  - `ReplicatedStorage.SlingArenaRemotes.AttributeUpgrade`

**INFERRED:** stat values are synchronized primarily through authoritative server updates and consumed by LocalScripts for display refresh.

---

## 1) Naming convention (required)

Use this naming format consistently:

- **ScreenGui:** `<Feature>NameUI` (example: `SlingStatsUI`)
- **Top-level frames:** `<Feature>Root`, `<Feature>Panel`
- **Rows:** `<Attribute>NameRow` (example: `HPRow`, `MoveSpeedRow`)
- **Buttons:** `<Action>Button` (example: `AcceptButton`, `ResetButton`)
- **Text labels:** `<Meaning>Label` (example: `CurrentValueLabel`)
- **Bars/fills:** `<Meaning>Bar`, `<Meaning>Fill`

Avoid generic names like `Frame1`, `TextButton2`, `Label3`.

---

## 2) Full UI hierarchy tree

## 2.1 World UI (Billboard on each Sling)

```text
Workspace
└── Runtime
    └── SlingPawns
        └── <SlingPawnModel>
            ├── <AttachmentPart>                          -- INFERRED: Head/Root/Top part
            │   └── SlingWorldBillboard (BillboardGui)
            │       └── WorldUiRoot (Frame)
            │           ├── LevelBadge (Frame)
            │           │   └── LevelLabel (TextLabel)
            │           └── HPBarContainer (Frame)
            │               ├── HPBarBackground (Frame)
            │               ├── HPBarFill (Frame)
            │               └── HPValueLabel (TextLabel)  -- optional (can hide at distance)
            └── ...
```

## 2.2 Main Stats Popup UI

```text
StarterGui
└── SlingStatsUI (ScreenGui)
    └── StatsRoot (Frame)
        ├── HeaderBar (Frame)
        │   ├── TitleLabel (TextLabel)
        │   ├── AvailablePointsLabel (TextLabel)
        │   └── ToggleDropdownButton (TextButton)
        ├── BodyContainer (Frame)
        │   ├── AttributeList (Frame)
        │   │   ├── UIListLayout
        │   │   ├── HPRow (Frame)
        │   │   ├── BaseDamageRow (Frame)
        │   │   ├── RegenRateRow (Frame)
        │   │   ├── ReflectDamageRow (Frame)
        │   │   ├── LaunchSpeedRow (Frame)
        │   │   ├── LaunchRangeRow (Frame)
        │   │   ├── ChargeSpeedRow (Frame)
        │   │   └── MoveSpeedRow (Frame)
        │   └── ActionButtonsRow (Frame)
        │       ├── ResetButton (TextButton)
        │       └── AcceptButton (TextButton)
        └── FooterExpBar (Frame)
            ├── ExpBarBackground (Frame)
            ├── ExpBarFill (Frame)
            ├── ExpValueLabel (TextLabel)    -- e.g. 770 / 1200
            └── LevelOnBarLabel (TextLabel)  -- e.g. LV 12
```

## 2.3 Attribute row template structure

```text
<Attribute>Row (Frame)
├── AttributeNameLabel (TextLabel)
├── CurrentValueLabel (TextLabel)
├── AllocatedPointsLabel (TextLabel)   -- e.g. +5
├── DecreaseButton (TextButton)         -- "-"
└── IncreaseButton (TextButton)         -- "+"
```

---

## 3) Step-by-step creation guide (manual in Studio)

## Step 1 – Create the Stats ScreenGui

1. In `StarterGui`, insert `ScreenGui` named `SlingStatsUI`.
2. Set properties:
   - `ResetOnSpawn = false`
   - `IgnoreGuiInset = true`
   - `DisplayOrder` high enough to appear above regular HUD.
3. Insert `Frame` named `StatsRoot`.
4. Recommended `StatsRoot` properties:
   - `AnchorPoint = (0.5, 0.5)`
   - `Position = UDim2.fromScale(0.5, 0.55)`
   - `Size = UDim2.fromScale(0.36, 0.62)`
   - `BackgroundTransparency` around `0.1` to `0.2`.
5. Add `UICorner` and `UIPadding` for clean panel layout.

## Step 2 – Build header + dropdown trigger

1. Under `StatsRoot`, insert `HeaderBar` (`Frame`).
2. Add:
   - `TitleLabel` (`TextLabel`) → text: `Sling Attributes`
   - `AvailablePointsLabel` (`TextLabel`) → text example: `Points: 3`
   - `ToggleDropdownButton` (`TextButton`) → text: `▲` (open) / `▼` (closed)
3. Use `UIListLayout` or manual anchors so header elements remain aligned in different resolutions.

## Step 3 – Build BodyContainer and attribute list

1. Insert `BodyContainer` (`Frame`) under `StatsRoot`.
2. Inside `BodyContainer`, insert `AttributeList` (`ScrollingFrame`).
3. Insert `UIListLayout` inside `AttributeList`.
4. Create 8 rows with exact names:
   - `HPRow`
   - `BaseDamageRow`
   - `RegenRateRow`
   - `ReflectDamageRow`
   - `LaunchSpeedRow`
   - `LaunchRangeRow`
   - `ChargeSpeedRow`
   - `MoveSpeedRow`
5. For each row, create 5 controls:
   - `AttributeNameLabel`
   - `CurrentValueLabel`
   - `AllocatedPointsLabel`
   - `IncreaseButton`
   - `DecreaseButton`
6. Row behavior intention:
   - `IncreaseButton`: assign 1 pending point to this attribute.
   - `DecreaseButton`: remove 1 pending point from this attribute.
   - `AllocatedPointsLabel`: local pending value (example `+0`, `+2`, `+5`).

## Step 4 – Add action buttons

1. Under `BodyContainer`, create `ActionButtonsRow`.
2. Add two `TextButton`s:
   - `ResetButton`
   - `AcceptButton`
3. Intended behavior:
   - `ResetButton`: clear pending allocations (UI-only reset until confirmed).
   - `AcceptButton`: submit current pending allocations for server validation/commit.

## Step 5 – Build footer EXP bar

1. Under `StatsRoot`, add `FooterExpBar` (`Frame`).
2. Create:
   - `ExpBarBackground` (`Frame`)
   - `ExpBarFill` (`Frame`) anchored left, width updated by exp ratio
   - `ExpValueLabel` (`TextLabel`) with format `currentExp / requiredExp`
   - `LevelOnBarLabel` (`TextLabel`) centered on bar, format `LV <n>`
3. Example display:
   - `ExpValueLabel`: `770 / 1200`
   - `LevelOnBarLabel`: `LV 12`

## Step 6 – Create World Billboard UI above Sling

1. In a Sling pawn template/model, choose the part that should carry world UI.
   - **ASSUMED safe default:** top/center body part.
2. Insert `BillboardGui` named `SlingWorldBillboard`.
3. Set Billboard properties:
   - `AlwaysOnTop = true`
   - `Size = UDim2.fromOffset(180, 56)` (start point)
   - `StudsOffset = Vector3.new(0, 4.5, 0)` (adjust per Sling size tier)
   - `MaxDistance = 180` to `250`
   - `LightInfluence = 0` for readability
4. Build children under billboard:
   - `WorldUiRoot`
   - `LevelBadge` + `LevelLabel`
   - `HPBarContainer` + `HPBarBackground` + `HPBarFill`
5. Notes:
   - BillboardGui automatically faces camera.
   - Keep widget compact to reduce clutter in multiplayer.

## Step 7 – Connect conceptual data flow (no heavy backend code)

Use this ownership model:

- **Server authoritative:** Level, EXP, HP, base stats, available points, accepted allocations.
- **Client UI state:** currently opened/closed dropdown state, pending unsent allocations.

Recommended event flow:

1. Player presses `+` / `-` on a row → local pending allocation changes.
2. UI recalculates preview values and remaining points display.
3. Player presses `AcceptButton` → request server upgrade action(s).
4. Server validates limits/caps/available points and applies real state.
5. Server publishes updated state to client (`StateUpdate`/`UIStateUpdate`) and UI refreshes.

---

## 4) Level system + stat points (design integration)

- Each level-up grants exactly **+1 Stat Point**.
- Stat points should affect stats using **percentage-based multipliers** rather than flat unlimited addition.
- Display model in UI:
  - `CurrentValueLabel` shows current effective stat.
  - `AllocatedPointsLabel` shows pending additions.
  - `AvailablePointsLabel` shows unspent points.

Recommended messaging in UI:
- If no available points, disable `IncreaseButton` on all rows.
- If attribute at cap, disable `IncreaseButton` for that row only.

---

## 5) Sling size design rules (non-code guideline)

Use normalized size tiers for balance + readability.

| Tier | Suggested visual scale (relative to base) | Gameplay intent | UI offset hint |
|---|---:|---|---|
| Small | 0.85x – 1.00x | Agile, easier escape, lower visual obstruction | Billboard `StudsOffset.Y` ~ 3.8–4.3 |
| Medium | 1.01x – 1.35x | Baseline combat readability and fair collisions | `StudsOffset.Y` ~ 4.4–5.0 |
| Large | 1.36x – 1.90x | Power presence with counterplay limits | `StudsOffset.Y` ~ 5.1–6.2 |

Guideline rules:
1. Keep growth readable but not screen-blocking.
2. Increase billboard Y-offset with Sling size tier.
3. Keep HP bar width visually consistent in screen space; avoid giant bar inflation.
4. Test with 8–12 players visible to ensure labels remain readable.

---

## 6) Dropdown/Toggle behavior for Stats UI

## 6.1 Structure

- `StatsRoot` remains the panel parent.
- `HeaderBar` always visible.
- `BodyContainer` and `FooterExpBar` are collapsed/expanded.

## 6.2 Animation approach (TweenService concept)

Recommended collapse animation:

- Expanded state:
  - `StatsRoot.Size = ExpandedSize`
  - `BodyContainer.Visible = true`
  - `FooterExpBar.Visible = true`
- Collapsed state:
  - tween `StatsRoot.Size` to smaller height
  - fade/clip body contents during tween
  - set body/footer invisible at animation end

Recommended tween profile:
- Duration: `0.18` to `0.28` seconds
- Easing: `Quad` or `Cubic`, `Out`
- Keep one tween instance per panel transition to avoid overlap.

---

## 7) Best practices checklist

1. **Scaling:** prefer `UDim2.fromScale` for macro layout and offsets for paddings.
2. **AnchorPoint discipline:** center major popups with `(0.5, 0.5)`.
3. **Template reuse:** build one clean attribute row template, then duplicate + rename.
4. **Separation of concerns:** no gameplay authority inside UI scripts.
5. **State sync:** only trust server-pushed values for final stats/HP/level.
6. **Multiplayer readability:** reduce text density in world-space labels.
7. **Device testing:** validate at least desktop + mobile aspect ratios.

---

## 8) Common mistakes to avoid

1. **Misaligned BillboardGui**
   - Cause: wrong `StudsOffset` or wrong parent part.
   - Fix: attach to consistent top-center attachment part and tune per size tier.

2. **Hardcoded fixed pixel layouts everywhere**
   - Cause: only offset-based sizes.
   - Fix: use scale-based layout + padding offsets.

3. **Mixing UI and combat logic**
   - Cause: client deciding final damage/stat values.
   - Fix: client sends intent, server validates and returns authoritative state.

4. **Unclear row naming**
   - Cause: duplicate rows named `Frame` or `Row`.
   - Fix: enforce `<Attribute>Row` naming strictly.

5. **No cap/points feedback**
   - Cause: `+` still active when points are zero or stat is maxed.
   - Fix: disabled button style + tooltip/state label.

---

## 9) Quick implementation order (recommended)

1. Build `SlingStatsUI` skeleton (header/body/footer).
2. Build one perfect attribute row template.
3. Duplicate template into 8 required attributes and rename correctly.
4. Add reset/accept buttons and disabled-state styles.
5. Add EXP bar with on-bar level label.
6. Add dropdown/toggle behavior for panel open/close.
7. Build world `SlingWorldBillboard` (level + HP).
8. Connect UI to authoritative state updates and validate in multiplayer test.

This order reduces rework and keeps structure scalable.
