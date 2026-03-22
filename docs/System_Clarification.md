# Sling Arena System Clarification

## 1. RemoteEvent audit

### Used production remotes

| Remote | Path | Direction | Current usage |
|---|---|---|---|
| MoveRequest | `ReplicatedStorage.SlingArenaRemotes.MoveRequest` | Client -> Server | `SlingMovement.client.lua` sends locomotion input to `SlingService`. |
| StartCharge | `ReplicatedStorage.SlingArenaRemotes.StartCharge` | Client -> Server | `SlingUIController.client.lua` starts charge; `SlingService` validates and records it. |
| ReleaseCharge | `ReplicatedStorage.SlingArenaRemotes.ReleaseCharge` | Client -> Server | `SlingUIController.client.lua` releases charge; `SlingService` launches server-side. |
| JoinArena | `ReplicatedStorage.SlingArenaRemotes.JoinArena` | Client -> Server | Lobby UI enters the round flow. |
| LeaveArena | `ReplicatedStorage.SlingArenaRemotes.LeaveArena` | Client -> Server | Lobby UI leaves the round flow. |
| TeleportRequest | `ReplicatedStorage.SlingArenaRemotes.TeleportRequest` | Client -> Server | `MapService` handles allowed manual teleports. |
| AttributeUpgrade | `ReplicatedStorage.SlingArenaRemotes.AttributeUpgrade` | Client -> Server | `SkillService` spends attribute points. |
| RequestRespawn | `ReplicatedStorage.SlingArenaRemotes.RequestRespawn` | Client -> Server | `MonetizationService` handles free respawns. |
| PurchaseRespawn | `ReplicatedStorage.SlingArenaRemotes.PurchaseRespawn` | Client -> Server | `MonetizationService` handles paid respawns. |
| PurchaseMatchBuff | `ReplicatedStorage.SlingArenaRemotes.PurchaseMatchBuff` | Client -> Server | `MonetizationService` applies match buffs. |
| PrestigeReset | `ReplicatedStorage.SlingArenaRemotes.PrestigeReset` | Client -> Server | `PlayerStateService` handles prestige resets. |
| ToggleSpecialUpgrade | `ReplicatedStorage.SlingArenaRemotes.ToggleSpecialUpgrade` | Client -> Server | `SkillService` toggles special upgrade state. |
| DebugSpawnFood | `ReplicatedStorage.SlingArenaRemotes.DebugSpawnFood` | Client -> Server | `MapService` debug utility. |
| DebugResetSling | `ReplicatedStorage.SlingArenaRemotes.DebugResetSling` | Client -> Server | `PlayerService` debug utility. |
| StateUpdate | `ReplicatedStorage.SlingArenaRemotes.StateUpdate` | Server -> Client | `PlayerStateService` publishes canonical state, including `CooldownEndTime`. |
| UIStateUpdate | `ReplicatedStorage.SlingArenaRemotes.UIStateUpdate` | Server -> Client | `RoundService` publishes round/lobby UI payloads. |
| GameplayFeedback | `ReplicatedStorage.SlingArenaRemotes.GameplayFeedback` | Server -> Client | `DamagePipelineService` sends combat feedback. |
| MatchStateUpdate | `ReplicatedStorage.SlingArenaRemotes.MatchStateUpdate` | Server -> Client | `RoundService` sends match state transitions. |
| RoundResult | `ReplicatedStorage.SlingArenaRemotes.RoundResult` | Server -> Client | `RoundService` announces the winner. |
| PopupMessage | `ReplicatedStorage.SlingArenaRemotes.PopupMessage` | Server -> Client | `TrapService` sends popup messages. |

### Removed production remotes

| Remote | Reason |
|---|---|
| `ActivateSkill` | Not referenced by production client or server logic. |
| `RequestMatchBuff` | Not referenced by production client or server logic; `PurchaseMatchBuff` is the active implementation. |

## 2. Zone parts clarification

