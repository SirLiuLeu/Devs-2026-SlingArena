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
| DeletePet | C->S | PetService | `{ instanceId: string }` | Delete an owned Pet; the server also removes any equipped-slot reference and recalculates derived stats. |
| UnequipPet | C->S | PetService | `{ slot: number|string }` | Unequip the Pet occupying the requested slot. |
| UpgradePet | C->S | PetService | `{ instanceId: string, expectedLevel: number }` | Server-authoritative Pet upgrade; the server verifies the expected level and commits the cost/result. |
| EquipLauncher | C->S | LauncherInventoryService | `{ instanceId: string }` | Equip an owned Launcher instance by instance ID. |
| UnequipLauncher | C->S | LauncherInventoryService | `{}` | Clear the selected Launcher equip state, subject to server validation. |
| ChangeTeam | C->S | TeamService | `{ teamId: string }` | Request a team change; server validates team ID, capacity, round state and cooldown. |
| AttributeUpgrade | C->S | PlayerStateService | `{ attributeName: string }` | Spend attribute point on selected stat. |
| ConsumeHpPotion | C->S | PlayerStateService | `{}` | Legacy-compatible HP potion consume request. |
| RequestRespawn | C->S | MonetizationService | `{ mode: "Free" }` | Request free respawn flow. |
| PurchaseRespawn | C->S | MonetizationService | `{}` | Purchase paid respawn with diamonds. |
| PurchaseMatchBuff | C->S | MonetizationService | `{}` | Purchase in-match buff with diamonds. |
| PrestigeReset | C->S | MonetizationService | `{}` | Prestige reset request. |
| DebugSpawnFood | C->S | MapService | `{ mapName: string }` | Studio/debug contract only; the current `MapService:DebugSpawnFood` method is a stub. |
| DebugResetLauncher | C->S | PlayerService | `{}` | Studio-only debug reset; server ignores requests outside Studio. |
| DebugLevelUp5 | C->S | GrowthService | `{}` | Studio-only test hook; server ignores requests outside Studio. |
| StartSafeZone | C->S | RoundService | `{}` | Studio-only round-start test hook; server ignores requests outside Studio. |
| Plus1Minute | C->S | RoundService | `{}` | Studio-only round-time test hook; server ignores requests outside Studio. |
| EndRound | C->S | RoundService | `{}` | Studio-only round-end test hook; server ignores requests outside Studio. |
| SellLauncher | C->S | LauncherInventoryService | `{ instanceId: string }` | Sells an eligible owned Launcher instance; the server decides eligibility and payout. |
| CombineLaunchers | C->S | LauncherInventoryService | `{ instanceIds: [string, string, string], requestId: integer }` | Combines three compatible owned Launcher instances; server validates ownership/eligibility and echoes the request ID in GameplayFeedback. |
| QuestClaim | C->S | QuestService | assignmentId: string | Claims the single active Daily Quest; server checks readiness and atomically grants the configured reward once. |
| QuestSkip | C->S | QuestService | assignmentId: string | Requests skipping the active Daily Quest; server starts the 90-second cooldown and issues a replacement at the same step. |

# Server → Client (Sync / Feedback)

| RemoteName | Direction | OwnerService | PayloadSchema | Description |
|---|---|---|---|---|
| StateUpdate | S->C | PlayerStateService | `{ userId: number, mapName: string, arenaStatus: string, level: number, exp: number, progressionRoundId: number?, maxHP: number, currentHP: number, movementState: string, cooldownEndTime: number, ... }` | Authoritative per-player state snapshot; Player Level/EXP belong to one RoundId and reset after results or when an empty Arena abandons the round. |
| MatchStateUpdate | S->C | RoundService | `{ state: string, roundId: number }` | Round phase synchronization. |
| UIStateUpdate | S->C | RoundService | `{ state: string, arenaStatus: string, alivePlayers: number, playerCount: number, mapName: string, timeLeft: number, countdownTimer: number }` | Aggregated round/UI status payload. |
| RoundResult | S->C | RoundService | `{ winner: string, roundId: number }` | End-of-round winner announcement. |
| GameplayFeedback | S->C | DamagePipelineService | `{ eventType: string, payload: { [string]: any } }` | Combat/damage feedback (damage dealt, impact, level-up, etc.). |
| PopupMessage | S->C | TrapService | `{ type: string, text: string }` | Contextual popup notification (trap or gameplay warnings). |
| ZoneUpdate | S->C | SafeZoneService | `{ phase: string, radius: number, center: Vector3, dpsPercent: number, nextShrinkAt?: number }` | Safe-zone visual and damage sync (freeze-required). |
| PetProjectileVisual | S->C | PlasmaCannon / SlowBlaster | `Spawn` or `End` visual message | Client-local projectile cosmetics; hit/damage/Slow remain server-authoritative. |
| QuestUpdate | S->C | QuestService | Snapshot containing DailyQuest, Weekly, ServerNow and optional action results | Authoritative Daily Quest chain snapshot and action results. |

