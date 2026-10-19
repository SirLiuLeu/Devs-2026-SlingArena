# SlingArena Runtime Context

`LauncherConfig.lua` currently defines five Launcher models: `Normalduck`, `Kingduck`, `Witchduck`, `Drakeduck`, and `Shielduck`. Five is the current catalog size, not a fixed limit for future additions; runtime lookup should use `LauncherConfig.GetAllIds()`/`GetById()` rather than assume a permanent count.

# Client → Server (Actions)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| MoveRequest | C->S | LauncherService | `{ direction: Vector3 }` | Continuous movement intent input from client. |
| StartCharge | C->S | LauncherService | `{ aimTarget: Vector3 }` | Begin charge sequence for launcher launch. |
| ReleaseCharge | C->S | LauncherService | `{ aimTarget: Vector3 }` | Release charged launcher launch. |
| RequestLaunch | C->S | LauncherService | `{ aimTarget: Vector3, chargeRatio?: number }` | Canonical alias for launch request contract (freeze-required; map to StartCharge/ReleaseCharge flow). |
| JoinArena | C->S | RoundService | `{}` | Player requests arena participation. |
| LeaveArena | C->S | RoundService | `{}` | Player exits arena participation. |
| TeleportRequest | C->S | MapService | `{ mapName: string, spawnName: string }` | Legacy debug contract; current `MapService:RequestTeleport` is a stub and does not teleport players. Do not expose as a production feature. |
| AbilityTrigger | C->S | LauncherAbilityService | `{ abilityId: string, phase: "Start"\|"Commit"\|"Cancel", target?: Vector3, contextId?: string }` | Ability activation intent routed to ability orchestrator. |
| EquipPet | C->S | PetService | `{ instanceId: string, slot?: number|string }` | Equip an owned Pet instance; the server validates ownership and slot selection. |
| UnequipPet | C->S | PetService | `{ slot: number|string }` | Unequip the Pet occupying the requested slot. |
| UpgradePet | C->S | PetService | `{ instanceId: string, expectedLevel: number }` | Server-authoritative Pet upgrade; the server verifies the expected level and commits the cost/result. |
| EquipLauncher | C->S | LauncherInventoryService | `{ instanceId: string }` | Equip an owned Launcher instance by instance ID. |
| UnequipLauncher | C->S | LauncherInventoryService | `{}` | Clear the selected Launcher equip state, subject to server validation. |
| ChangeTeam | C->S | TeamService | `{ teamId: string }` | Request a team change; server validates team ID, capacity, round state and cooldown. |
| AttributeUpgrade | C->S | PlayerStateService | `{ attributeName: string }` | Spend attribute point on selected stat. |
| ConsumeHpPotion | C->S | PlayerStateService | `{}` | Consume HP potion request. |
| RequestRespawn | C->S | MonetizationService | `{ mode: "Free" }` | Request free respawn flow. |
| PurchaseRespawn | C->S | MonetizationService | `{}` | Purchase paid respawn with diamonds. |
| PurchaseMatchBuff | C->S | MonetizationService | `{}` | Purchase in-match buff with diamonds. |
| PrestigeReset | C->S | MonetizationService | `{}` | Prestige reset request. |
| DebugSpawnFood | C->S | MapService | `{ mapName: string }` | Studio/debug contract only; the current `MapService:DebugSpawnFood` method is a stub. |
| DebugResetLauncher | C->S | PlayerService | `{}` | Studio-only debug reset; server ignores requests outside Studio. |
| SellLauncher | C->S | LauncherInventoryService | `{ instanceId: string }` | Sells an eligible owned Launcher instance; the server decides eligibility and payout. |

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
| PetProjectileVisual | S->C | PlasmaCannon / SlowBlaster | `Spawn` or `End` visual message | Client-local projectile cosmetics; hit/damage/Slow remain server-authoritative. |

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
| `AbilityConfig.lua` | Launcher ability tuning and per-ability lookup helpers. | `LauncherAbilityService` |
| `BalanceConfig.lua` | Core balance constants for combat, collisions, growth, launch, respawn, food, and economy values. | `LauncherService`, `GrowthService`, `PlayerStateService`, `CollisionService`, `DamagePipelineService`, `FoodService`, `LevelConfig` |

