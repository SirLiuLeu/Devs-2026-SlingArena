# Remote Contracts

## Authoritative production RemoteEvents

All production remotes must exist statically under `ReplicatedStorage.SlingArenaRemotes` via Rojo `*.model.json` files. Test-only remotes may still be created at runtime inside isolated unit tests.

| Remote | Direction | Payload | Owner service | Purpose |
|---|---|---|---|---|
| MoveRequest | Client -> Server | `moveDirection: Vector3` | SlingService | Movement input for WASD locomotion. |
| StartCharge | Client -> Server | `aimTarget: Vector3` | SlingService | Starts a sling charge from validated player input. |
| ReleaseCharge | Client -> Server | `aimTarget: Vector3` | SlingService | Releases a validated charge and launches the pawn server-side. |
| JoinArena | Client -> Server | none | RoundService | Queue the player into the arena flow. |
| LeaveArena | Client -> Server | none | RoundService | Remove the player from the arena flow and return to lobby. |
| TeleportRequest | Client -> Server | `mapName: string, spawnName: string` | MapService | Requests an allowed manual teleport outside active rounds. |
| AttributeUpgrade | Client -> Server | `attributeName: string` | SkillService | Spend attribute points server-side. |
| RequestRespawn | Client -> Server | `respawnType: string` | MonetizationService | Request the free respawn path. |
| PurchaseRespawn | Client -> Server | none | MonetizationService | Purchase a paid respawn. |
| PurchaseMatchBuff | Client -> Server | none | MonetizationService | Purchase the configured match buff package. |
| PrestigeReset | Client -> Server | none | MonetizationService | Reset progression for prestige rewards. |
| ToggleSpecialUpgrade | Client -> Server | `active: boolean` | SkillService | Enable or disable the server-owned special upgrade state. |
| DebugSpawnFood | Client -> Server | `mapName: string` | MapService | Debug-only food spawn utility. |
| DebugResetSling | Client -> Server | none | PlayerService | Debug-only pawn reset utility. |
| StateUpdate | Server -> Client | canonical `PlayerState` table | PlayerStateService | Replicates authoritative player state, including charge/cooldown lifecycle. |
| UIStateUpdate | Server -> Client | round UI state table | RoundService | Publishes round/lobby UI state only. |
| GameplayFeedback | Server -> Client | feedback table `{ EventType, Payload }` | DamagePipelineService | Sends combat feedback such as damage and level-up events. |
| MatchStateUpdate | Server -> Client | `{ State: string, RoundId: number }` | RoundService | Announces round state transitions. |
| RoundResult | Server -> Client | `{ Winner: string, RoundId: number }` | RoundService | Announces the round winner. |
| PopupMessage | Server -> Client | `{ Type: string, Text: string }` | TrapService | Sends popup text such as trap hit messages. |

## Removed from production contract

| Remote | Reason removed |
|---|---|
| ActivateSkill | No production code binds or fires it. Keeping a static remote for an inert path made the remote set misleading. |
| RequestMatchBuff | No production code binds or fires it. `PurchaseMatchBuff` is the active match-buff remote in the current implementation. |

## Validation notes

### MoveRequest
- Direction: Client -> Server
- Payload: `{ moveDirection: Vector3 }`
- Validation: Vector3 only; server normalizes magnitude `<= 1`; player must be alive, queued, and not charging/recovering.

### StartCharge
- Direction: Client -> Server
- Payload: `{ aimTarget: Vector3 }`
- Validation: Vector3 only; round must be active; player alive; release cooldown must be finished.

### ReleaseCharge
- Direction: Client -> Server
- Payload: `{ aimTarget: Vector3 }`
- Validation: Vector3 only; player must already be charging; launch force and velocity are server-computed and clamped.

### JoinArena / LeaveArena
- Direction: Client -> Server
- Payload: none
- Validation: player identity comes from Roblox sender; RoundService controls participation and teleports.

### TeleportRequest
- Direction: Client -> Server
- Payload: `{ mapName: string, spawnName: string }`
- Validation: strings only; denied during countdown/active round; map/spawn instances must exist; size gate is checked server-side before the teleport succeeds.

### AttributeUpgrade
- Direction: Client -> Server
- Payload: `{ attributeName: string }`
- Validation: attribute name must be string and spend is server-authoritative.

### RequestRespawn / PurchaseRespawn
- Direction: Client -> Server
- Payload: `respawnType: string` (request) / none (purchase)
- Validation: MonetizationService enforces diamond cost, limits, and round state.

### PurchaseMatchBuff
- Direction: Client -> Server
- Payload: none
- Validation: MonetizationService validates affordability and active-round constraints.

### PrestigeReset
- Direction: Client -> Server
- Payload: none
- Validation: PlayerStateService applies capped prestige logic server-side.

### ToggleSpecialUpgrade
- Direction: Client -> Server
- Payload: `{ active: boolean }`
- Validation: SkillService toggles server-owned upgrade state only.

### DebugSpawnFood / DebugResetSling
- Direction: Client -> Server
- Payload: `{ mapName: string }` / none
- Validation: debug-only utility remotes handled server-side with safe guards.

### StateUpdate
- Direction: Server -> Client
- Payload: canonical `PlayerState` snapshot for that player, including `CooldownEndTime` for authoritative cooldown UI sync.

### UIStateUpdate
- Direction: Server -> Client
- Payload: `{ State, ArenaStatus, AlivePlayers, PlayerCount, MapName, TimeLeft, CountdownTimer }`.
- Note: this remote does **not** drive the charge bar or cooldown bar.

### GameplayFeedback
- Direction: Server -> Client
- Payload: `{ EventType: string, Payload: table }`.

### MatchStateUpdate
- Direction: Server -> Client
- Payload: `{ State: "Lobby"|"PreRound"|"Countdown"|"ActiveRound"|"RoundEnd"|"PostRound", RoundId: number }`.

### RoundResult
- Direction: Server -> Client
- Payload: `{ Winner: string, RoundId: number }`.

### PopupMessage
- Direction: Server -> Client
- Payload: `{ Type: string, Text: string }`.
