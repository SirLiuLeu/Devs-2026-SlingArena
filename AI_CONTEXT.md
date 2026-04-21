# Client → Server (Actions)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| MoveRequest | C->S | SlingService | `{ direction: Vector3 }` | Player movement intent. |
| StartCharge | C->S | SlingService | `{ aimTarget: Vector3 }` | Start charge intent. |
| ReleaseCharge | C->S | SlingService | `{ aimTarget: Vector3 }` | Release charge intent. |
| RequestLaunch | C->S | SlingService | `{ aimTarget: Vector3, chargeRatio?: number }` | Canonical launch request contract alias for freeze alignment. |
| JoinArena | C->S | RoundService | `{}` | Join arena queue/flow. |
| LeaveArena | C->S | RoundService | `{}` | Leave arena queue/flow. |
| TeleportRequest | C->S | MapService | `{ mapName: string, spawnName: string }` | Map teleport/debug request. |
| AbilityTrigger | C->S | SlingAbilityService | `{ abilityId: string, phase: "Start"\|"Commit"\|"Cancel", target?: Vector3, contextId?: string }` | Ability input event routed to orchestrator. |
| AttributeUpgrade | C->S | PlayerStateService | `{ attributeName: string }` | Spend attribute point through player-state authority. |
| ConsumeHpPotion | C->S | PlayerStateService | `{}` | Consume HP potion through player-state authority. |
| PurchaseRespawn | C->S | MonetizationService | `{}` | Purchase paid respawn. |
| RequestRespawn | C->S | MonetizationService | `{ mode: "Free" }` | Request free respawn. |
| PurchaseMatchBuff | C->S | MonetizationService | `{}` | Purchase match buff. |
| PrestigeReset | C->S | MonetizationService | `{}` | Prestige reset request. |
| DebugSpawnFood | C->S | MapService | `{ mapName: string }` | Debug spawn food on map. |
| DebugResetSling | C->S | PlayerService | `{}` | Debug reset sling pawn. |

# Server → Client (Sync / Feedback)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| StateUpdate | S->C | PlayerStateService | `{ userId: number, mapName: string, arenaStatus: string, level: number, exp: number, maxHP: number, currentHP: number, movementState: string, cooldownEndTime: number, ... }` | Authoritative player state snapshot. |
| MatchStateUpdate | S->C | RoundService | `{ state: string, roundId: number }` | Round phase synchronization. |
| UIStateUpdate | S->C | RoundService | `{ state: string, arenaStatus: string, alivePlayers: number, playerCount: number, mapName: string, timeLeft: number, countdownTimer: number }` | Round/UI aggregate sync payload. |
| RoundResult | S->C | RoundService | `{ winner: string, roundId: number }` | Round winner/result payload. |
| GameplayFeedback | S->C | DamagePipelineService | `{ eventType: string, payload: { [string]: any } }` | Combat feedback channel. |
| PopupMessage | S->C | TrapService | `{ type: string, text: string }` | Contextual world/trap popup notifications. |
| ZoneUpdate | S->C | SafeZoneService | `{ phase: string, radius: number, center: Vector3, dpsPercent: number, nextShrinkAt?: number }` | Safe-zone sync payload. |