# Controllers (Current)

| Controller | Responsibility | Category |
|---|---|---|
| `InputController.client.lua` | Captures keyboard/touch movement input, right-mouse hold state, computes camera-relative movement direction, and sends `MoveRequest` with aim target. | Input |
| `CameraController.client.lua` | Keeps the local camera in `Custom` mode and sets camera subject to the local pawn root when available. | Input |
| `LauncherUIController.client.lua` | Runs launcher joystick/charge/cooldown HUD behavior and sends `StartCharge` / `ReleaseCharge` remotes from UI input. | UI |
| `UIController.lua` | Composes and starts feature UI controllers, wires top-level hub toggles, and routes snapshot updates into UI. | UI |
| `InventoryUIController.lua` | Renders the Items-only `StarterGui.InventoryUI`, item selection, quantity/details, and Use action. | UI |
| `PetInventoryUIController.lua` | Owns `StarterGui.PetInventoryUI`, Pet slots/previews, Equip/Unequip, delete confirmation, upgrade preview, and Pet stat/ability descriptions. | UI |
| `ShopUIController.lua` | Renders shop tabs/slots and binds buy actions through shop logic service snapshots. | UI |
| `OnlineRewardUIController.lua` | Renders online reward slots/timers and reward-claim UI states from logic snapshots. | UI |
| `DailyLoginUIController.lua` | Renders daily login reward slots and claim/locked/completed states from logic snapshots. | UI |
| `DailyQuestUIController.lua` | Binds MainHUD.Root.QuestDaily, renders one active task/cooldown/claim state, confirms Skip, and toggles the left-extending RootBody. | UI |
| `MovementController.server.lua` | Receives `MoveRequest` from clients, applies pawn linear velocity, and updates facing rotation toward movement direction. | Network |

# Config Data (`ReplicatedStorage/Shared/Config`)


