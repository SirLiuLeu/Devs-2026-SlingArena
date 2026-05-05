# 1. System Overview

This document describes the current physics and collision implementation in this repository. It is intentionally limited to what the code actually does.

## Current physics/collision goals visible in code

- **Server-authoritative player launch and player-vs-player collision:** `SlingService` owns charge/release state, server launch velocity, network ownership during launch, launch decay, and launch stop/recovery transitions. `CollisionService` polls server positions/velocities and resolves player collisions, wall bounce, trap candidates, and collision events.
- **Client-side input and food-hit prediction:** `InputController.client.lua` continuously sends movement/aim input. `SlingUIController.client.lua` sends charge start/release requests. `FoodCollisionClient.client.lua` predicts food overlaps, briefly applies local hitstop/bounce feel, and sends `ReportFoodHit`; `FoodService` validates and resolves the food hit on the server.
- **Damage authority on server:** `DamagePipelineService` computes player collision damage from server collision metadata and applies HP/death/feedback on the server.
- **Mixed architecture reality:** `Rule_DESIGN.md` describes client prediction + server authority for physics/combat, but the current player-vs-player launch/collision path is primarily server-simulated. Client prediction/reconciliation exists for food collisions only; there is no client prediction/reconciliation path for player-vs-player collision in the current code.

## Overall flow: charge → launch → collision → damage

1. **Movement/aim input:** client sends `MoveRequest` every `1 / 20` seconds with a planar movement vector and current aim direction.
2. **Charge start:** client calls `StartCharge` with a planar aim direction. Server validates the remote payload, control permission, cooldown, state, root, and duplicate charge state before setting `IsCharging` and `MovementState = Charging`.
3. **Release / launch:** client calls `ReleaseCharge`. Server computes charge ratio via `LaunchMotionModel.ComputeChargeRatio`, builds launch state via `LaunchMotionModel.BuildState`, disables locomotion `LinearVelocity` controllers, sets server network ownership, and writes planar `AssemblyLinearVelocity` directly.
4. **Launch decay / stop:** server heartbeat samples `LaunchMotionModel.Sample` while `MovementState == "Launching"`, overwriting planar velocity with the sampled speed. Launch ends when horizontal velocity reaches `BalanceConfig.VelocityStopThreshold`; the player enters `Recovering`, then later `Idle` after a dynamic cooldown equal to the measured release duration.
5. **Collision:** `CollisionService` heartbeat applies drag/wall bounce, detects player overlaps by pairwise distance, resolves player collision response, and emits collision events. `FoodService` separately polls food collisions and accepts client `ReportFoodHit` reports after server validation.
6. **Damage:** player-vs-player collision emits `CollisionPlayerHit`; `DamagePipelineService` computes collision damage and applies it to the victim. Food collision damage is handled inside `FoodService` against food HP, not through `DamagePipelineService`.

## Main modules involved

| Area | Module/file | Responsibility |
| --- | --- | --- |
| Client movement input | `src/StarterPlayer/StarterPlayerScripts/InputController.client.lua` | Sends `MoveRequest(input, aimDirection)` at 20 Hz. |
| Client charge UI | `src/StarterGui/SlingArenaUI/SlingUIController.client.lua` | Sends `StartCharge` / `ReleaseCharge`, displays charge/cooldown UI. |
| Server launch/movement authority | `src/ServerScriptService/Services/SlingService.lua` | Validates remotes, controls movement states, applies launch velocity, samples launch decay/stop. |
| Server locomotion actuator | `src/ServerScriptService/Services/SlingMovement.lua` | Creates/controls a planar `LinearVelocity` for normal movement. |
| Launch model | `src/ServerScriptService/Services/LaunchMotionModel.lua` | Computes charge ratio, initial speed/energy/duration, and time-based speed/energy samples. |
| Player/player collision | `src/ServerScriptService/Services/CollisionService.lua` | Polls distance collision, wall/trap candidates, collision response and transfer. |
| Player damage pipeline | `src/ServerScriptService/Services/DamagePipelineService.lua` | Computes player collision damage, clamps/applies HP damage, death, feedback, reflect. |
| Food collision | `src/ServerScriptService/Services/FoodService.lua` and `src/StarterPlayer/StarterPlayerScripts/FoodCollisionClient.client.lua` | Client predicts food overlap; server validates and consumes/damages food. |
| Trap reaction | `src/ServerScriptService/Services/TrapService.lua` | Applies trap damage/exp penalty and pushes player away from trap. |
| Shared validation | `src/ReplicatedStorage/Shared/RemoteContracts.lua` | Validates remote payload shapes. |
| Bootstrap/use sites | `src/ServerScriptService/Main.server.lua` | Constructs and starts services in the active architecture. |
| Design target | `Rule_DESIGN.md` | Stated target rules used to evaluate feasible refactors. |

# 2. Launch / Apply Force

## How force/velocity is applied

- Current launch does **not** use `VectorForce`, `BodyVelocity`, `ApplyImpulse`, or a true Roblox force for player launch.
- On `ReleaseCharge`, the server directly writes planar speed to the root part:
  - X = `launchState.direction.X * launchState.initialSpeed`
  - Y = existing `root.AssemblyLinearVelocity.Y`
  - Z = `launchState.direction.Z * launchState.initialSpeed`
- The server sets `root:SetNetworkOwner(nil)` before writing the launch velocity, making the server the launch physics owner.
- Existing root descendant `LinearVelocity` controllers are zeroed and disabled during launch to prevent locomotion from counteracting launch momentum.
- Normal movement uses a planar `LinearVelocity` actuator in `SlingMovement` with `VelocityConstraintMode = Plane`, `PrimaryTangentAxis = Vector3.xAxis`, `SecondaryTangentAxis = Vector3.zAxis`, and `PlaneVelocity = desired X/Z speed`.

## Where calculations happen

| Calculation | Function/module |
| --- | --- |
| Charge ratio | `LaunchMotionModel.ComputeChargeRatio(startedAt, now)` |
| Initial launch direction fallback/sanitization | `SlingService.ResolveAimDirection`, `ResolveLaunchDirectionFromRoot`, `ResolveLaunchDirection` |
| Launch state speed/energy/duration | `LaunchMotionModel.BuildState(direction, chargeRatio, now, player)` |
| Direct velocity application | `SlingService:ReleaseCharge` |
| Per-heartbeat speed sample | `LaunchMotionModel.Sample(state, now)` called by `SlingService:_stepMovementStates` |

