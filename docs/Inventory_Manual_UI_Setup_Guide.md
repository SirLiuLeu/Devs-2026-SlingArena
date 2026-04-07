# Inventory + Sling UI Manual Setup Guide

This guide explains how to manually create required UI instances for inventory slots, hover behavior, and selection behavior without changing runtime architecture.

## 1) Slot Setup (Item + Sling)

Create slots from templates (recommended):
- `ReplicatedStorage/Assets/UI/ItemSlotTemplate` (Frame)
- `ReplicatedStorage/Assets/UI/SlingsSlotTemplate` (Frame)

Required children per slot:
- `UICorner`
- `Icon` (ImageLabel)
- `Name` (TextLabel)
- `Quantity` (TextLabel, item slot)
- Sling slot extras (if used by your style): `EquippedTag`, `Level`, `RarityStroke`

Target hierarchy:
- `StarterGui/InventoryUI/MainHub/BodyItems/GridContainer`
- `StarterGui/InventoryUI/MainHub/BodySling/GridContainer`

## 2) Hover Effect Setup

Use reusable handlers for all slots (do not duplicate logic per slot):
- Connect `MouseEnter`
- Connect `MouseLeave`
- On enter: brighten `BackgroundColor3`
- On leave: restore normal color if not selected

Implementation pattern:
- Track `isHovered` locally per slot
- Call one shared visual function (e.g. `applySlotVisual(slot, isHovered, isSelected)`)

## 3) Selected State Setup

Selection behavior rules:
- Click slot -> mark selected
- Selection style must be different from hover (stronger color and/or border)
- Keep one selection per list:
  - one selected item slot
  - one selected sling slot

Implementation pattern:
- Store `selectedItemId`
- Store `selectedSlingId`
- Re-apply visuals for all slots after selection change

## 4) Common Mistakes

- Missing event connections (`MouseEnter`, `MouseLeave`, click input)
- Hardcoded per-slot behavior instead of reusable handlers
- Not resetting previous selected slot visual
- Assuming optional panel instances always exist (add warn + safe fallback)
- Forgetting to refresh right panel when selected slot changes

## 5) Best Practices

- Keep inventory data logic in provider/service modules
- Keep UI rendering + interaction in controller modules
- Use one reusable slot visual function for normal/hover/selected states
- Keep sling equip/unequip as state changes first, then apply visual/model update
- Validate sling model before equip:
  - model exists
  - no Humanoid
  - has BasePart/PrimaryPart

## 6) Required Right Panel Bindings

Items panel should display:
- Name
- Icon
- Description
- Use button

Sling panel should display:
- Name
- Stats summary
- Equip button
- Unequip/Delete-active button

If any instance is missing, keep runtime alive and use `warn()`.