| `ConfirmationTextConfig.lua` | Shared confirmation and team-feedback messages, with `vi`/`en` lookup and placeholder substitution. | `TeamSelectionUIController`, `UIController`, `LauncherInventoryUIController` |
| `DebugConfig.lua` | Debug and diagnostic feature flags. | client and server diagnostics |
| `GachaRewardConfig.lua` | Gacha reward entries (id/type/weight/icon/name/teamBonus) and reward accessor. | `GachaSpinLogic`, `SpinUIController`, `GachaSpinLogicTests` |
| `GameConfig.lua` | Runtime flag durations, stacking/tick behavior and status-effect visual configuration. | `FlagService`, `PlayerStateService` |
| `ItemConfig.lua` | Item catalog (`Items`) with metadata (`id`, `name`, `effect`, `icon`, `stackable`) and lookup helpers. | `InventoryUIController`, `InventoryDataProvider`, `RewardRoller`, `MockData`, `RewardGenerationTests` |
| `LevelConfig.lua` | Level progression settings and `RequiredExp` formula (via `BalanceConfig`). | `PlayerStateService`, `UIController` |
| `PetAbilityProgressionConfig.lua` | Ability parameters at levels 1/5/10/15/20 plus `Display = { Format, Templates = { en, vi } }` localization data. | `PetProgression`, `PetDisplayFormatter` |
| `PetPreviewConfig.lua` | Per-pet viewport camera `Rotation` and `Offset`, accessed through `Get(petId)`. | `InventoryUIController`, `PreviewRenderer` |
| `PetRenderConfig.lua` | Client-side nearby Pet render distance, range-check interval, and exit hysteresis. | `ClientPetController` |
| `PetProjectileRenderConfig.lua` | Client-only projectile visual distance and count cap. | `PetProjectileVisualController.client.lua` |
| `LauncherPreviewConfig.lua` | Per-Launcher viewport camera `Rotation` and `Offset`, accessed through `Get(launcherId)`. | `LauncherInventoryUIController`, `PreviewRenderer` |
| `PetRarityStatsConfig.lua` | Base HP and damage values by pet rarity. | `PetProgression`, pet UI |
| `PetsConfig.lua` | Pet definition catalog, ability IDs, rarity, and max-level settings. | `PetService`, `PetProgression`, `InventoryUIController` |
| `PetsUpgradeConfig.lua` | Level normalization, costs, 10% per-level base-stat growth, and milestone predicates. | `PetService`, `PetProgression`, `PetDisplayFormatter` |
| `LauncherConfig.lua` | Current five Duck Launcher definitions (`Normalduck`, `Kingduck`, `Witchduck`, `Drakeduck`, `Shielduck`), default ID, combat stats, weight, reflect damage, and lookup helpers. Future catalog size is not fixed. | `PlayerStateService`, `LauncherStatResolver`, launcher inventory/shop and mock data |
| `TrapConfig.lua` | Trap tuning constants (EXP penalty, cooldown, count, color). | `TrapService` |
| `PhysicsConfig.lua` | Centralized movement, launch, collision and physics thresholds. | `LauncherService`, `CollisionService`, `DamagePipelineService` |
| `SafeZoneConfig.lua` | Safe Zone radius, shrink, relocation and replicated attribute names. | `SafeZoneService`, `SafeZoneVisualizer.client.lua` |
| `TeamConfig.lua` | Team IDs, colors, capacity, change cooldown and Rage timing. | `TeamService`, team selection UI, `RoundService` |
| `LauncherTextureConfig.lua` | Team/Rage texture IDs for equipped Launcher visuals. | `PlayerService` |
| `QuestConfig.lua` | Quest definitions and progress requirements. | `QuestService`, quest UI |
| `RankConfig.lua` | Rank/leaderboard progression settings. | leaderboard/progression services |

## Pet Inventory progression UI

- The pet details level label is `StarterGui/InventoryUI/Root/BodyPets/RightPanel/Stats/Level`; `ProjectTreeSpec.UI.Inventory.PetsStatLevel` is the code path used to bind it.
- `PetDisplayFormatter.Format(definition, level, previewNextLevel, languageCode)` is presentation-only and returns `LevelText`, `HPText`, `DamageText`, and `ScriptText`. It selects the localized ability template by locale (with an English fallback) and encodes every RichText arrow as `-&gt;`.
- Base HP and damage grow at every level. Most ability parameters change at levels 1, 5, 10, 15, and 20; Titan weight/hitbox/visual multipliers are calculated at every level. The first Upgrade click previews base-stat changes; milestone-based ability text changes only when the next level is one of those milestones. The second click submits the upgrade, disables the button until a server result, and all selection/tab/hide/result events clear the preview.

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