## Related states

- `Charging`: set by `SlingService:StartCharge` after server validation.
- `Launching`: set by `SlingService:ReleaseCharge` after direct velocity write.
- `Recovering`: set by `SlingService:_stepMovementStates` when horizontal speed reaches the stop threshold.
- `Idle` / `Moving`: normal movement states set by `SlingService:_applyRootVelocity` when not launching/recovering/charging.

## Whether time-decay is used

- Yes, **server launch speed uses a time-based sampled decay** from `LaunchMotionModel.Sample`:
  - `elapsed = now - state.startTime`
  - `fullWindow = state.duration * LaunchConfig.Duration.FullSpeedRatio`
  - `decayWindow = state.duration * LaunchConfig.Duration.DecayRatio`
  - after `fullWindow`, `decayAlpha = clamp((elapsed - fullWindow) / decayWindow, 0, 1)`
  - `speed = state.initialSpeed * (1 - decayAlpha^2)`
- Launch energy also decays over elapsed time:
  - `passiveDecay = 1 - (LaunchConfig.Energy.PassiveDecayPerSecond * elapsed)`
  - `energy = max(0, state.energy * max(0, passiveDecay))`
- Important implementation detail: `LaunchMotionModel.Sample` uses the launch state's current `state.energy` as the base each heartbeat; because `SlingService` then writes `launchState.energy = sampledEnergy`, passive energy decay is compounded over repeated samples rather than derived only from original launch energy.

# 3. Stop / Decay

## When launch stops

`SlingService:_stepMovementStates` stops active launch motion in two steps:

1. While `MovementState == "Launching"`, it samples speed and energy.
   - If `speed <= LaunchConfig.Speed.StopThreshold` or sampled energy is `<= 0`, planar velocity is set to zero.
   - Otherwise planar velocity is overwritten with `launchState.direction * speed`.
2. After that write, it checks actual horizontal velocity magnitude. If `MovementState == "Launching"` and horizontal speed is `<= BalanceConfig.VelocityStopThreshold`, the service restores disabled velocity controllers, computes release duration, sets a cooldown end time, and transitions to `Recovering`.

## Stop conditions

| Stop condition | Constant/value | Effect |
| --- | --- | --- |
| Sampled launch speed low | `LaunchConfig.Speed.StopThreshold = 3.5` | Planar velocity is zeroed. |
| Sampled launch energy depleted | `sampledEnergy <= 0` | Planar velocity is zeroed. |
| Actual horizontal velocity low | `BalanceConfig.VelocityStopThreshold = 0.1` | State transitions from `Launching` to `Recovering`. |
| Recovery cooldown elapsed | dynamic `self._releaseCooldown[player] = now + releaseDuration` | State transitions from `Recovering` to `Idle`. |

## Speed reduction logic

- **Launch model decay:** during launch, `SlingService` overwrites planar velocity from `LaunchMotionModel.Sample` every heartbeat.
- **Global drag:** `CollisionService:_applyDragAndBounce` also multiplies every alive player's horizontal velocity by `dragFactor = max(0, 1 - Config.AirDrag * dt)` and zeros it under `Config.StopVelocityThreshold`.
- **Important coupling:** `CollisionService:_applyDragAndBounce` runs before collision detection in the same `CollisionService` heartbeat, while `SlingService:_stepMovementStates` also rewrites launch velocity in its own heartbeat. The final velocity can depend on heartbeat connection ordering.
- **Disable locomotion decay:** `SlingMovement:DisableLocomotion(false)` reduces existing planar velocity to 25%, but launch uses `DisableLocomotion(true)`, so this 25% reduction is used for charging/recovering locomotion disabling, not for preserved launch momentum.

## State transitions

- `Idle/Moving` → `Charging`: valid `StartCharge`.
- `Charging` → `Launching`: valid `ReleaseCharge`.
- `Launching` → `Recovering`: horizontal speed <= `BalanceConfig.VelocityStopThreshold`.
- `Recovering` → `Idle`: `now >= self._releaseCooldown[player]`.
- `Charging` or `Recovering` block movement input by setting stored input to `Vector3.zero`; `Launching` disables locomotion and keeps aim rotation only.

# 4. Collision Detection

## Player-vs-player collision

- Method: **server-side pairwise distance polling** on every `RunService.Heartbeat` in `CollisionService:Init`.
- `CollisionService:_detectPlayerCollisions` loops all player pairs and reads server roots via `PlayerService:GetRoot`.
- A collision candidate is detected when:
  - both roots exist,
  - both players are alive,
  - distance between root positions is `<= (rootA.Size.X + rootB.Size.X) * BalanceConfig.PlayerCollisionDistanceFactor`,
  - pair cooldown `BalanceConfig.CollisionCooldown` has elapsed.
- No raycast, `.Touched`, `GetPartsInPart`, or Roblox overlap query is used for player-vs-player collision.

## Wall collision

- Method: **position bounds check** in `CollisionService:_applyDragAndBounce`.
- If `abs(root.Position.X)` or `abs(root.Position.Z)` exceeds `Config.MaxArenaRadius - BalanceConfig.ArenaWallPadding`, the corresponding horizontal velocity axis is inverted and reduced by `1 - Config.BounceLoss`.
- Wall collision events are rate-limited by `BalanceConfig.WallCollisionCooldown`.

## Trap collision

- Method 1: `CollisionService:_resolveTrapCollisions` checks whether each root position is inside each trap part's local-space AABB via `trap.CFrame:PointToObjectSpace(root.Position)` and half-size bounds.
- Method 2: `TrapService` also binds `BasePart.Touched` handlers when map resources are loaded.
- `CollisionService` emits `TrapCollisionCandidate`; `TrapService:OnTrapCollision` applies effects with `TrapConfig.TriggerCooldown`.

## Food collision

Food collision has two paths:

1. **Server polling path:** `FoodService:_startCollisionLoop` runs every `COLLISION_INTERVAL = 0.05`. It records motion history, checks nearby food grid entries, detects distance/swept collision against food hitboxes, and resolves common/HP food effects.
2. **Client-predicted report path:** `FoodCollisionClient.client.lua` checks nearby food on `RenderStepped` using X/Z radius plus ping expansion and Y tolerance, applies local predicted bounce/hitstop, and fires `ReportFoodHit`. `FoodService:Start` validates the report using server root position, server velocity, movement state, speed caps, distance/swept checks, and Y tolerance.

## Conditions where collision is ignored

- Player-vs-player pair is ignored if either root is missing, either player is not alive, pair cooldown has not elapsed, or resolved impact speed is below `LaunchConfig.Collision.MinImpactSpeed`.
- Player-vs-player response is ignored unless one side has an active launch state (`slingService._activeLaunches[player]`). If neither has active launch energy/state, collision is skipped.
- Food client reports are ignored/rejected if payload shape is invalid, per-player report cooldown is active, food entry is inactive/consumed/missing, player/root is invalid/dead, root speed exceeds `MAX_ALLOWED_SPEED`, movement state is missing/disallowed, HP food recent horizontal speed is below `HP_FOOD_MIN_HORIZONTAL_SPEED`, distance/swept validation fails, or Y mismatch exceeds `Y_TOLERANCE`.
- Common food server validation allows `Launching`, `Moving`, and `Idle`; HP food validation does not explicitly require `Launching`, but requires recent horizontal speed >= `22`.
- `DamagePipelineService:ApplyDamage` ignores attacker-caused combat damage outside `EarlyGame`/`FinalPhase`, ignores invulnerable victims, clamps damage, and zeroes friendly-fire damage.

# 5. Collision Response

## What happens on player-vs-player collision

When `CollisionService:_resolvePlayerCollisions` accepts a hit:

1. Reads horizontal velocities `va`/`vb` and computes normal from A to B in X/Z.
2. Computes `rel = va - vb` and `impactSpeed = max(0, rel:Dot(normal))`.
3. Chooses the attacker as the player with greater active launch energy. If B has more energy than A, attacker/defender are swapped and normal/relative velocity are inverted.
4. Requires `attackerLaunch` to exist; otherwise skips.
5. Computes outgoing relative velocity from normal/tangent components:
   - `relativeNormalVelocity = normal * rel:Dot(normal)`
   - `relativeTangentVelocity = rel - relativeNormalVelocity`
   - `outgoingRelativeVelocity = relativeTangentVelocity * TangentialDamping - relativeNormalVelocity * Restitution`
6. Reduces attacker energy by `CollisionLossRatio` and derives `energyRetention`.
7. Computes attacker outgoing velocity as `defenderVelocity + outgoingRelativeVelocity * energyRetention`.
8. Updates the attacker's launch state from the outgoing velocity and remaining energy, then applies that horizontal velocity to the attacker root.
9. Computes transfer speed/energy and may apply velocity plus a new active launch state to the defender.
10. Emits `CollisionDetected` and `CollisionPlayerHit` events. Damage is handled by `DamagePipelineService`, not inside `CollisionService`.

## Bounce / deflection logic

- Player-vs-player bounce is not a Roblox impulse. It is direct horizontal velocity assignment based on relative velocity decomposition, tangential damping, restitution, and retained launch energy.
- Wall bounce inverts the exceeded axis and multiplies by `1 - Config.BounceLoss`.
- Food HP collision bounce has two implementations:
  - server polling path reflects full velocity with `_reflectVelocity(velocity, normal) = reflected * REFLECTION_DAMPING` and resolves penetration by moving `root.CFrame` out of the food radius;
  - client prediction path compresses velocity by `IMPACT_ABSORPTION`, waits `HITSTOP_SECONDS`, then reflects and multiplies by `BOUNCE_RETENTION`.

## Whether force is reduced, and how

- **Player-vs-player attacker energy:** `remainingEnergy = preCollisionEnergy * (1 - LaunchConfig.Energy.CollisionLossRatio)`. With current config, that keeps 72% of energy.
- **Player-vs-player attacker outgoing velocity:** outgoing relative velocity is scaled by `energyRetention`, and tangent/normal components are damped by `TangentialDamping` and `Restitution`.
- **Transferred energy:** defender chain-launch energy is `transferEnergy * LaunchConfig.Energy.ChainHitDecayMultiplier`.
- **Wall velocity:** impacted axis is multiplied by `1 - Config.BounceLoss`.
- **Global drag:** horizontal velocity is multiplied by `max(0, 1 - Config.AirDrag * dt)` in `CollisionService`.
- **HP food final hit:** when HP food reaches 0 in the server polling path, player velocity is damped by `LAST_HIT_VELOCITY_DAMPING = 0.75`.
- **HP food report path:** server applies an opposite impulse `horizontalVelocity * -root.AssemblyMass * 0.35` after applying food damage.

## How force is transferred to other objects/players

- **Player to player:** transfer uses `transferSpeed = min(MaxTransferSpeed, impactSpeed * EnergyTransferRatio * angleFactor * energyFactor)` and applies `defenderVelocity + normal * transferSpeed` to the defender. If transfer energy is high enough, the defender receives a new `_activeLaunches[defender]` state with `energy = transferEnergy * ChainHitDecayMultiplier`, `duration = 1.1`, `chargeRatio = 0.3`, and `sourcePlayer = attacker`.
- **Player to HP food:** food does not receive physical force because food models are anchored. Instead, food HP is reduced, and the player is reflected/damped or receives an opposite impulse depending on path.
- **Traps to player:** trap collision adds velocity `away.Unit * 55 + Vector3.new(0, 10, 0)`.

# 6. Damage Model

## Player collision damage

`DamagePipelineService:ComputeCollisionDamage(attackerState, impactSpeed, collisionMeta)` computes:

```text
baseDamage = max(attackerState.BaseDamage or BalanceConfig.BaseDamage or 0, 0)
earlyBonus = 1 / (1 + elapsed * LaunchConfig.Damage.LaunchTimeBias)
chainPenalty = max(0.2, 1 - collisions * LaunchConfig.Damage.ChainDecayPerHit)
intensity = speed / max(LaunchConfig.Collision.MinImpactSpeed, 1)
energyScalar = energy / max(LaunchConfig.Energy.Max, 1)
damage = baseDamage
  * (1 + energyScalar)
  * earlyBonus
  * chainPenalty
  * (intensity * LaunchConfig.Damage.CollisionIntensityMultiplier)
  * LaunchConfig.Damage.BaseMultiplier
clamped to 0..LaunchConfig.Damage.Max
```

Then `ApplyDamage` clamps again to `BalanceConfig.MaxDamagePerHit`.

Important current behavior:

- The attacker state's `BaseDamage` comes from `PlayerStateService`; default/recalculated base damage comes from `SlingshotConfig.SlingConfig.BaseDamage` scaled by level multiplier.
- Collision metadata is populated by `CollisionService` from launch energy, collision count, elapsed launch time, impact speed, and transferred speed.
- `DamagePipelineService:Init` calls `ApplyDamage(..., { SuppressKnockback = true })` for `CollisionPlayerHit`, so the separate `ComputeCollisionKnockback` function is not used for current player-vs-player collision damage.

## Food collision damage

`FoodService:_applySlingDamage(entry, player, velocity)` computes:

```text
clampedVelocity = clamp(velocity, DAMAGE_MIN_VELOCITY, DAMAGE_MAX_VELOCITY)
damage = clampedVelocity * DAMAGE_BASE
```

With current local constants, this means:

- minimum food hit damage uses velocity `20`, producing `2000` damage;
- maximum food hit damage uses velocity `170`, producing `17000` damage.

Common food with `rule.Touch == true` is consumed instead of damaged. HP food is damaged until current HP reaches 0, then reward/consume logic runs.

## Damage cooldown

- Player-vs-player collision candidate cooldown is per unordered pair key and uses `BalanceConfig.CollisionCooldown = 0.3`. Because `DamagePipelineService` reacts to `CollisionPlayerHit`, this is the effective cooldown between player collision damage applications for the same pair.
- `PlayerStateService` has invulnerability fields (`InvulnerableUntil`, `HitInvulSeconds`, `DefaultInvulnerableSeconds` in config), and `ApplyDamage` checks `IsInvulnerable`, but current player-vs-player collision handling does not mark victims invulnerable after a hit.
- HP food server polling path uses per-player/per-food `DEFAULT_HIT_COOLDOWN = 0.18`.
- Food client report path uses client `REPORT_COOLDOWN = 0.05` and server `_hitRequestCooldown` / `HIT_REQUEST_COOLDOWN = 0.06` per player.
- Trap effects use `TrapConfig.TriggerCooldown` inside `TrapService` and `BalanceConfig.TrapCollisionCooldown` inside `CollisionService` candidate emission.

## Anti-spam / multi-hit control

- Pairwise player collision cooldown in `CollisionService._lastCollision`.
- Wall collision cooldown in `CollisionService._lastWallCollision`.
- Trap candidate cooldown in `CollisionService._lastTrapCollision` plus trap trigger cooldown in `TrapService._lastTriggeredAt`.
- Food local/server report cooldowns and HP-food per-food cooldowns.
- Server combat damage is blocked outside combat rounds and against invulnerable victims.

## Authority

- Player damage is server-authoritative: `CollisionService` emits server events, `DamagePipelineService` computes/applies damage, and `PlayerStateService` mutates HP.
- Food damage/consume is server-authoritative: client prediction can hide common food or bounce locally, but `FoodService` validates and applies the actual consume/damage.

# 7. Client / Server Sync

## What client predicts

- Movement input/aim are not local physics authority in code; the client sends input requests.
- Charge UI predicts/display charge ratio using `SlingshotConfig.MAX_CHARGE_TIME` but server launch charge ratio uses `LaunchModelConfig.Charge.MaxSeconds`.
- Food collision client predicts overlap, hides common food immediately, records `beforeVelocity`/`beforePosition`, applies local hitstop/bounce, and sends `ReportFoodHit`.
- There is no current client-side prediction implementation for player-vs-player collision response or player collision damage.

## What server validates

- `SlingService` validates `MoveRequest`, `StartCharge`, and `ReleaseCharge` payload types through `RemoteContracts.Validate`, plus control permission, alive/stunned/round state, movement state, root validity, anchored state, and root mass.
- `FoodService` validates `ReportFoodHit` by active food entry, alive/root, max speed, movement state, HP-food recent speed, distance/swept checks, and Y tolerance.
- `DamagePipelineService` validates combat round, invulnerability, team friendliness, damage clamp, and alive state through `PlayerStateService`.

## Handling of position mismatch

- Food hit rejection is the only explicit client reconciliation path found.
- On `GameplayFeedback` with `EventType == "FoodHitRejected"`, `FoodCollisionClient` restores the recorded pre-hit velocity and compares current position to `beforePosition`:
  - if delta >= `MAJOR_DESYNC = 12`, it teleports local root to `beforePosition`;
  - if delta >= `MINOR_DESYNC = 4`, it lerps root CFrame 35% toward `beforePosition`;
  - otherwise it leaves position unchanged after velocity restore.
- This correction is to the client's stored pre-prediction position, not a server-provided authoritative position. The rejection payload only includes `FoodId` and `ServerResync = true`.

## Source of truth

- **Source of truth for player state/HP/damage:** server `PlayerStateService` and `DamagePipelineService`.
- **Source of truth for launch/player collision:** server `SlingService` and `CollisionService`.
- **Source of truth for food state:** server `FoodService` (`_foodById`, active/consumed flags, HP attributes, server consume/destroy).
- **Client prediction layer:** current code only implements visible food-hit prediction/rejection rollback.

# 8. Anti-hack / Validation

## Current exploit prevention mechanisms

