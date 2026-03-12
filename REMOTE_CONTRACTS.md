# Remote Contracts

| Remote | Direction | Payload | Owner Service |
|---|---|---|---|
| MoveRequest | Client -> Server | `moveDirection: Vector3` | SlingService |
| StartCharge | Client -> Server | `aimTarget: Vector3` | SlingService |
| ReleaseCharge | Client -> Server | `aimTarget: Vector3` | SlingService |
| JoinArena | Client -> Server | none | RoundService |
| LeaveArena | Client -> Server | none | RoundService |
| TeleportRequest | Client -> Server | `mapName: string, spawnName: string` | MapService |
| AttributeUpgrade | Client -> Server | `attributeName: string` | SkillService |
| ActivateSkill | Client -> Server | `skillId: string?` | SkillService |
| RequestRespawn | Client -> Server | `respawnType: string` | MonetizationService |
| RequestMatchBuff | Client -> Server | `buffType: string?` | MonetizationService |
| UIStateUpdate | Bidirectional | state table | RoundService |
| PurchaseRespawn | Client -> Server | none | MonetizationService |
| PurchaseMatchBuff | Client -> Server | none | MonetizationService |
| PrestigeReset | Client -> Server | none | MonetizationService |
| ToggleSpecialUpgrade | Client -> Server | `active: boolean` | SkillService |
| DebugSpawnFood | Client -> Server | `mapName: string` | MapService |
| DebugResetSling | Client -> Server | none | PlayerService |
| StateUpdate | Server -> Client | full PlayerState table | PlayerStateService |
| GameplayFeedback | Server -> Client | feedback table `{Type, Amount, Source?, CurrentHP?}` | DamagePipelineService |
| MatchStateUpdate | Server -> Client | `{State: string, RoundId: number}` | RoundService |
| RoundResult | Server -> Client | `{Winner: string, RoundId: number}` | RoundService |
| PopupMessage | Server -> Client | `{Type: string, Text: string}` | TrapService |

## Schemas

### MoveRequest
- Direction: Client -> Server
- Payload: `{ moveDirection: Vector3 }`
- Validation: Vector3 only; server normalizes magnitude <= 1; player must be alive, queued, and not charging/recovering.

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
- Validation: player identity comes from Roblox sender; RoundService controls participation + teleports.

### TeleportRequest
- Direction: Client -> Server
- Payload: `{ mapName: string, spawnName: string }`
- Validation: strings only; denied during countdown/active round; map/spawn instances must exist; corridor size rule enforced.

### AttributeUpgrade
- Direction: Client -> Server
- Payload: `{ attributeName: string }`
- Validation: attribute name must be string and spend is server-authoritative.

### ActivateSkill
- Direction: Client -> Server
- Payload: optional skill payload
- Validation: currently reserved hook; server ignores invalid usage safely.

### RequestRespawn / PurchaseRespawn
- Direction: Client -> Server
- Payload: `respawnType: string` (request) / none (purchase)
- Validation: MonetizationService enforces diamond cost, limits, and round state.

### RequestMatchBuff / PurchaseMatchBuff
- Direction: Client -> Server
- Payload: optional buff identifier / none
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
- Payload: canonical PlayerState snapshot for that player.

### GameplayFeedback
- Direction: Server -> Client
- Payload: `{ Type: string, Amount: number, Source?: string, CurrentHP?: number }`.

### MatchStateUpdate
- Direction: Server -> Client
- Payload: `{ State: "Lobby"|"PreRound"|"Countdown"|"ActiveRound"|"RoundEnd"|"PostRound", RoundId: number }`.

### RoundResult
- Direction: Server -> Client
- Payload: `{ Winner: string, RoundId: number }`.

### PopupMessage
- Direction: Server -> Client
- Payload: `{ Type: string, Text: string }`.