| Config file | Data it contains | Known users |
|---|---|---|
| `AbilityConfig.lua` | Launcher ability tuning and per-ability lookup helpers. | `LauncherAbilityService` |
| `BalanceConfig.lua` | Core balance constants for combat, collisions, growth, launch, respawn, food, and economy values. | `LauncherService`, `GrowthService`, `PlayerStateService`, `CollisionService`, `DamagePipelineService`, `FoodService`, `LevelConfig` |
| `ConfirmationTextConfig.lua` | Shared confirmation and team-feedback messages, with `vi`/`en` lookup and placeholder substitution. | `TeamSelectionUIController`, `UIController`, `LauncherInventoryUIController` |
| `DebugConfig.lua` | Debug and diagnostic feature flags. | client and server diagnostics |
| `FloatingTextConfig.lua` | Shared styles for floating Damage, Heal, and EXP text. | `PlayerService` |
| `GiftBoxConfig.lua` | Weighted Gift Box reward pool; all item entries are validated against `ItemConfig` and weights total 100. | `ItemService` |
| `GameConfig.lua` | Runtime flag durations, stacking/tick behavior and status-effect visual configuration. | `FlagService`, `PlayerStateService` |
| `ItemConfig.lua` | Item catalog and shared item metadata. Bomb tuning includes blast radius, max damage falloff, knockback, and beep interval; `gift_box` is a consumable. | `InventoryUIController`, `InventoryDataProvider`, `RewardRoller`, `MockData`, `ItemService`, `BombService` |
| `LevelConfig.lua` | Level progression settings and `RequiredExp` formula (via `BalanceConfig`). | `PlayerStateService`, `UIController` |
| `PetAbilityProgressionConfig.lua` | Numeric ability parameters at milestones 1/5/10/15/20. Player-facing ability text is owned by `PetAbilityDisplayConfig.lua`. | `PetProgression`, `PetDisplayFormatter` |
| `PetAbilityDisplayConfig.lua` | Localized descriptions for each Pet ability; does not own gameplay tuning. | `PetDisplayFormatter`, `PetInventoryUIController` |
| `PetPreviewConfig.lua` | Per-pet viewport camera `Rotation` and `Offset`, accessed through `Get(petId)`. | `PetInventoryUIController`, `PreviewRenderer` |
| `PetRenderConfig.lua` | Client-side nearby Pet render distance, range-check interval, and exit hysteresis. | `ClientPetController` |
| `PetProjectileRenderConfig.lua` | Client-only projectile visual distance and count cap. | `PetProjectileVisualController.client.lua` |
| `LauncherPreviewConfig.lua` | Per-Launcher viewport camera `Rotation`, `Offset`, and preview `Scale`, accessed through `Get(launcherId)`. | `LauncherInventoryUIController`, `PreviewRenderer` |
| `PetRarityStatsConfig.lua` | Base HP and damage values by pet rarity. | `PetProgression`, pet UI |
| `PetsConfig.lua` | Pet definition catalog, ability IDs, rarity, and max-level settings. | `PetService`, `PetProgression`, `PetInventoryUIController` |
| `PetsUpgradeConfig.lua` | Pet levels 1–50, linear `50 × currentLevel × rarityMultiplier` upgrade cost, +5% base HP/Damage per level through 20 and +3% per level from 21–50, plus ability milestone predicates. | `PetService`, `PetProgression`, `PetDisplayFormatter` |
| `LauncherConfig.lua` | Current five Duck Launcher definitions (`Normalduck`, `Kingduck`, `Witchduck`, `Drakeduck`, `Shielduck`), default ID, combat stats, weight, reflect damage, and lookup helpers. Future catalog size is not fixed. | `PlayerStateService`, `LauncherStatResolver`, launcher inventory/shop and mock data |
| `RarityConfig.lua` | Launcher rarity/star tiers (Common → Normal → Rare → Epic → Legendary), star lookup, next-tier lookup, display colors, and per-tier stat multipliers. | `PlayerDataService`, `InventoryDataProvider`, `LauncherStatResolver`, `LauncherInventoryUIController` |
| `TrapConfig.lua` | Trap tuning constants (EXP penalty, cooldown, count, color). | `TrapService` |
| `PhysicsConfig.lua` | Centralized movement, launch, collision and physics thresholds. | `LauncherService`, `CollisionService`, `DamagePipelineService` |
| `SafeZoneConfig.lua` | Safe Zone radius, shrink, relocation and replicated attribute names. | `SafeZoneService`, `SafeZoneVisualizer.client.lua` |
| `TeamConfig.lua` | Team IDs, colors, capacity, change cooldown and Rage timing. | `TeamService`, team selection UI, `RoundService` |
| `LauncherTextureConfig.lua` | Team/Rage texture IDs for equipped Launcher visuals. | `PlayerService` |
| `SoundConfig.lua` | SFX keys and playback settings. HP potion consumption uses `SFX_Item_HealthPotion`; `CollisionClientScanner` plays spatial `SFX_Wall_Hit` locally once per continuous contact with `Collision_Wall`-tagged geometry, without server validation; Ground, Food, Lava, Trap, and unclassified parts are excluded. | `SoundManager`, `SFXController`, `CollisionClientScanner` |
| `QuestConfig.lua` | Five-step Daily Quest pools, step rewards, 90-second skip cooldown, and UTC+7 daily reset. | `QuestService`, `DailyQuestUIController` |
| `RankConfig.lua` | Rank/leaderboard progression settings. | leaderboard/progression services |

## Pet Inventory progression UI

- Pet UI is now owned by `PetInventoryUIController` and binds `StarterGui/PetInventoryUI/Root/BodyPets`; `ProjectTreeSpec.UI.PetInventory` is the canonical path group. `InventoryUIController` is Items-only and must not resolve or mutate Pet UI.
- `PetInventoryUIController` opens from `Workspace/Maps/LobbyMap/Pet/PetInventoryGUI_Part` through `WorldProximityUIController`; the range is 10 studs and leaving the range closes the Pet screen.
- Pet slots are cloned from `ReplicatedStorage/Assets/UI/PetSlotTemplate_PetInventoryUI`. Pet ownership/equip snapshots still come from the shared `InventoryDataProvider` and server `StateUpdate`; the Pet UI does not keep a second local inventory.
- `PetDisplayFormatter.Format(definition, level, previewNextLevel, languageCode)` returns `LevelText`, `HPText`, `DamageText`, and `ScriptText`. `PetAbilityDisplayConfig` contains localized descriptions for all Pet definitions, while numeric values are resolved from `PetProgression` and `PetAbilityProgressionConfig`.
- Pet level caps at 50. Base HP and Damage gain +5% per upgrade level through level 20, then +3% per level from 21 to 50. Ability parameters remain capped at level 20 and use milestones 1, 5, 10, 15, and 20; Titan weight/hitbox parameters also stop scaling at 20. Upgrade price is `50 × currentLevel × rarityMultiplier`, with the existing rarity multipliers retained.
- The first Upgrade click previews base-stat changes; the second click sends `UpgradePet(instanceId, expectedLevel)`. The button stays pending until `PetUpgradeResult` or the authoritative level update arrives. Deletion requires confirmation and sends `DeletePet(instanceId)`; the server removes equipped-slot references before synchronizing the player.