- Remote shape validation in `RemoteContracts` for `MoveRequest`, `StartCharge`, `ReleaseCharge`, `RequestLaunch`, and `ReportFoodHit`.
- `SlingService:HandleMoveRequest` rate-limits movement events to one accepted event per `0.03` seconds per player.
- Client movement input is normalized/clamped by server to planar magnitude <= 1 before movement use.
- Charge/release require control permission (`_canControl`), alive player, valid round/queue/lobby state, not stunned, valid state transitions, and valid root/mass.
- Launch direction is flattened to X/Z; near-zero aim falls back to forward/default.
- During launch, network ownership is set to the server (`nil`), reducing client authority over launch simulation.
- Food report validation rejects excessive speed (`MAX_ALLOWED_SPEED = 450`), bad movement states, low recent speed for HP food, distance/sweep/Y mismatches, invalid food IDs, inactive/consumed food, dead players, and request spam.
- Damage application rejects attacker-caused combat damage outside `EarlyGame`/`FinalPhase`, invulnerable victims, and friendly fire.

## Validation of speed, position, state, collision

| Validation target | Current code |
| --- | --- |
| Movement remote type | `RemoteContracts.Names.MoveRequest` requires `Vector3`. |
| Movement frequency | `SlingService._moveRateState` rejects events closer than `0.03` seconds. |
| Movement magnitude | `SlingService` stores `planar.Unit` if magnitude > 1. |
| Charge/release type | `RemoteContracts` requires aim `Vector3`. |
| Launch state | `StartCharge` rejects Charging/Launching/Recovering and duplicate charge; `ReleaseCharge` requires existing charge state. |
| Food speed cap | `FoodService:_validateFoodHit` rejects root speed > `450`. |
| Food position | Server distance and swept path checks against server root/current/motion history. |
| Food Y mismatch | Server rejects if vertical difference > `10`. |
| Player collision | Server root positions and server velocities only; pair cooldown and impact speed threshold. |
| Damage | Server round state, invulnerability, team friendliness, damage clamps. |

## Potential weak points based only on current code

- `StartCharge`/`ReleaseCharge` only validate aim type and server control state; there is no client/server aim delta clamp currently enforced, despite `Config.MaxAimAngleDelta` existing.
- `RemoteContracts.Names.ReportFoodHit` has a validator, but `FoodService:Start` does not call `RemoteContracts.Validate` before using payload fields; it only checks `type(payload) == "table"`. The deeper `_validateFoodHit` still rejects most bad reports, but the shared contract is not consistently used.
- Player-vs-player collision cooldown is set when a distance candidate is detected, before impact speed and active launch checks. A non-damaging close overlap can consume the cooldown window and suppress an immediate valid hit.
- Player-vs-player collision has no explicit server-side position reconciliation to clients beyond Roblox replication.
- Food rejection rollback uses the client-cached pre-hit position, not an authoritative server position.
- `CollisionService` requires `PhysicsConfig` but does not use it, and several clamping constants expected by `Rule_DESIGN.md` are not enforced for current collision response.
- `MovementController.server.lua` is a standalone server script that also listens to `MoveRequest`, separate from `SlingService`; because `ServerScriptService` scripts run automatically in Roblox, this can create duplicate movement handlers unless intentionally disabled outside the module bootstrap.

# 9. DataConfig / Constants

No module named `DataConfig` was found in the code scan. Physics/collision tuning values are split across `PhysicsConfig`, `LaunchModelConfig`, `BalanceConfig`, `Config`, `SlingshotConfig`, `FoodService` local constants, `FoodCollisionClient` local constants, `TrapConfig`, and some service-local constants.

## Launch

| Constant/config | Value | Used? | Used by / notes |
| --- | ---: | --- | --- |
| `LaunchModelConfig.Charge.MaxSeconds` | `1.4` | Yes | `LaunchMotionModel.ComputeChargeRatio`. |
| `LaunchModelConfig.Charge.MinSeconds` | `0.15` | No | Not referenced by code. |
| `LaunchModelConfig.Duration.Min` | `1.0` | Yes | `BuildState` duration interpolation. |
| `LaunchModelConfig.Duration.Max` | `3.0` | Yes | `BuildState` duration interpolation. |
| `LaunchModelConfig.Duration.FullSpeedRatio` | `0.6` | Yes | `Sample` full-speed window. |
| `LaunchModelConfig.Duration.DecayRatio` | `0.4` | Yes | `Sample` decay window. |
| `LaunchModelConfig.Speed.Min` | `36` | Yes | Initial launch speed interpolation. |
| `LaunchModelConfig.Speed.Max` | `108` | Yes | Initial launch speed interpolation. |
| `LaunchModelConfig.Speed.StopThreshold` | `3.5` | Yes | Launch velocity zero threshold. |
| `LaunchModelConfig.Energy.Min` | `28` | Yes | Initial energy interpolation. |
| `LaunchModelConfig.Energy.Max` | `120` | Yes | Initial energy interpolation and damage energy scalar. |
| `LaunchModelConfig.Energy.PassiveDecayPerSecond` | `0.12` | Yes | Launch energy decay. |
| `PhysicsConfig.Charge.*` | `MaxChargeTime`, `ChargeForceMultiplier`, `MinForce`, `MaxForce` | No | Defined but not referenced; launch now uses `LaunchModelConfig`. |
| `Config.BaseForce`, `MaxExtraForce`, `MaxCharge`, `ChargeRatePerSecond`, `ShotCooldown`, `MaxAimAngleDelta` | mixed | No | Legacy-looking launch/charge constants; not referenced in current launch code. |
| `BalanceConfig.ReleaseDistanceMultiplier`, `ReleaseSpeedMultiplier`, `MaxLaunchDistance`, `LaunchSpeedToMoveSpeedRatio`, `MaxLaunchPlanarSpeed` | mixed | No | Not referenced in current launch code. |
| `SlingshotConfig.MAX_CHARGE_TIME` | `2.0` | Yes, client UI only | `SlingUIController` charge bar, not server launch authority. Mismatch with server `1.4`. |
| `SlingshotConfig.RECOVER_TIME` | `3.0` | Yes, client default UI only | Server recovery cooldown is dynamic release duration, not this fixed value. |
| `SlingshotConfig.MIN_LAUNCH_FORCE`, `MAX_LAUNCH_FORCE`, `MAX_AIM_DISTANCE`, `LaunchPowerPerPoint`, `ChargeSpeedPerPoint`, `SlingshotModifiers`, `SlingConfig.ForceMultiplier`, `SlingConfig.MaxPullDistance` | mixed | No for current launch | Not referenced by server launch implementation. |
| `SlingshotConfig.BaseLaunchForce` | `900` | Yes, state/stat only | Used as `PlayerState.LaunchSpeed`, but not used by `SlingService` launch velocity. |

