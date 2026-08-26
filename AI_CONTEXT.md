# Client → Server (Actions)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| MoveRequest | C->S | LauncherService | `{ direction: Vector3 }` | Continuous movement intent input from client. |
| StartCharge | C->S | LauncherService | `{ aimTarget: Vector3 }` | Begin charge sequence for launcher launch. |
| ReleaseCharge | C->S | LauncherService | `{ aimTarget: Vector3 }` | Release charged launcher launch. |
| RequestLaunch | C->S | LauncherService | `{ aimTarget: Vector3, chargeRatio?: number }` | Canonical alias for launch request contract (freeze-required; map to StartCharge/ReleaseCharge flow). |
| JoinArena | C->S | RoundService | `{}` | Player requests arena participation. |
| LeaveArena | C->S | RoundService | `{}` | Player exits arena participation. |
| TeleportRequest | C->S | MapService | `{ mapName: string, spawnName: string }` | Admin/debug teleport request. |
| AbilityTrigger | C->S | LauncherAbilityService | `{ abilityId: string, phase: "Start"\|"Commit"\|"Cancel", target?: Vector3, contextId?: string }` | Ability activation intent routed to ability orchestrator. |
| EquipEquipment | C->S | EquipmentService | `{ instanceId: string }` | Server-authoritative equip request for an owned Equipment instance; definition IDs are not accepted as ownership. |
| UnequipEquipment | C->S | EquipmentService | `{ slotType: string }` | Server-authoritative unequip request for an Equipment slot. |
| UpgradeEquipment | C->S | EquipmentService | `{ instanceId: string }` | Server-authoritative upgrade request; cost and result are computed on the server from PlayerData diamonds. |
| AttributeUpgrade | C->S | PlayerStateService | `{ attributeName: string }` | Spend attribute point on selected stat. |
| ConsumeHpPotion | C->S | PlayerStateService | `{}` | Consume HP potion request. |
| RequestRespawn | C->S | MonetizationService | `{ mode: "Free" }` | Request free respawn flow. |
| PurchaseRespawn | C->S | MonetizationService | `{}` | Purchase paid respawn with diamonds. |
| PurchaseMatchBuff | C->S | MonetizationService | `{}` | Purchase in-match buff with diamonds. |
| PrestigeReset | C->S | MonetizationService | `{}` | Prestige reset request. |
| DebugSpawnFood | C->S | MapService | `{ mapName: string }` | Debug force food spawn for map. |
| DebugResetLauncher | C->S | PlayerService | `{}` | Debug reset player launcher pawn/state. |

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

# Controllers (Current)

| Controller | Responsibility | Category |
|---|---|---|
| `InputController.client.lua` | Captures keyboard/touch movement input, right-mouse hold state, computes camera-relative movement direction, and sends `MoveRequest` with aim target. | Input |
| `CameraController.client.lua` | Keeps the local camera in `Custom` mode and sets camera subject to the local pawn root when available. | Input |
| `LauncherUIController.client.lua` | Runs launcher joystick/charge/cooldown HUD behavior and sends `StartCharge` / `ReleaseCharge` remotes from UI input. | UI |
| `UIController.lua` | Composes and starts feature UI controllers, wires top-level hub toggles, and routes snapshot updates into UI. | UI |
| `InventoryUIController.lua` | Renders and updates inventory UI (items/launchers), slot interactions, and equipped launcher preview model. | UI |
| `ShopUIController.lua` | Renders shop tabs/slots and binds buy actions through shop logic service snapshots. | UI |
| `OnlineRewardUIController.lua` | Renders online reward slots/timers and reward-claim UI states from logic snapshots. | UI |
| `DailyLoginUIController.lua` | Renders daily login reward slots and claim/locked/completed states from logic snapshots. | UI |
| `SpinUIController.lua` | Controls spin UI visibility, spin animation, world trigger binding, and spin button interactions. | UI |
| `MovementController.server.lua` | Receives `MoveRequest` from clients, applies pawn linear velocity, and updates facing rotation toward movement direction. | Network |

# Config Data (`ReplicatedStorage/Shared/Config`)

Config modules store shared tuning and content tables (movement/combat constants, level progression formulas, item/launcher catalogs, trap/gameplay values, and gacha reward pools). They are required by both client and server code to keep gameplay math and UI/content lookups consistent across systems.