> **History note:** Entries below are dated implementation history, not a current-state inventory. Later notes and the current source supersede older Equipment-era descriptions; current gameplay ownership is Pets + Launcher Inventory.

## Recent implementation update (2026-08-21)

- The legacy `EquipmentSlot1..3` attachment contract is retired from the active Launcher pawn. Do not add these attachments back; equipped Pet visuals are client-rendered by `ClientPetController` relative to `Hitbox.LauncherMovementAttachment`.
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


## Movement VFX and Pet attachment update (2026-10-24)

- `Hitbox.TailAttachment.RocketLaunchParticle`, `MotionTrail1`, and `MotionTrail2` default to disabled. They are enabled only while the Launcher is `Moving`, `Charging`, or `Launching`, and disabled in `Idle`, `Knockback`, and other states.
- Equipped Pet visuals remain client-rendered and now follow from `Hitbox.LauncherMovementAttachment` when present. Legacy `EquipmentSlot1..3` attachments are stripped from the server's Launcher template clone and must not be restored to the current asset tree.


## Audio SFX system (updated 2026-10-27)

- Sound keys and default settings are declared in `src/ReplicatedStorage/Shared/Config/SoundConfig.lua`; `SoundId` intentionally starts empty so IDs can be filled after implementation. Configuration includes Volume, Pitch (mapped to PlaybackSpeed), 3D roll-off distances, emitter size, loop flags, pool limits, and per-key concurrency limits.
- `src/ReplicatedStorage/Shared/Utils/SoundManager.lua` lazily creates Sound instances, reuses pooled instances, supports Play/PlayAt/PlayOn/PlayLoop/StopLoop and per-call overrides, and returns completed sounds and temporary 3D emitters to bounded pools.
- `src/ReplicatedStorage/Client/Controllers/SFXController.lua` plays client-local click/success/hurt/death/kill/level-up/round-start/victory cues and binds existing or future GuiButtons for click SFX.
- Server-side spatial cues are triggered from authoritative gameplay resolution points. Do not play success audio when a request is merely sent; wait for server success feedback.
- The planned sound set is the 21 keys in SoundConfig. Unlisted statuses (including Slow and Petrify) remain silent. Populate SoundId values before runtime audio QA.


## Collision camera shake and sound toggle (2026-10-27)

- A validated player collision sends `GameplayFeedback.EventType = "CollisionCameraShake"` only to the defender. `CameraController.client.lua` applies a short local camera offset after the default camera update; `PhysicsConfig.CameraShake` tunes impact-speed scaling, normal-angle scaling, duration, and amplitude. The attacker does not receive this feedback.
- `MainHUD.Root.LeftMenu.SoundToggleButton` toggles client-side sound. `SoundOnIcon` is visible when enabled; `SoundOffIcon` is visible when muted. The TextButton background and text are transparent so the icon images provide the visual state.
- Managed audio routes through `SoundService.SlingArenaSoundGroup`; the toggle changes that group locally, so it does not mute audio for other players. The group is declared in `default.project.json` for consistent server/client identity.
- Legacy `SettingButton` / `SettingsUI` path resolution and panel-opening logic are retired; no Settings panel is required by the current HUD.


## Audio and item SFX update (2026-11-09)