## Decay

| Constant/config | Value | Used? | Used by / notes |
| --- | ---: | --- | --- |
| `Config.AirDrag` | `0.95` | Yes | `CollisionService:_applyDragAndBounce`. |
| `Config.StopVelocityThreshold` | `2` | Yes | Global drag zero threshold. |
| `BalanceConfig.VelocityStopThreshold` | `0.1` | Yes | Launching → Recovering threshold. |
| `BalanceConfig.VelocityDecayFactor` | `0.6` | No | Not referenced in current code despite old docs mentioning it. |
| `BalanceConfig.MaxVelocity` | `170` | Yes | Only used by `DamagePipelineService` knockback branch; current player collision suppresses knockback. |

## Collision

| Constant/config | Value | Used? | Used by / notes |
| --- | ---: | --- | --- |
| `LaunchModelConfig.Collision.MinImpactSpeed` | `6` | Yes | Player collision minimum impact speed and damage intensity denominator. |
| `LaunchModelConfig.Collision.Restitution` | `0.72` | Yes | Player collision outgoing normal response. |
| `LaunchModelConfig.Collision.EnergyTransferRatio` | `0.58` | Yes | Player collision transfer energy/speed. |
| `LaunchModelConfig.Collision.TangentialDamping` | `0.82` | Yes | Player collision tangent response. |
| `LaunchModelConfig.Collision.MinPostCollisionSpeed` | `3.5` | Yes | Zero/update launch state threshold and transfer gating. |
| `LaunchModelConfig.Collision.MaxTransferSpeed` | `90` | Yes | Defender transfer speed clamp. |
| `LaunchModelConfig.Energy.CollisionLossRatio` | `0.28` | Yes | Attacker energy reduction. |
| `LaunchModelConfig.Energy.ChainHitDecayMultiplier` | `0.82` | Yes | Defender chain-launch energy. |
| `LaunchModelConfig.Energy.MinTransferEnergy` | `8` | Yes | Defender active launch gating. |
| `BalanceConfig.CollisionCooldown` | `0.3` | Yes | Player/player pair cooldown. |
| `BalanceConfig.WallCollisionCooldown` | `0.2` | Yes | Wall collision event cooldown. |
| `BalanceConfig.TrapCollisionCooldown` | `0.25` | Yes | Trap candidate cooldown. |
| `BalanceConfig.PlayerCollisionDistanceFactor` | `0.25` | Yes | Player collision distance threshold. |
| `BalanceConfig.ArenaWallPadding` | `6` | Yes | Wall bounds threshold. |
| `BalanceConfig.MinVelocityToCollide` | `8` | No | Not referenced. |
| `Config.BounceLoss` | `0.2` | Yes | Wall bounce velocity retention. |
| `Config.MaxArenaRadius` | `300` | Yes | Wall bounds threshold. |
| `Config.Mass` | `5` | Yes | Player template body physical properties; not player collision formula. |
| `PhysicsConfig.Collision.MinImpulse`, `MaxImpulse`, `PlayerImpulseScale`, `MinCollisionSpeed`, `HitstopSeconds`, `ImpactAbsorption`, `BounceRetention` | mixed | No | Defined but not referenced; client food prediction uses duplicate local constants, not this config. |
| `PhysicsConfig.PhysicalProperties.*` | mixed | Yes | Applied to roots by `SlingService` and duplicate `MovementController.server.lua`; elasticity may be overridden by `Stability.ZeroElasticity`. |
| `PhysicsConfig.Stability.UseInfiniteForce`, `ZeroElasticity` | booleans | Yes | Movement controller max force and root elasticity. |

## Damage

| Constant/config | Value | Used? | Used by / notes |
| --- | ---: | --- | --- |
| `LaunchModelConfig.Damage.BaseMultiplier` | `1.0` | Yes | Collision damage formula. |
| `LaunchModelConfig.Damage.LaunchTimeBias` | `0.55` | Yes | Early-hit damage bonus decay. |
| `LaunchModelConfig.Damage.CollisionIntensityMultiplier` | `1.4` | Yes | Collision damage formula. |
| `LaunchModelConfig.Damage.ChainDecayPerHit` | `0.22` | Yes | Collision chain penalty. |
| `LaunchModelConfig.Damage.Max` | `420` | Yes | First collision damage clamp. |
| `BalanceConfig.MaxDamagePerHit` | `350` | Yes | Final damage clamp in `ApplyDamage`. |
| `BalanceConfig.BaseDamage` | `20` | Fallback only | Used if attacker state lacks `BaseDamage`; default state normally uses `SlingshotConfig.SlingConfig.BaseDamage`. |
| `BalanceConfig.BaseImpactForce`, `KnockbackFactor`, `MaxKnockback` | mixed | Function used? no | Used only by `ComputeCollisionKnockback`, which is not called by current collision pipeline. |
| `BalanceConfig.SelfDamageRatio`, `MaxSelfDamageToCurrentHpRatio` | mixed | No | Not referenced. |
| `BalanceConfig.MaxChargeSelfDamage` | `18` | Yes | Fired on max charge release and clamps `ApplySelfDamage`. Actual listener for `MaxChargeReleased` was not found in current code. |
| `BalanceConfig.DefaultInvulnerableSeconds`, `HitInvulSeconds` | mixed | No current collision use | Values exist; current collision pipeline does not mark hit invulnerability. |
| `SlingshotConfig.SlingConfig.BaseDamage` | `211000` | Yes | Default/recalculated player `BaseDamage`; damage is later clamped to `420` then `350`. |
| `SlingshotConfig.SlingConfig.ReflectDamagePercent` | `0.05` | Yes | Applied via final stats reflect in `DamagePipelineService`. |
| `FoodService` local `DAMAGE_MIN_VELOCITY`, `DAMAGE_MAX_VELOCITY`, `DAMAGE_BASE` | `20`, `170`, `100` | Yes | Food HP damage formula. |
| `TrapService` hardcoded damage | `15` | Yes | Trap HP damage through `DamagePipelineService:ApplyDamage`. |