## Launcher inventory viewport migration update (2026-09-10)

- `LauncherInventoryUIController` renders the Studio-authored `LauncherSlotTemplate_LauncherInventoryUI.Root.EquipmentPreview` `ViewportFrame` through `PreviewRenderer`, using models from `ReplicatedStorage.Assets.Launchers`.
- Generated launcher slots store `CurrentRenderedId`; the renderer only recreates a viewport preview when that launcher id changes. Snapshot refreshes while the panel is disabled are cached and rendered when it becomes visible.
- Controller destruction disconnects slot events and destroys every slot retained in `_slotMap`, releasing each cloned preview model and camera.


## Team/Rage, knockback, preview, and reflect update (2026-10-16)

- `TeamService` assigns active round participants to four balanced teams (`White`, `Yellow`, `Blue`, `Red`), syncs canonical `PlayerState.TeamId` with Roblox `Player.Team`, enforces 10 players per team, and accepts team changes with a 30-second successful-change cooldown.
- `RoundService` activates Rage/FFA at 480 elapsed round seconds independently of the Safe Zone's transition to `FinalPhase`; the `UIStateUpdate` payload exposes `RageActive`. Team identity remains in player state while friendly-fire checks are disabled during Rage.
- `DamagePipelineService` owns the friendly-damage query and rejects same-team direct and player-sourced DoT damage. `CollisionService` uses that query before emitting knockback, so a teammate collision is blocked before physical knockback/effect dispatch.
- `LauncherConfig` already resolves each Launcher `weight` to `PlayerState.Weight`; collision knockback now applies the attacker/defender weight ratio, capped at 1.4, and a global velocity cap.
- `LauncherPreviewConfig` and `PetPreviewConfig` expose per-model `Scale` (default 1). `PreviewRenderer` adjusts preview camera distance from this value instead of changing runtime model size.
- `PetStatResolver` now includes equipped pet `statModifiers.Add.reflectDamage` in the derived reflect stat, clamped to 50%. The damage pipeline also processes attacker death if reflected damage is lethal.
- `TeamConfig` and `LauncherTextureConfig` define four teams, a 10-player cap, and shared texture slots for White/Yellow/Blue/Red/Rage. `TeamSelectionUIController` binds the Studio-authored `StarterGui.TeamSelectionGui` and sends validated `ChangeTeam` requests; texture IDs are configured and still need visual verification in Studio.
- `PlayerService` applies configured team/Rage textures to each equipped Launcher model and applies team colors to world HP bars. Rage switches Roblox team membership to neutral while preserving `PlayerState.TeamId` for scoreboard/history.
- `LauncherConfig.control`, `maxShootRange`, `PlayerState.LaunchRange`, and the unused Range stat were removed. The Launcher inventory reuses its existing Range label to display Weight.
- Hydra's Titan passive scales weight (1.5%/pet level, with +0.5% at level 20) and hitbox (+2%/pet level, capped at 1.5x). Launcher visual scale starts at 1x when Titan becomes active and grows +4% per player level earned while Titan is equipped, capped at 2x; prior player levels do not count. The modifier log prints only when the actual Launcher model scale changes.
- Octopus PlasmaCannon and Dragon SlowBlaster use server-simulated projectiles with server-side swept-sphere hit checks and authoritative damage/Slow. Clients render local anchored visuals with RenderStepped interpolation through `LauncherArenaRemotes.PetProjectileVisual`; distance and per-client caps limit local rendering. The `Assets.Prefabs.PlasmaBall` and `SlowBall` prefab instances remain Studio assets and must be present after Rojo sync.
- Only the first equipped pet with `activeAbilityId` controls the single SkillButton. Active ability dispatch checks `activeAbilityId` on the server, separate from passive/effect identity.


## Implementation update (2026-10-17)