- Bomb placement plays two spatial `SFX_Beep` cues; detonation plays spatial `SFX_ExplosionBomb`. The client preloads Explosion/Hurt/Reward one-shots through `SoundManager.Preload` to avoid first-play asset loading delay; the explosion SFX remains aligned to the actual fuse/detonation time.
- `SFX_Hurt` is driven by authoritative `GameplayFeedback.DamageTaken`, not HP snapshot differences, so initial profile/spawn reconciliation cannot emit a false hurt sound. Successful item use no longer triggers generic `SFX_Success`; HP Potion retains its dedicated sound. Server `RewardReceived` feedback plays `SFX_Success`, excluding Shop purchases and Quest claims that already have their own success feedback; Daily Login and Online Reward mock claims retain their existing single UI success cue.
- Bomb-hit Players enter the shared `Knockback` movement state only after the damage pipeline accepts a positive hit, before the impulse is replicated. Launcher locomotion is suspended during the state; Human mode returns to `Human` when the physical knockback settles or times out. Food receives Bomb area damage only and is not knocked back.
- Gift Box reward feedback reports the rolled Diamonds or Item in the inventory panel. Legendary Food last-hits grant one Gift Box.

## Audio collision SFX update (2026-10-29)

- Launcher wall-hit audio is played locally by `CollisionClientScanner` as soon as a launch sweep detects `Collision_Wall`. A contact episode plays once, and the scanner rearms after no tagged Wall has been detected for 0.12 seconds. `Collision_Ground` is skipped during sweep casts so it cannot hide a Wall ahead; `Collision_Food`, `Collision_Lava`, `Collision_Trap`, and unclassified geometry do not use wall audio. This cosmetic cue does not use a server report or server validation. Existing server arena-boundary bounce audio remains a separate path.


## Launcher inventory combine implementation (2026-11-01)

- Launcher combine uses `LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.CombineButton`, `BodyLauncher.CombineControls`, and `Root.CombineConfirmFrame.Dialog`. The confirmation Dialog contains three input Frame holders and one output Frame holder; the controller clones `LauncherSlotTemplate_LauncherInventoryUI` into each holder at full holder size.
- The UI requests exactly three distinct instance IDs plus a request correlation ID through `LauncherArenaRemotes.CombineLaunchers`. The server echoes that ID in `GameplayFeedback.LauncherCombineResult`; clients ignore stale results after a timeout or a newer request.
- The server currently permits only owned, permanent, unexpired, unequipped, non-default instances with the same Launcher definition and rarity/star. The three source instances are removed and one new instance is created in the same data mutation. The result advances one `RarityConfig` tier and inherits the highest source level. Only after the successful server result is received do the three InputSlot previews fly simultaneously into OutputSlot; the result preview is revealed when all three flight tweens complete, and this arrival is the animation endpoint (no extra grow/spin/shrink phase). All tween completion listeners are connected before playback to avoid missing already-fired completion signals. The success response immediately shows a reward toast with the result Launcher name and new rarity and changes the modal Confirm button from `Combining...` to `Tiếp tục`. Continue remains enabled and immediately cancels any remaining flight effects, closes the modal, clears the consumed selection, and returns to Combine Mode without waiting for animation completion. The original BackButton is only used before a successful combine. A watchdog is retained only as a fallback.
- Server MockProvider new-player defaults and the client-only MockPlayerData fallback each generate four Common copies of every current Launcher definition (20 owned instances for the current five-Launcher catalog). The first Normalduck copy is the protected equipped default. Existing named MockData profiles keep their own OwnedLaunchers rather than receiving the entire new-player inventory.
- Confirmed rarity tiers are Common/Normal/Rare/Epic/Legendary (stars 1–5) with 1.0x/1.2x/1.4x/1.6x/1.8x multipliers. Rarity scales only Launcher-derived HP, Damage, Regeneration, Armor, and ReflectDamage. Pet-sourced additive HP/Damage/ReflectDamage bonuses are applied afterwards and are not multiplied by Launcher rarity. Speed, LaunchPower, LaunchSpeed, Weight, and EXP bonus are not rarity-scaled; existing level-based LaunchPower progression remains independent.
- Combine is free and requires three owned instances of the same Launcher definition and rarity/star. Default, equipped, temporary, and expired instances are excluded; the result inherits the highest source level.
- Combine mode lists only groups with at least three eligible instances. After selecting the first item, `SelectedOverlay` dims different eligible groups and prevents mixed-group selection.
- `LauncherSlotTemplate_LauncherInventoryUI.Root.CombineCheckButton` is an `ImageButton`. It uses `rbxassetid://91796348808787` while unchecked and `rbxassetid://128924789177125` while selected. Back before a successful combine preserves the current selection. After a successful result animation, the original BackButton is hidden; the modal Confirm button is relabeled `Tiếp tục` and performs the same return-to-Combine-Mode action. The Continue button is not disabled/dimmed after success. Returning clears the consumed selection, and the selection-screen Confirm button stays disabled until exactly three compatible Launchers are selected.
- Runtime QA still requires Roblox Studio: confirm authored modal sizes/ZIndex/anchors, all three slot holders, result ViewportFrame visibility, animation layout, repeated combine operations, late/duplicate feedback, and server rejection reasons.