### AntiGiantZone
- **Intended purpose:** a spatial counter-pressure area that punishes or blocks oversized slings so giants cannot dominate every route.
- **Current code usage:** `MapService:Generate()` only collects the parts into `_antiGiantZones`; nothing queries them afterward.
- **Status:** mismatched. The data is discovered, but no rule is enforced.
- **Recommended design:** on server heartbeat or zone touch entry, compare player `Size` against a zone attribute such as `MaxSize` or `DamagePerSecond`; then apply slow, damage, or displacement when the player is too large.

### SafeSpawnZone
- **Intended purpose:** protect freshly spawned players from instant damage or spawn-camping.
- **Current code usage:** `MapService:Generate()` only collects the parts into `_safeSpawnZones`; no immunity, collision filtering, or spawn placement rule consumes them.
- **Status:** mismatched. The zone exists in hierarchy only.
- **Recommended design:** after spawn/teleport, if the player is inside `SafeSpawnZone`, set a short invulnerability window and optionally prevent hostile collisions until the player leaves or the timer expires.

### SizeRestrictedCorridor
- **Intended purpose:** create alternate routes that only smaller players may use.
- **Current code usage:** `MapService:CanPlayerUseCorridors()` checks only global `BalanceConfig.CorridorSizeLimit`, and `RequestTeleport()` blocks teleports when the player is above that size. The actual corridor parts are never spatially checked.
- **Status:** partially implemented but still mismatched. There is a size rule, but it is not tied to corridor geometry.
- **Recommended design:** keep the global size limit as a fallback, but enforce the corridor by testing whether a movement/teleport destination is inside a `SizeRestrictedCorridor` part and then reading a per-part limit such as `MaxSize`.

## 3. Charge system trace

### Exact input mapping
- **Start charge:** `UserInputService.InputBegan` when the input is `MouseButton1` or `Touch`, `gameProcessed` is false, and the screen ray hits the local character model.
- **Update aim/drag:** `UserInputService.InputChanged` for `MouseMovement` and `Touch`.
- **Release charge:** `UserInputService.InputEnded` when the input is `MouseButton1` or `Touch`.

### Full flow
1. Player clicks/touches their sling.
2. `SlingUIController.client.lua` raycasts from the screen point and only accepts the interaction if it begins on the player's own character.
3. Client fires `StartCharge(aimTarget)`.
4. `SlingService:StartCharge()` validates the payload, round state, liveness, and cooldown, then sets `IsCharging = true` and `MovementState = Charging` through `PlayerStateService`.
5. While the input is still held, the client animates `ChargeBar.Fill` locally from elapsed local hold time.
6. Player releases input.
7. Client fires `ReleaseCharge(aimTarget)`.
8. `SlingService:ReleaseCharge()` validates the release, computes charge ratio and launch vector server-side, applies velocity, sets `MovementState = Launched`, and stores `CooldownEndTime` in authoritative player state.
9. `PlayerStateService:PublishState()` sends `StateUpdate` to the owning client.
10. The client reads `StateUpdate.CooldownEndTime` and animates `CooldownBar.Fill` until the authoritative cooldown expires.

### Why the bars were not updating
- `StartCharge` and `ReleaseCharge` were firing correctly.
- `UIStateUpdate` was also unrelated; it only carries round/lobby payloads.
- The real break was UI binding: the LocalScript was named `SlingUI`, which collided with the required `SlingUI` `ScreenGui` path. The resolver could bind to the script instead of the `ScreenGui`, so `ChargeBar.Fill` and `CooldownBar.Fill` were missing.
- A second issue was the hardcoded 2-second UI wait. If the UI clone arrived later than expected, the binder could miss it permanently.

## 4. SlingUI assumptions

- The actual `SlingUI` `ScreenGui` and its child frames are still expected to be authored in Studio/manual assets.
- `UIStateUpdate` is intentionally left as round-state UI only.
- Charge fill remains client-predicted for responsiveness, while cooldown is synchronized from authoritative server state.
