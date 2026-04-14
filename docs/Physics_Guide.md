# Sling Arena Physics Guide

This guide documents the **current implementation** only (no new system), with a focus on movement + launch and where to tune physics parameters.

## 1. Movement System

### Input flow (WASD)
- Client script `StarterPlayerScripts/SlingMovement.client.lua` reads keyboard state via `UserInputService` and sends `MoveRequest` continuously on `RunService.RenderStepped` with a normalized planar `Vector3` direction.
- Server script `ServerScriptService/Services/SlingService.lua` receives `MoveRequest`, validates payload through `RemoteContracts`, checks control rules (alive, round state, not charging/recovering), then stores desired input in `_input[player]`.

### How movement is applied
- **Not CFrame teleporting**. Movement is physics-based and server authoritative.
- On `RunService.Heartbeat`, `SlingService:_stepMovement()` calls `SlingMovement:Move(...)`.
- `SlingMovement` uses a **LinearVelocity actuator** (`VelocityConstraintMode = Plane`) attached to the root part, setting `PlaneVelocity` (X/Z plane only).
- Acceleration/deceleration smoothing is applied by lerping toward target planar velocity each frame.

### Core services involved
- `UserInputService` (client input capture)
- `RunService.RenderStepped` (client send loop)
- `RunService.Heartbeat` (server movement simulation)
- Remote: `SlingArenaRemotes.MoveRequest`

### Movement parameter tuning points
- `Config.MoveSpeed`
- `BalanceConfig.GroundAcceleration` / `BalanceConfig.GroundDeceleration` (fallbacks in code)
- `SlingMovement` force multiplier (`DEFAULT_FORCE_MULTIPLIER` / options.forceMultiplier)

---

## 2. Launch System (Charge / Release)

### Direction calculation
- `StartCharge` stores initial aim direction as `(aimTarget - root.Position).Unit` using `SlingService.ResolveAimDirection(...)`.
- `ReleaseCharge` recalculates aim direction from latest aim target.
- Planar aim is clamped by max launch distance logic (`MAX_LAUNCH_DISTANCE`) before final launch vector use.

### Force and velocity application
- Charge ratio: `elapsed / maxChargeTime` (clamped 0..1).
- Launch force: `CalculateLaunchForce(chargeRatio, ..., maxForce, ...) * RELEASE_SPEED_MULTIPLIER`.
- Launch vector: `direction * launchForce`.
- **Application method**: direct write to `root.AssemblyLinearVelocity` (X/Z replaced by planar launch, Y preserved).
- So launch is currently done via **AssemblyLinearVelocity**, not VectorForce/BodyMover impulse.

### Where force/speed is clamped
- Charge ratio clamped in `CalculateChargeRatio`.
- Launch force clamped in `CalculateLaunchForce` to `[0, maxForce]`.
- Planar launch speed clamped to:
  - move-speed-derived cap (`MoveSpeed * LaunchSpeedToMoveSpeedRatio`)
  - and global cap `MaxLaunchPlanarSpeed`
  - final cap is min of those two.

### Launch parameter tuning points
- `SlingshotConfig.MAX_CHARGE_TIME`
- `SlingshotConfig.MAX_LAUNCH_FORCE` (or fallback formula)
- `BalanceConfig.ReleaseSpeedMultiplier`
- `BalanceConfig.MaxLaunchDistance`
- `BalanceConfig.LaunchSpeedToMoveSpeedRatio`
- `BalanceConfig.MaxLaunchPlanarSpeed`
- `SlingshotConfig.RECOVER_TIME` (launch recovery state duration)

---

## 3. Physics Explanation

### Gravity
- **INFERRED:** gravity is default Roblox global gravity.
- No assignment to `Workspace.Gravity` was found in runtime services.
- Vertical velocity (`Y`) is usually preserved while custom logic edits X/Z, so gravity naturally continues to act.

### Mass / Weight
- Runtime mass math in collisions uses `Config.Mass * state.Size` as effective mass estimate for momentum comparison.
- Pawn root is now expected to be `Hitbox` (`Model.PrimaryPart = Hitbox`).
- Existing template code in `PlayerService` still conditionally applies custom physical properties to a part named `Body`; this is legacy-safe logic and may be inactive with the standardized template if no `Body` part exists.

### Friction / Drag
- No explicit friction tuning via `CustomPhysicalProperties` on the active Hitbox path was found.
- Horizontal damping is primarily **custom code drag** in `CollisionService:_applyDragAndBounce()`:
  - `horizontal *= (1 - Config.AirDrag * dt)`
  - snaps to zero under `Config.StopVelocityThreshold`.
- Wall/gate bounce also modifies planar velocity directly using `Config.BounceLoss`.

### Air control
- Players can influence movement mid-air because locomotion is plane-velocity based and processed on heartbeat whenever movement state allows control.
- During `Launched`, locomotion actuator is disabled to preserve launch momentum.
- After launch recovery window ends, movement state returns to `Idle`, locomotion re-enables, and X/Z velocity can be steered again even before landing (no hard grounded-only movement gate in movement loop).

### Other velocity modifiers in pipeline
- Collision winner velocity decay: multiplied by `BalanceConfig.VelocityDecayFactor`.
- Damage knockback: added to `AssemblyLinearVelocity`, then X/Z clamped by `BalanceConfig.MaxVelocity`.
- Trap pushes: adds directional + upward velocity.