## Recent Runtime UI / Debug / Food Updates (2026-11-03)
- `LauncherWorldUI` writes `HPStats` as current/max HP on every authoritative `PlayerStateUpdated` update. The bar fill still uses the same authoritative HP ratio and team color.
- FoodSpawn Parts define the complete rectangular X/Z spawn area. Mid/Edge target count is floor(Size.X * Size.Z / 500), clamped to 1–40; Center spawns 2 per Part. This doubles the configured target density and cap while keeping HP–HP Hitbox edge gap at 4 studs and Common–Common / HP–Common gaps at 3 studs. Food must raycast to an upward-facing floor tagged Collision_Ground within 4 studs of the FoodSpawn top plane.
- `UnitTestUI.RootFrame.ShowStats` is an optional debug TextButton. When present, it prints the local player's latest authoritative derived stats, including Launcher/Pet HP and Damage contributions, Speed, LaunchSpeed, Armor, Regeneration, ReflectDamage, Weight, and EXP Bonus; absence is valid and must not emit a startup UI warning.
- Player Level is the only Player progression Level and exists only in PlayerStateService runtime state scoped to the server's current RoundId. PlayerDataService clears legacy profile `Level/Exp` fields instead of persisting them. It starts at 1 on a new Arena join, gains EXP during Awaits/EarlyGame/FinalPhase, survives respawn and same-server leave/rejoin within that RoundId, and resets after results or when an empty Arena abandons the round. Lobby EXP is rejected; direct EXP consumables and EXP-boost consumables are not deducted outside a valid round.
- Online Reward is server-authoritative through OnlineRewardService and grants only Diamonds and ItemConfig items; it does not grant direct Round EXP. Persistent profile data no longer includes Player `Level/Exp`; Global Top 100 ranks persistent ProgressPoints, while match boards show round-scoped runtime Level.
- Pet Base HP/Damage grow by +5% of base per level through level 50 (3.45x at level 50). Ability values at levels 1/5/10/15/20 are retained; levels 25/30/35/40/45/50 each add one sixth of the remaining 20% of each configured parameter range. Ability stats do not change between milestones.
- `PetStatResolver` applies each equipped Pet's rarity-based base HP/Damage plus its configured `statModifiers.Add/Multiply` values. BrainBoost's level-scaled `abilityParams.expBonus` supersedes its legacy static `Add.expBonus` value so the bonus is not counted twice. Cooldowns and discrete projectile-speed unlocks retain dedicated settings.


## Implementation update (2026-11-04)

- `InventoryUIController` now resolves `InventoryUI.Root.BodyItems` through `ProjectTreeSpec.UI.Inventory.BodyItems` and explicitly enables the frame on startup/open. `SetVisible(false)` hides both `BodyItems` and the ScreenGui; opening from `MainHUD.Root.LeftMenu.InventoryButton` makes the sole remaining content frame visible. No tab UI was reintroduced.
- Food density was doubled in `FoodConfig`: Mid/Edge area target uses 1 food per 500 studs² (previously 1 per 1000), maximum per FoodSpawn Part increased from 20 to 40, and Center target increased from 1 to 2. Existing no-overlap clearances, rarity weights, respawn times, ground checks, and player clearance are unchanged. Progression economy tests now assert the new target counts.
- Pet progression audit: all 18 Pet definitions now have level-scaled ability parameters. The 11 newly supported Pets are ThunderHammer/Stun, Medusa/Petrify, GhostFlame/Burn, Poison, HealthCore, PowerCore, TurboModule, LaunchBooster, QuickReload, ThornArmor, and ShadowCloak. `EffectUtil` reads level-scaled DoT damage for both Player flags and Food DoT state; `PetStatResolver` applies progression bonuses while suppressing legacy static duplicates; `IdleStealth` reads the level-scaled delay. ThornArmor's reflect contribution is resolved by `PetStatResolver` and processed by `DamagePipelineService`.
- Runtime validation in Roblox Studio has not yet been performed for these changes.