## Sync/validation

| Constant/config | Value | Used? | Used by / notes |
| --- | ---: | --- | --- |
| `InputController` `SEND_INTERVAL_SECONDS` | `1/20` | Yes | Client movement send rate. |
| `SlingService` move accept interval | `0.03` | Yes | Server movement rate limit. |
| `FoodCollisionClient` `REPORT_COOLDOWN` | `0.05` | Yes | Client food hit report cooldown. |
| `FoodService` `HIT_REQUEST_COOLDOWN` | `0.06` | Yes | Server food report cooldown. |
| `FoodCollisionClient` `MINOR_DESYNC`, `MAJOR_DESYNC` | `4`, `12` | Yes | Food rejection rollback correction thresholds. |
| `FoodService` `VALIDATION_EPSILON`, `MAX_ALLOWED_SPEED`, `Y_TOLERANCE`, `MOTION_HISTORY_WINDOW` | mixed | Yes | Server food hit plausibility checks. |
| `RemoteContracts` validators | type checks | Yes | Used by `SlingService`; partially not used by `FoodService:Start` for `ReportFoodHit`. |

## Can unused constants be removed?

Safe removal depends on whether external Studio-authored scripts or future branches rely on them. Based strictly on this repository:

- **Likely safe to remove after a deprecation pass:** unused `PhysicsConfig.Charge.*`, unused `PhysicsConfig.Collision.*`, old `Config` launch constants, `BalanceConfig` legacy launch constants, and unused `LaunchModelConfig.Charge.MinSeconds`. They are not referenced by current code.
- **Do not remove without replacing client/server UI dependencies:** `SlingshotConfig.MAX_CHARGE_TIME` and `RECOVER_TIME` are used by client UI even though they do not match server launch authority. Prefer aligning UI to server config or sending server timing before removing.
- **Do not remove only because a helper is unused:** `BalanceConfig.BaseImpactForce`, `KnockbackFactor`, and `MaxKnockback` are only used by an unused function (`ComputeCollisionKnockback`). Remove them only if the function is removed or the current collision pipeline intentionally never uses additive knockback.
- **Do not remove physical property constants currently applied to roots/templates:** `PhysicsConfig.PhysicalProperties`, `PhysicsConfig.Movement`, `PhysicsConfig.Stability`, `Config.Mass`, and `Config.SlingScale` are used.

# 10. Architecture Evaluation

## Strengths

- Server owns launch state, launch velocity during `Launching`, player collision resolution, player HP damage, death, and food validation.
- Launch model is centralized in `LaunchMotionModel`, making initial speed/energy/duration and time decay easy to inspect.
- Player collision response is deterministic code math rather than relying on uncontrolled Roblox contact impulses.
- Food reports have practical anti-lag validation: server distance, swept path, motion history, ping expansion, Y tolerance, speed cap, state checks, and rejection feedback.
- Event separation is mostly clear: `CollisionService` resolves physics/events; `DamagePipelineService` applies HP/death.

## Weak points

- Server and client charge timing are inconsistent: server uses `LaunchModelConfig.Charge.MaxSeconds = 1.4`, while charge UI uses `SlingshotConfig.MAX_CHARGE_TIME = 2.0`.
- `CollisionService` imports `PhysicsConfig` but does not use it; `PhysicsConfig.Collision` values duplicate client food prediction constants without being the source of truth.
- Player-vs-player collision cooldown starts on distance candidate, not on accepted damaging collision.
- `CollisionService:_applyDragAndBounce` and `SlingService:_stepMovementStates` can both overwrite launch horizontal velocity each heartbeat.
- Active launch state is stored in `SlingService._activeLaunches` but directly mutated by `CollisionService`, creating private-field coupling.
- `MovementController.server.lua` is a second `MoveRequest` listener outside the service architecture and may conflict with `SlingService` in Roblox runtime.
- Food collision has two authoritative-ish server paths (heartbeat polling and remote report), with different response formulas for HP food.
- Player collision source of truth is server, but there is no explicit player collision client prediction/reconciliation path despite the Rule_Design target.

## Redundant logic

- Two server movement systems: `SlingService` + `SlingMovement` and standalone `MovementController.server.lua`.
- Food bounce constants exist as local client constants, local server constants, and unused `PhysicsConfig.Collision` config values.
- Common/HP food collision can be resolved by server polling or client report, leading to duplicated validation/response flow.
- `SlingService.CalculateChargeRatio` exists but current release uses `LaunchMotionModel.ComputeChargeRatio`.
- `SlingService.BuildLaunchVector` exists but current launch writes velocity from `launchState.direction * initialSpeed` directly.

## High coupling areas

- `CollisionService` reaches into `SlingService._activeLaunches` directly to read/write launch state.
- `FoodCollisionClient` rollback depends on `GameplayFeedback` rejection shape from `FoodService`.
- `DamagePipelineService` depends on collision metadata keys produced by `CollisionService`.
- Client cooldown UI depends on state fields (`CooldownEndTime`, `LastReleaseDuration`) set by `SlingService`.

## Potential desync or tuning issues

- Charge UI can show a different full-charge timing than the server actually uses.
- Server launch speed is overwritten by launch sampling, drag can also overwrite it, and collision can reset `startTime`; tuning one value may have hidden effects.
- Passive energy decay compounds because sampled energy is written back into launch state each frame.
- Food rejection rollback restores client pre-prediction position, not the server's authoritative position.
- `SlingshotConfig.SlingConfig.BaseDamage = 211000` is far above collision clamps; tuning base damage may appear ineffective until clamps are adjusted.

# 11. Refactor Suggestions (based on Rule_Design)

Rule_Design states that physics/combat should follow client-side prediction plus server authority, with server validation and applied force clamped by `PhysicsConfig.lua`. The suggestions below stay within the current service/event architecture.

## 1. Make one launch config source of truth