- Team selection uses the shared ConfirmationUIController and ConfirmationTextConfig; the confirmation copy supports Vietnamese/English. Team counts use the replicated Player.TeamId attribute, full teams flash red twice, and ToggleBtn shows the current team name/color when it is a TextButton.
- PlayerService:_applyTeamTexture intentionally inspects only direct children of the equipped Launcher model (GetChildren()), per the agreed asset requirement. Texture changes on nested descendants are not applied.
- Octopus PlasmaCannon and Dragon SlowBlaster scan for valid targets on a 0.5-second interval and auto-trigger when their cooldown is ready. PetAbilityService no longer listens for click-driven active-Pet triggers. Successful attacks log [PET_ABILITY_ACTIVATED].
- PlayerStateService:SyncPetFromData replicates equipped Pet IDs as Player attributes. ClientPetController creates local Pet visuals only for players within PetRenderConfig.NearbyRenderDistance and destroys remote visuals when they move out of range.
- UnitTestUI.RootFrame.LevelUp5 is wired through ProjectTreeSpec, LobbyClientService, and a Studio-only DebugLevelUp5 RemoteEvent; the server grants up to five levels and fires the normal LevelUp events.
- Runtime status: these changes have been source-reviewed against the repository, but have not been executed in Roblox Studio in this pass. Verify the Team GUI/Teams instances, all Launcher textures, Assets.Prefabs.PlasmaBall and SlowBall, level-up growth, and two/multi-client nearby-Pet behavior in Studio.


## Implementation update (2026-10-18)

- Launcher inventory uses the Studio-authored `LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.EquiptButton` and `SellButton`. Any owned, unexpired Launcher can be sold regardless of duplicate status; the default and currently equipped instances remain protected. Permanent sale prices in `LauncherConfig`: Normalduck 1, Kingduck 2, Witchduck 2, Drakeduck 3, Shielduck 3 Diamonds. Time-limited Launcher sale price is fixed at 5 Diamonds. The server remains authoritative for eligibility/pricing and removes the instance + grants Diamonds in one PlayerData mutation.
- Launcher Equip writes the selected owned instance to `EquippedLauncherInstanceId`, synchronizes runtime state/stats, and refreshes the live Launcher model in the same server request when a Launcher pawn exists. A Human-mode player retains the equipped selection; the visual is applied when a Launcher pawn is spawned. The client consumes `LauncherEquipResult` and `LauncherSellResult` feedback and displays localized success/failure toasts.
- Team-change rejection logs are detailed for `InvalidRequest`, `InvalidTeam`, `Cooldown`, and `RageActive`; remaining rejection reasons use compact logs. `ChangeTeam` validates payload shape separately from known team IDs so unknown string IDs are classified as `InvalidTeam`.
- Pet projectile visuals are client-local and distance/cap gated; server simulation and hit resolution remain authoritative. The new `PetProjectileVisual` RemoteEvent and `PetProjectileRenderConfig` are source-controlled.
- Runtime validation is still required in Roblox Studio, including SellButton UI presence, timed Launcher lifecycle, multi-client projectile visibility/hit accuracy, team rejection logs, and Titan scaling/log frequency.

## Launcher inventory, team diagnostics, and food placement update (2026-10-19)
- `Main.server.lua:runServicePhase` runs each service phase once and warns instead of throwing a second invocation or crashing bootstrap on a phase error. This avoids duplicate RemoteEvent listeners and conflicting action feedback.
- Launcher sale no longer requires permanent duplicates. Client checks protect the default/equipped/expired items and positive sale price; server independently verifies ownership, protects the default/equipped instances and expired timed items, and computes the authoritative payout.
- Launcher Inventory logs every button request, client-side eligibility block, confirmation result, remote request, server result, and missing-feedback timeout. Sell is allowed for eligible owned permanent or temporary Launchers regardless of duplicate status; the default, currently equipped, and expired instances remain protected. The server remains authoritative for ownership, expiry, and payout.
- Team switching prints the exact source and target team used to build the confirmation message, logs Confirm/Cancel, and keeps the request target captured in the callback. ConfirmationUIController binds Confirm/Cancel once, hides both the root and ScreenGui after either action, and warns with authored paths when the GUI, text, Confirm, or Cancel controls are missing.
- Food placement rejects candidate positions inside `FoodConfig.MinPlayerSpawnClearance` plus the food/player hitbox radii for alive non-Lobby players. Food models are positioned before being parented into `FoodContainer`; blocked batches retry after 2 seconds up to 3 times, with pending retries invalidated when map food is cleared.
- Validation note: changes were reviewed statically against the source. Live Roblox Studio/multi-client runtime tests have not been run in this implementation pass.
