# SlingUI Developer Guide

## 1. SlingUI runtime flow

1. The player presses on their Sling pawn in the world.
2. `SlingUIController.client.lua` validates that the input started on the local pawn, resolves `PlayerGui.SlingArenaUI.SlingUI`, marks the local interaction as charging, and fires `StartCharge`.
3. While the press is still held:
   - `ChargeBar.Fill.Size` grows from `0` to `1` on the X scale.
   - `JoystickRoot.Thumb` follows the drag delta.
   - `DirectionIndicator` rotates from the current drag vector.
4. On release, the client fires `ReleaseCharge`, hides the joystick visuals immediately, and waits for authoritative `StateUpdate` confirmation from the server.
5. `SlingService` validates the release, applies launch velocity on the server, and updates the player's authoritative `CooldownEndTime` in `StateUpdate`.
6. Once the client receives `StateUpdate` with `MovementState = Launched|Recovering` and a future `CooldownEndTime`, `CooldownBar.Fill.Size` grows from `0` to `1` on the X scale.
7. When the cooldown completes or the server returns the player to `Idle`, the update loop disconnects and the player can charge again.

## 2. Why the old implementation broke

The old LocalScript was also named `SlingUI`, which collided with the required `SlingUI` `ScreenGui` name in `StarterGui.SlingArenaUI`. Because Roblox allows same-name siblings, path resolution could hit the LocalScript instead of the `ScreenGui`, leaving `ChargeBar.Fill` and `CooldownBar.Fill` unresolved. The UI bars then never updated even though `StartCharge` and `ReleaseCharge` were firing.

The controller script is now named `SlingUIController.client.lua`, so the `SlingUI` path resolves to the intended `ScreenGui` only.

## 3. Deterministic UI initialization

The old implementation used a hardcoded 2-second timeout while waiting for cloned UI. That made startup nondeterministic:

- fast clones still paid an unnecessary delay in some paths;
- slow clones could miss the timeout and permanently fail to bind;
- once the timeout elapsed, the code stayed in a partially bound state.

The current implementation is event-driven instead:

- `UIBinder.client.lua` creates the controller immediately;
- it rebinds whenever `PlayerGui` children/descendants appear or disappear;
- `SlingUIController.client.lua` resolves existing UI synchronously and re-resolves on `DescendantAdded`.

This guarantees the UI binds as soon as the hierarchy exists, without guessing timing.

## 4. Required Studio hierarchy

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

Compatibility fallback is still supported for `DirectionArrow` if an older place file already uses that name.

## 5. UI elements involved

### JoystickRoot
- World-space touch/mouse drag anchor.
- `Base` is the visual ring.
- `Thumb` follows the drag delta.

### ChargeBar
- Path: `StarterGui.SlingArenaUI.SlingUI.ChargeBar`
- Child fill path: `StarterGui.SlingArenaUI.SlingUI.ChargeBar.Fill`
- Fills left-to-right with `Fill.Size = UDim2.new(chargeRatio, 0, 1, 0)`.

### CooldownBar
- Path: `StarterGui.SlingArenaUI.SlingUI.CooldownBar`
- Child fill path: `StarterGui.SlingArenaUI.SlingUI.CooldownBar.Fill`
- Fills left-to-right with `Fill.Size = UDim2.new(cooldownRatio, 0, 1, 0)`.
- Driven by authoritative `StateUpdate.CooldownEndTime`.

### DirectionIndicator
- Path: `StarterGui.SlingArenaUI.SlingUI.DirectionIndicator`
- Rotates from the current drag vector using `atan2`.

## 6. Remote/data flow summary

- Input start: client-only hit test on local pawn.
- Charge begin: `StartCharge` (`Client -> Server`).
- Server authority: `SlingService` sets `IsCharging = true` and movement state to `Charging`.
- Charge bar animation: local client loop for immediate feedback while the input is held.
- Release: `ReleaseCharge` (`Client -> Server`).
- Launch + cooldown authority: server computes force, launches the pawn, sets `CooldownEndTime`, and publishes `StateUpdate`.
- Cooldown animation: client reads `StateUpdate.CooldownEndTime` and animates `CooldownBar.Fill` until the authoritative end time.
- Round overlays: `UIStateUpdate` remains dedicated to match/lobby status, not sling charge UI.

## 7. Common bugs and fixes

- **ChargeBar does not move** -> verify `ChargeBar.Fill` exists and starts at `UDim2.new(0, 0, 1, 0)`.
- **CooldownBar never starts** -> verify the client receives `StateUpdate` with a future `CooldownEndTime`; `UIStateUpdate` is not the source for cooldown visuals.
- **Direction indicator does not rotate** -> ensure the image is named `DirectionIndicator` or `DirectionArrow` and its anchor point is `(0.5, 0.5)`.
- **Joystick appears offset** -> verify `JoystickRoot.AnchorPoint` and `Thumb.AnchorPoint` are both `(0.5, 0.5)`.
- **Player can attempt charge during cooldown** -> the client gates against the last authoritative cooldown end time, and the server remains authoritative if the client mispredicts.