- **Problem:** Server launch charge uses `LaunchModelConfig.Charge.MaxSeconds = 1.4`; client UI uses `SlingshotConfig.MAX_CHARGE_TIME = 2.0`. Several old launch force constants are unused.
- **Alignment with Rule_Design:** Improves source-of-truth clarity for charge → launch and reduces fake client feedback.
- **Gameplay impact:** Charge bar and actual launch strength match; tuning charge duration becomes predictable.
- **Risk level:** Low/medium. Requires client access to shared config or replicated server timing. Avoid moving server-only modules into client if they live under `ServerScriptService`.

## 2. Move accepted-collision cooldown update after impact validation

- **Problem:** `CollisionService:_detectPlayerCollisions` records pair cooldown before `_resolvePlayerCollisions` checks impact speed and active launch state.
- **Alignment with Rule_Design:** Better supports “damage once at impact” without non-impact overlaps consuming the hit window.
- **Gameplay impact:** Fewer missed valid launch hits when players are already close.
- **Risk level:** Low. Keep the same cooldown duration, but set it only after an accepted collision or maintain separate candidate/damage cooldowns.

## 3. Add a public `SlingService` launch-state API instead of mutating `_activeLaunches` from `CollisionService`

- **Problem:** `CollisionService` directly reads/writes `slingService._activeLaunches`, coupling collision math to a private table.
- **Alignment with Rule_Design:** Keeps server authority while making launch state mutation explicit and safer.
- **Gameplay impact:** No intended gameplay change; reduces regression risk for collision transfer and chain hits.
- **Risk level:** Medium. Need to preserve current behavior exactly: direction, speed, energy, start time reset, source player, collision count.

## 4. Consolidate food collision response constants

- **Problem:** `PhysicsConfig.Collision.HitstopSeconds`, `ImpactAbsorption`, and `BounceRetention` are unused, while `FoodCollisionClient` has duplicate local values. `FoodService` has separate local reflection damping constants.
- **Alignment with Rule_Design:** Rule_Design explicitly describes hitstop/bounce values and says applied force should be clamped/configured.
- **Gameplay impact:** Makes food hit feel tunable from one place and easier to keep server/client close.
- **Risk level:** Medium. Client cannot require `ServerScriptService/Config/PhysicsConfig.lua`; use a shared config module or replicate only needed values.

## 5. Disable or fold `MovementController.server.lua` into `SlingService`

- **Problem:** There are two server-side `MoveRequest` listeners that can create/control different `LinearVelocity` instances.
- **Alignment with Rule_Design:** Reduces redundant movement authority and clarifies the server truth layer.
- **Gameplay impact:** More predictable movement/launch transitions; fewer actuator conflicts.
- **Risk level:** Medium. Verify Roblox runtime actually includes this script and test movement after removal/disable. If it is a legacy fallback, mark it clearly or remove it.

## 6. Use server-provided correction data for food-hit rejection

- **Problem:** Rejection rollback uses the client's cached `beforePosition`, not server authoritative root position/velocity.
- **Alignment with Rule_Design:** Matches the stated reconciliation rule: invalid prediction should resync to server state.
- **Gameplay impact:** Better anti-exploit correction and less drift after rejected food hits.
- **Risk level:** Medium. Sending exact server CFrame/velocity in rejection payload must be rate-limited and only sent to the owning client.

## 7. Not recommended: replace current player collision with Roblox `.Touched` only

- **Problem:** `.Touched` would be simpler, but current code intentionally does deterministic server distance checks and custom response math.
- **Alignment with Rule_Design:** Not aligned. Rule_Design calls for server validation and controlled collision behavior, not raw engine contact as the only source.
- **Gameplay impact:** Could introduce noisy multi-hit contacts and non-deterministic physics feel.
- **Risk level:** High. Not recommended.

## 8. Not recommended: move player damage authority to client prediction

- **Problem:** It would reduce perceived latency but conflicts with current `DamagePipelineService` authority and anti-exploit goals.
- **Alignment with Rule_Design:** Not aligned. Rule_Design says client predicts feedback but does not decide final outcome.
- **Gameplay impact:** High exploit risk for HP/damage.
- **Risk level:** High. Not recommended.

# 12. Summary

## Current system in 5–10 bullets

- Launch is server-authoritative and applied by direct `AssemblyLinearVelocity` assignment, not by a Roblox force object.
- Launch strength is based on `LaunchMotionModel` charge ratio, speed, duration, and energy values.
- During launch, normal locomotion `LinearVelocity` controllers are disabled and root network ownership is set to the server.
- Launch speed decays over time through `LaunchMotionModel.Sample`, while global drag and wall bounce also mutate horizontal velocity.
- Player-vs-player collision is server pairwise distance polling with custom velocity/energy response and transfer, not raycast/touched/overlap APIs.
- Player collision damage is computed by `DamagePipelineService` from impact speed, launch energy, elapsed launch time, and collision count, then clamped.
- Food collision has client prediction plus server validation/rejection, and also a server polling collision loop.
- Food rejection rollback restores client pre-prediction velocity/position thresholds, not a server-provided position.
- Several old physics/launch constants exist but are unused by current launch/collision code.
- Current code only partially implements the Rule_Design client prediction model; player-vs-player physics is mainly server-driven.

## High-priority refactor recommendations

1. Align server and client charge timing/config so the charge bar matches actual launch strength.
2. Remove or disable the duplicate `MovementController.server.lua` path after verifying `SlingService` covers all movement needs.
3. Move player collision cooldown recording to accepted impacts or split candidate cooldown from damage cooldown.
4. Replace direct `CollisionService` mutation of `SlingService._activeLaunches` with a small public launch-state API.
5. Consolidate hitstop/bounce/food collision constants into a shared source and remove unused legacy constants after a deprecation pass.

## Open Questions / Ambiguous Areas

- `MovementController.server.lua` is outside the service bootstrap but likely still runs as a normal Roblox `Script` under `ServerScriptService`; if Studio disables it or Rojo maps it differently, the duplicate movement concern changes.
- `MaxChargeReleased` is fired by `SlingService`, and `DamagePipelineService:ApplySelfDamage` exists, but no listener for `MaxChargeReleased` was found in this repository. If a Studio-only script listens to it, max-charge self damage may exist outside source control.
- `PhysicsConfig.Collision` values match Rule_Design hitstop/bounce concepts, but current client prediction uses local constants instead. It is unclear whether this is an unfinished migration or intentional duplication.
