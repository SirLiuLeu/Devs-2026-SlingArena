# Client → Server (Actions)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| MoveRequest | C->S | SlingService | `{ direction: Vector3 }` | Continuous movement intent input from client. |
| StartCharge | C->S | SlingService | `{ aimTarget: Vector3 }` | Begin charge sequence for sling launch. |
| ReleaseCharge | C->S | SlingService | `{ aimTarget: Vector3 }` | Release charged sling launch. |
| RequestLaunch | C->S | SlingService | `{ aimTarget: Vector3, chargeRatio?: number }` | Canonical alias for launch request contract (freeze-required; map to StartCharge/ReleaseCharge flow). |
| JoinArena | C->S | RoundService | `{}` | Player requests arena participation. |
| LeaveArena | C->S | RoundService | `{}` | Player exits arena participation. |
| TeleportRequest | C->S | MapService | `{ mapName: string, spawnName: string }` | Admin/debug teleport request. |
| AbilityTrigger | C->S | SlingAbilityService | `{ abilityId: string, phase: "Start"\|"Commit"\|"Cancel", target?: Vector3, contextId?: string }` | Ability activation intent routed to ability orchestrator. |
| AttributeUpgrade | C->S | SkillService | `{ attributeName: string }` | Spend attribute point on selected stat. |
| ToggleSpecialUpgrade | C->S | SkillService | `{ active: boolean }` | Toggle special-upgrade state for player session. |
| ConsumeHpPotion | C->S | SkillService | `{}` | Consume HP potion request. |
| RequestRespawn | C->S | MonetizationService | `{ mode: "Free" }` | Request free respawn flow. |
| PurchaseRespawn | C->S | MonetizationService | `{}` | Purchase paid respawn with diamonds. |
| PurchaseMatchBuff | C->S | MonetizationService | `{}` | Purchase in-match buff with diamonds. |
| PrestigeReset | C->S | MonetizationService | `{}` | Prestige reset request. |
| DebugSpawnFood | C->S | MapService | `{ mapName: string }` | Debug force food spawn for map. |
| DebugResetSling | C->S | PlayerService | `{}` | Debug reset player sling pawn/state. |

# Server → Client (Sync / Feedback)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| StateUpdate | S->C | PlayerStateService | `{ userId: number, mapName: string, arenaStatus: string, level: number, exp: number, maxHP: number, currentHP: number, movementState: string, cooldownEndTime: number, ... }` | Authoritative per-player state snapshot. |
| MatchStateUpdate | S->C | RoundService | `{ state: string, roundId: number }` | Round phase synchronization. |
| UIStateUpdate | S->C | RoundService | `{ state: string, arenaStatus: string, alivePlayers: number, playerCount: number, mapName: string, timeLeft: number, countdownTimer: number }` | Aggregated round/UI status payload. |
| RoundResult | S->C | RoundService | `{ winner: string, roundId: number }` | End-of-round winner announcement. |
| GameplayFeedback | S->C | DamagePipelineService | `{ eventType: string, payload: { [string]: any } }` | Combat/damage feedback (damage dealt, impact, level-up, etc.). |
| PopupMessage | S->C | TrapService | `{ type: string, text: string }` | Contextual popup notification (trap or gameplay warnings). |
| ZoneUpdate | S->C | SafeZoneService | `{ phase: string, radius: number, center: Vector3, dpsPercent: number, nextShrinkAt?: number }` | Safe-zone visual and damage sync (freeze-required). |

