# SlingUI Developer Guide

## 1. SlingUI flow

1. Player presses on their Sling pawn in the world.
2. `SlingUI.client.lua` detects the press, marks `isHolding = true`, and fires `StartCharge`.
3. The `StarterGui.SlingArenaUI.SlingUI` ScreenGui becomes visible (`JoystickRoot`, `ChargeBar`, `DirectionArrow`).
4. Dragging updates the joystick thumb delta and rotates the direction arrow.
5. `RunService.RenderStepped` increases `charge` every frame and updates `ChargeBar.Fill.Size`.
6. Releasing the same input fires `ReleaseCharge`, hides the joystick, and starts cooldown UI.

## 2. Joystick system

- Required hierarchy: `SlingArenaUI (Folder) -> SlingUI (ScreenGui) -> JoystickRoot -> Base, Thumb`, plus `ChargeBar -> Fill` and `DirectionArrow`.
- `JoystickRoot.AnchorPoint` must be `(0.5, 0.5)` so the joystick center lands exactly at the touch/click point. If the anchor point is left at `(0, 0)`, the whole joystick appears lệch khỏi vị trí input.
- The root is positioned directly from screen input with `UDim2.new(0, input.X, 0, input.Y)`.
- The drag delta is `currentPosition - startPosition`, clamped to the max joystick radius.
- `Thumb.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)` keeps thumb motion relative to the joystick center instead of absolute screen coordinates.

## 3. Charge system

- The client charge loop runs in `RunService.RenderStepped`, which is the correct per-frame update for UI and local input response.
- Each frame: `charge += deltaTime`, then percent is `math.clamp(charge / MAX_CHARGE_TIME, 0, 1)`.
- `ChargeBar.Fill.Size = UDim2.new(percent, 0, 1, 0)` drives the visual bar.
- The server still owns launch physics; the UI charge percent is only local feedback before `ReleaseCharge` is sent.
- Force scales from charge time through the existing server-side sling pipeline in `SlingService`.

## 4. Common bugs

- **Joystick not appearing** → input start is not hitting the player Sling, or the `SlingArenaUI.SlingUI` hierarchy path is wrong.
- **UI lệch / offset** → `JoystickRoot.AnchorPoint` is not `(0.5, 0.5)`, or root position is not set from the exact input position.
- **Charge không chạy** → `isHolding` was never set/reset correctly, or the `RenderStepped` loop is not updating `charge`.
- **ChargeBar.Fill not moving** → `ChargeBar.Fill` path is wrong, or the fill size is not updated with the computed percent.
- **Food floating** → verify the food root stays anchored and that spawn logic only applies X/Z randomization while keeping `Y == FoodSpawn.Position.Y`.

## 5. Debug logging

`SlingUI.client.lua` keeps its debug helper but leaves runtime logging disabled by default.
If temporary logs are re-enabled for Studio debugging, remove or disable them again after confirmation.