## Pet Ability Progression implementation (2026-11-04)
- Added Level 1/5/10/15/20 values and Level 50 targets for the eleven previously unscaled Pets. Levels 21–50 use the existing milestone interpolation rule; the established progression values for the original seven Pets are unchanged.
- ThunderHammer/Stun and Medusa/Petrify now use level-scaled `collisionExtraDuration`, retaining the existing impact-speed scaling in `EffectUtil`.
- GhostFlame/Burn and Poison now override DoT damage-per-tick from Pet progression for both Player flag application and Food DoT ticking. Existing durations, tick intervals, stack rules, Poison slow, and food attribution remain unchanged.
- HealthCore, PowerCore, TurboModule, LaunchBooster, QuickReload, and ThornArmor now resolve level-scaled stat contributions through `PetStatResolver`. Each progression value supersedes its matching legacy static modifier to prevent double counting. QuickReload continues to feed `PlayerState.LaunchCooldownReduction` and the existing Launcher recovery calculation.
- ShadowCloak's `IdleStealth` module now reads the progression-controlled idle delay. PetInventory ability descriptions show the live value and next-level preview for the new parameters.
- `PetProgression.Resolve` falls back to the Pet definition ID for passive-only Pets without an abilityId and legacy NoOp Pets; they keep their existing NoOp runtime effect module.
- Added progression-target and stat-resolution regression tests for all eleven Pets. Roblox Studio/runtime tests have not yet been executed in this pass.


## Bomb item runtime (2026-11-08)
- Bomb is registered in `Shared/Config/ItemConfig.lua` as a normal stackable consumable and uses the existing `ConsumeItem` RemoteContract through `ItemService`; no new client remote or Inventory UI is required.
- Initial Bomb tuning: Damage 1500, BlastRadius 22 studs, FuseTime 3s, spawn 5 studs forward and 6 studs above the top of the player root, maximum 2 active Bombs per player, and 1.5s use cooldown. Values are starting balance, not final.
- `BombService.lua` owns only world placement, fuse, detonation and visuals. Placement is server-derived from the player's root. Detonation uses the Bomb RootPart's live position, not its original spawn position, because the unanchored Bomb can fall and roll.
- Explosion VFX assets are Studio-authored at `ReplicatedStorage.Assets.EffectVfx.ExplosionPart` (Part containing the `Explosion` Attachment) and `ReplicatedStorage.Assets.Prefabs.VFX_ExplosionRing` (Model with E1–E5 mesh descendants). `BombService` clones the authored `ExplosionPart`, anchors it upright at the live blast position, hides/disables its physical interactions, and activates the nested Attachment effects; VFX orientation and ground-crack particles do not inherit Bomb roll/rotation. The ring is expanded/rotated at the actual blast center.
- Bomb player damage delegates to `DamagePipelineService` with an explicit Bomb source and a Bomb-only friendly-fire opt-in; this includes the owner's self-damage and teammates. Bomb damage may hit Human-mode victims, but only an eligible Launcher-mode player may place a Bomb. A placed Bomb retains its owner attribution through its fuse if that owner changes mode.
- Food area damage delegates to `FoodService:ApplyAreaDamageToFood`, which reuses `ApplyDamageToFood` so Food LastHit, EXP/diamond rewards and respawn remain in the existing Food ownership path.
- `MockData` seeds 3 Bombs and 1 Gift Box in default and named mock inventories. `gift_box` currently has no opening effect and cannot be used; no reward odds, Pet temporary grant or Gift Box acquisition source has been implemented.
- Current asset paths are Studio-authored and are not validated by source control. Confirm the Bomb Model's RootPart/Hitbox structure, ring mesh classes, and all visual timings in Roblox Studio before release. A dedicated explosion SoundId is not configured yet.

## Daily Quest Chain (2026-11-10)

