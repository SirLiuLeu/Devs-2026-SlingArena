# SlingUI Developer Guide

## 1. SlingUI runtime flow

1. Player presses on their Sling pawn in the world.
2. `SlingUI.client.lua` validates the input hit, resolves `StarterGui.SlingArenaUI.SlingUI` once, marks the local state as charging, and fires `StartCharge`.
3. A controlled `RenderStepped` loop starts **only while charging or cooldown is active**.
4. While the player holds input:
   - `ChargeBar.Fill.Size` grows from `0` to `1` on the X scale.
   - `JoystickRoot.Thumb` follows the drag delta.
   - `DirectionIndicator` rotates from the current drag vector.
5. On release, the client fires `ReleaseCharge`, hides the joystick, and starts a local cooldown timer for the same recover duration used by the server.
6. During cooldown, `CooldownBar.Fill.Size` grows from `0` to `1` on the X scale.
7. When cooldown completes, the update loop disconnects itself and the player can charge again.

## 2. Anti-spam logging behavior

- The runtime no longer logs inside the per-frame update path.
- UI resolution is cached and printed exactly once when the hierarchy is first resolved.
- Missing UI hierarchy still produces a `warn()` exactly once so gameplay does not crash.
- If the UI appears later, the script re-resolves it safely without re-spamming warnings.

## 3. Required Studio hierarchy

- Required hierarchy:
  - `StarterGui`
    - `SlingArenaUI` (`Folder`)
      - `SlingUI` (`ScreenGui`)
        - `JoystickRoot` (`Frame`)
          - `Base` (`Frame`)
          - `Thumb` (`Frame`)
        - `ChargeBar` (`Frame`)
          - `Fill` (`Frame`)
        - `CooldownBar` (`Frame`)
          - `Fill` (`Frame`)
        - `DirectionIndicator` (`ImageLabel`)
- Compatibility fallback is supported for `DirectionArrow` if an older place file already uses that name.

## 4. Roblox Studio setup guide

### ChargeBar

- Instance path: `StarterGui.SlingArenaUI.SlingUI.ChargeBar`
- Type: `Frame`
- Recommended properties:
  - `AnchorPoint = Vector2.new(0, 0.5)`
  - `Position = UDim2.new(0.5, 0, 0.85, 0)`
  - `Size = UDim2.new(0.32, 0, 0.035, 0)`
  - `ClipsDescendants = true`
- Child fill path: `StarterGui.SlingArenaUI.SlingUI.ChargeBar.Fill`
- Fill properties:
  - `AnchorPoint = Vector2.new(0, 0.5)`
  - `Position = UDim2.new(0, 0, 0.5, 0)`
  - `Size = UDim2.new(0, 0, 1, 0)` at rest
- Fill direction: **left → right** using `Fill.Size = UDim2.new(chargeRatio, 0, 1, 0)`.

### CooldownBar

- Instance path: `StarterGui.SlingArenaUI.SlingUI.CooldownBar`
- Type: `Frame`
- Recommended properties:
  - `AnchorPoint = Vector2.new(0, 0.5)`
  - `Position = UDim2.new(0.5, 0, 0.9, 0)`
  - `Size = UDim2.new(0.32, 0, 0.025, 0)`
  - `ClipsDescendants = true`
- Child fill path: `StarterGui.SlingArenaUI.SlingUI.CooldownBar.Fill`
- Fill properties:
  - `AnchorPoint = Vector2.new(0, 0.5)`
  - `Position = UDim2.new(0, 0, 0.5, 0)`
  - `Size = UDim2.new(0, 0, 1, 0)` at rest
- Fill direction: **left → right** using `Fill.Size = UDim2.new(cooldownRatio, 0, 1, 0)`.
- Expected behavior: starts empty on release, then fills toward 100% until the cooldown ends.

### DirectionIndicator

- Instance path: `StarterGui.SlingArenaUI.SlingUI.DirectionIndicator`
- Type: `ImageLabel`
- Recommended properties:
  - `AnchorPoint = Vector2.new(0.5, 0.5)`
  - `Size = UDim2.new(0.06, 0, 0.06, 0)`
  - `BackgroundTransparency = 1`
  - center the image so rotation pivots naturally around the press point
- The script rotates the image from the drag vector with `atan2`, so the art should visually point to the right by default. If your art points up, rotate the asset by `-90` degrees in Studio.

## 5. Common bugs and fixes

- **ChargeBar does not move** → verify `ChargeBar.Fill` exists and starts at `UDim2.new(0, 0, 1, 0)`.
- **CooldownBar counts backward** → the correct behavior is `elapsed / duration`, not `remaining / duration`.
- **Direction indicator does not rotate** → ensure the image is named `DirectionIndicator` or `DirectionArrow` and its anchor point is `(0.5, 0.5)`.
- **Joystick appears offset** → verify `JoystickRoot.AnchorPoint` and `Thumb.AnchorPoint` are both `(0.5, 0.5)`.
- **Player can start charge during cooldown** → the client gate checks `cooldownEndTime`, while the server remains authoritative and rejects invalid requests.

## 6. Notes on authority

- The server still owns `StartCharge`, `ReleaseCharge`, launch force, and physics.
- The client only renders feedback for charge, drag direction, and cooldown.
- `StateUpdate` is used as a safe reset hook so the UI clears itself if the player dies or if the server state changes unexpectedly.