| Config file | Data it contains | Known users |
|---|---|---|
| `AbilityConfig.lua` | No runtime table currently present (empty file). | usage unclear |
| `BalanceConfig.lua` | Core balance constants for combat, collisions, growth, launch, respawn, food, and economy values. | `LauncherService`, `GrowthService`, `PlayerStateService`, `CollisionService`, `DamagePipelineService`, `FoodService`, `LevelConfig` |
| `Config.lua` | Base gameplay constants (force/charge/physics/arena/player defaults and movement speed). | `LauncherService`, `PlayerService`, `SafeZoneService`, `CollisionService` |
| `FoodConfig.lua` | Placeholder comments for food design fields (EXP/HP/respawn/drop-rate); no exported config table. | usage unclear |
| `GachaRewardConfig.lua` | Gacha reward entries (id/type/weight/icon/name/teamBonus) and reward accessor. | `GachaSpinLogic`, `SpinUIController`, `GachaSpinLogicTests` |
| `GameConfig.lua` | Placeholder comments for player cap/phase/respawn/join rules; no exported config table. | usage unclear |
| `ItemConfig.lua` | Item catalog (`Items`) with metadata (`id`, `name`, `effect`, `icon`, `stackable`) and lookup helpers. | `InventoryUIController`, `InventoryDataProvider`, `RewardRoller`, `MockData`, `RewardGenerationTests` |
| `EquipmentConfig.lua` | Phase 1 Equipment definition catalog with slot/category/rarity/effect/stat-modifier metadata, separate from owned instances. | `EquipmentService`, `EquipmentEffectService`, `EquipmentStatResolver`, `EquipmentFoundationTests` |
| `EquipmentUpgradeConfig.lua` | Reusable Equipment upgrade cost formula (`BaseCost * 1.35^(L-1) * LateGameMultiplier(L)`). | `EquipmentService`, `EquipmentFoundationTests` |
| `LevelConfig.lua` | Level progression settings and `RequiredExp` formula (via `BalanceConfig`). | `PlayerStateService`, `UIController` |
| `LauncherConfig.lua` | Canonical 11-launcher catalog (`Types`) with `NormalLauncher` as `DefaultLauncherId`, per-launcher `modelPath` values under `ReplicatedStorage/Assets/Launchers`, rarity/stats, and lookup helpers. | `InventoryUIController`, `InventoryDataProvider`, `RewardRoller`, `MockData`, `RewardGenerationTests` |
| `LaunchershotConfig.lua` | Launch/charge/recovery constants, launchershot modifiers, and launcher combat baseline values. | `LauncherService`, `PlayerStateService`, `LauncherUIController` |
| `TrapConfig.lua` | Trap tuning constants (EXP penalty, cooldown, count, color). | `TrapService` |

## Recent implementation update (2026-08-21)

- Equipment visuals are Launcher-only: `PlayerService` attaches cloned `Equipment/<Id>/Handle` models exclusively to `Player.Hitbox.EquipmentSlot1..3`, clears them for Human mode, and restores equipped visuals whenever a Launcher pawn is spawned.
- Equipment active-input UI resolves the first equipped definition with an `abilityId` from authoritative `StateUpdate` data and fires `AbilityTrigger` with that id.
- `RoundService` sends an immediate targeted `UIStateUpdate` snapshot to each joining client; Shop UI re-resolves and safely rebinds after `CharacterAdded`.
- Debug lifecycle traces in the Equipment services are reduced/commented with `-- [DEBUG_TRACE]`.

## Equipment foundation reliability update (2026-08-26)

- `EquipmentEffectService` resolves its sibling `EquipmentEffects` folder through `script.Parent`, matching the Rojo hierarchy used by `Main.server.lua`.
- `MockData.MOCK_SCHEMA_DEFAULTS` is the shared fresh-player schema used by `MockProvider`; seeded `PlayerProfiles` remain opt-in fixtures, while new players start with empty equipment slots.
- `EquipmentFoundationTests` records individual failures, completes the suite, and then raises one aggregate failure so CI remains unambiguous.
- `PlayerDataService:_ensureEquipmentData` rebuilds equipped slots in deterministic numeric/legacy-key precedence order instead of mutating the table during `pairs()` iteration.

## Combat equipment investigation update (2026-08-24)

- Server-side `[EQUIPMENT_ATTACK_TRACE]` prints are intentionally enabled across collision validation, `CollisionPlayerHit`, equipment dispatch, Medusa/ThunderHammer/GhostFlame effect handlers, flag application, and the damage pipeline. These traces identify equipment activation/validation, hook dispatch, effect calculations, and early exits while diagnosing collision equipment effects.