- Daily Quest replaces the old Daily/Main quest list. Each player has one active assignment at a time and completes up to five steps per Vietnam calendar day (reset at UTC+7 midnight).
- QuestService owns quest selection, active step, progress snapshots, server-authoritative Claim/Skip, 90-second Skip cooldown, and cooldown completion after reconnect. A successful Claim grants the reward and assigns the next step in one PlayerDataService update; the fifth Claim ends the chain for that day.
- PlayerDataService.QuestState.DailyChain persists step/completed count, active assignment (unique AssignmentId and progress baseline), next assignment timestamp, and completed-for-day state. DailySchemaVersion migrates the former Daily/Main list schema without changing Weekly ProgressPoints.
- Daily Quest uses weighted pools: Food collection tasks have 80% of selection weight and active gameplay tasks have 20%. Five-step rewards are 50/80/120/180/250 Diamonds (10x previous rewards). Online-time, LaunchCount and generic damage tasks are retired; obsolete saved assignments are cleared without consuming a step or Skip cooldown.
- Metrics are server-event driven: Food rarity/type collection (DailyQuestFoodCollected), player kills, participant RoundCompleted, successful hp_potion consumption (DailyQuestHpPotionUsed), and confirmed Bomb damage to another player (DailyQuestBombPlayerDamaged). Food touch and hit-to-destroy flows keep their existing single-count behavior. Each assignment stores a metric baseline so progress from an earlier task cannot complete a later task.
- DailyQuestUIController and DailyQuestLogicService replace QuestUIController and QuestLogicService. QuestDaily uses RootBody/TaskDescriptionLabel, ClaimRewardBtn/DiamondIcon/DiamondCountText, ToggleDropdown/OpenIcon/ClosedIcon and NotificationIcon as documented in PROJECT_TREE.md. Progress is appended to TaskDescriptionLabel (for example, "Thu thập Common Food (50/100)"). ClaimRewardBtn is green and enabled only when Ready; otherwise the button and reward contents are muted gray and disabled. RootBody is anchored on its left edge and expands rightward from ToggleDropdown, collapsing toward the same origin. The controller re-resolves UI references after relevant descendants are added, removed or reparented.
- QuestUpdate synchronizes snapshots/results; QuestClaim and QuestSkip carry the current AssignmentId. The server validates each request and rate-limits repeated requests. Weekly Points and weekly reward processing remain independent.
- Validation note: static repository review only; Roblox Studio runtime and multi-client tests are still required. Runtime persistence remains limited by the currently configured MockProvider until a durable provider is selected.


## Online Reward implementation (2026-11-12)

- Online Reward uses `OnlineRewardService` on the Server and `OnlineRewardConfig` in Shared Config. It has 15 milestones over 30 minutes (1, 2, 3, 5, 7, 10, 13, 15, 18, 20, 23, 25, 27, 28, 30 minutes), with five Common, five Normal, and five Rare slots.
- Reward sets contain Diamonds and valid `ItemConfig` consumables only; direct EXP rewards and `exp_card_500` are excluded. SetA/SetB/SetC are selected server-side and stored per cycle.
- The server validates readiness and CycleId before `PlayerDataService:CommitOnlineRewardClaim` grants Diamonds/Items and records the slot claim in one profile mutation. A cycle resets only after all 15 slots have been claimed, then sends the Online Reward refresh toast.
- OnlineRewardState is part of the PlayerDataService profile schema. `LastOnlineAt` is refreshed with a 20-second heartbeat so the next join can detect an interrupted session; offline gaps strictly greater than 30 minutes reset the cycle. `ResetTimeOnlineReward` completes all countdowns in Studio but does not claim rewards.
- Client OnlineRewardLogicService receives server snapshots, submits claims, and sends the Studio-only `DebugCompleteCountdown` test action; it does not own timers or grant rewards. OnlineRewardUIController renders 15 slots, the simplified `OnlineRewardUI.Root.Content` / `Root.CloseButton` hierarchy, and optional `MainHUD.Root.LeftMenu.OnlineRewardButton.InfoIcon`.
- Persistence limitation: current `PlayerDataService` still uses the in-memory `MockProvider`; the profile schema is ready for a durable provider but cannot survive a different server process until that provider is replaced. Runtime behavior has not yet been tested in Roblox Studio.


## UI binding follow-up (2026-11-12)

- `UnitTestUI.Root.ResetTimeOnlineReward` is an optional Studio-only path for the startup binder. `UIController` watches UnitTestUI like other ScreenGuis, retries references on descendant additions/removals and when the ScreenGui is cloned into PlayerGui, and falls back to a unique `GuiButton` named `ResetTimeOnlineReward` under UnitTestUI if the documented path differs. The click sends `DebugCompleteCountdown` through the already-used `OnlineRewardRequest` RemoteEvent; the server accepts it only in Studio, updates `OnlineRewardState.ElapsedSeconds` through `PlayerDataService:UpdateData`, then sends a snapshot that makes all 15 slots Ready without claiming them.
- `InventoryUI.Root.BodyItems.RightPanel.Description` is optional. InventoryUIController resolves the canonical path when present, then falls back only to a unique TextLabel named `Description` under the current BodyItems.RightPanel. UIBinder does not treat this optional label as a required startup path.
