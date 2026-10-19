# 🔥 SLING ARENA – GAME DESIGN SPECIFICATION (Code-Verified)
_Last audited against source: `SirLiuLeu/Devs-2026-SlingArena` (main), 2026-08-29._

This document is the **single source of truth** for gameplay rules during feature development and bug fixing. Every rule below has been checked against the actual Luau source under `src/`. Anything the source does not support has been **removed** rather than carried forward from the previous draft. Anything the source contradicts is called out inline and collected in **Section 13 — Inconsistencies / Needs Alignment**.

Legend used throughout:
- ✅ **Verified** — confirmed directly in source.
- ⚠️ **Partially implemented** — some supporting code exists, but the full behavior described does not run end-to-end.
- ❌ **Not implemented** — referenced in docs/config but no runtime code executes it.

---

# 0. DESIGN GOAL

* Genre: Survival Physics Arena (round-based, up to solo/duo play)
* Core Experience: Farm Food to level up; use physics-based Launch collisions to push opponents into hazards or the shrinking Safe Zone
* Core Feeling: **Launch → Impact → Bounce → Slide** should feel strong and responsive
* Philosophy: Skill & positioning over raw stat checks

# 1. CORE GAME LOOP

* **Lobby:** select Launcher / Pets, open Shop, Spin
* **Join Arena:** player enters the map and is switched into `Launcher` mode
* **Mid Round:** farm Food, level up, fight, use traps
* **Late Round:** Safe Zone shrinks to minimum radius → `FinalPhase`
* **End:** last player alive wins; round resets, all players return to Lobby

---

# 2. ROUND LIFECYCLE

Round states (`GameStates.MapRoundState`), verified in `RoundService.lua`:

**Lobby → Awaits → EarlyGame → FinalPhase → RoundEnd → PostRound**

## 2.1 Lobby

* Players are not counted as "in the arena" (`LocationState = Lobby`).
* Round state returns to `Lobby` whenever the arena empties out (0 players in `Awaits`/`EarlyGame`), which also resets `_roundTimer` to 0.

## 2.2 Joining the Arena

* `RoundService:JoinArena(player)`:
  * Rejects the join if the player is inside a **15-second** rejoin cooldown after last leaving (`REJOIN_COOLDOWN_SECONDS = 15`). ✅
  * Activates the default arena map.
  * Resolves spawn mode via `PlayerStateService:ResolveArenaSpawnMode`, which returns `Launcher` **unless** `ShouldForceHuman(player)` is true (see §4.4). ✅
  * If the round was in `Lobby`, transitions it to `Awaits`.

## 2.3 Awaits

* Purpose: wait for enough players before the shrink timeline starts.
* Full gameplay is enabled (movement, charge, launch, food, combat) — nothing in code disables these during `Awaits`. ✅
* ⚠️ The previous doc claimed "EXP gain reduced by 50%, no Diamonds, no special rewards" during `Awaits`. **No such gating exists** in `GrowthService`, `FoodService`, or `PlayerStateService:GrantExp` — EXP and Diamond grants are identical in `Awaits` and `EarlyGame`. Flagged in §13.

## 2.4 EarlyGame

* Trigger: **`MIN_PLAYERS_TO_START = 3`** players present in the arena (`RoundService.lua`). ✅
* On entry, the Safe Zone begins shrinking (`SafeZoneService`).
* ⚠️ No code path applies a distinct "100% EXP" multiplier for this phase specifically — EXP math is round-state agnostic (see §2.3).

## 2.5 FinalPhase

* Trigger: `SafeZoneService:IsAtMinimumRadius()` becomes true while in `EarlyGame` (or via the debug `+1 Minute` tool forcing the check). ✅
* On entry: `RoundService:_setState(FinalPhase)`.
* ❌ No respawn-disable or "new team creation disabled" logic is tied to entering `FinalPhase`. `DamagePipelineService:HandlePlayerDeath` still calls `RespawnAfterDelay(player, 3, ...)` during `FinalPhase`; see §13 for the current behavior.
* What **is** real: dying while in `Launcher` mode, or dying at all while the round state is `FinalPhase`, permanently forces the player into `Human` mode for the rest of the match (`PlayerStateService:RecordDeath`) — see §4.

## 2.6 RoundEnd

* `ROUND_END_FREEZE_SECONDS = 5`, `ROUND_END_RESULTS_SECONDS = 15` (`RoundService.lua`). ✅
* Flow: freeze all arena players → determine winner → unfreeze after 5s → show results/rewards until 15s → transition to `PostRound`.
* Win condition: last player alive (checked while round state is `EarlyGame` or `FinalPhase`).

## 2.7 PostRound

* Players return to Lobby; round/map/food/temporary-flag state resets; next round prepared.

---

# 3. CHARACTER CONTROL MODES — HUMAN vs LAUNCHER

Backed by `GameStates.PlayerMode` (`Human` | `Launcher`) and `PlayerStateService`.

## 3.1 Mode Switching

* **On joining the Arena:** the player's active mode resolves to `Launcher`, **unless** they are currently forced into `Human` (`ShouldForceHuman`). (`RoundService:JoinArena` → `PlayerStateService:ResolveArenaSpawnMode`)
* **On death:** `PlayerStateService:RecordDeath(player, roundState)` sets `ActivePlayerMode = Human` and `ForcedHuman = true` immediately if either:
  * the player died while in `Launcher` mode (the common case — Human-mode players cannot take damage, see below), **or**
  * the current round state is `FinalPhase`.
  * The **visible pawn respawn** (the character model actually reappearing) happens on a **3-second delay** via `PlayerService:RespawnAfterDelay(player, 3, ...)`, spawned in whatever mode `ActivePlayerMode` now holds. ✅ This matches the intended "3-second delay before reverting to Human" behavior, though technically the *state flag* flips immediately at the moment of death and the delay only gates the *pawn respawn*. See §13.

## 3.2 Human Mode Capabilities

Confirmed via `IsHuman()` gates across services:

| Capability | Human Mode |
|---|---|
| Standard movement | ✅ Allowed |
| Charge / Launch | ❌ Blocked (`LauncherService.lua`) |
| Take / deal combat damage | ❌ Blocked (`PlayerStateService:ApplyDamage`, `DamagePipelineService`) |
| Consume Common Food | ✅ Allowed |
| Consume HP-based Food (Uncommon/Rare/Epic/Legendary) | ❌ Blocked — these require a valid attack (`RequiresLaunching`), which Human mode cannot perform (`FoodService.lua`, `CollisionValidation.lua`) |

## 3.3 Launcher Mode

* Full gameplay: movement, charge, launch, combat, all Food types, Pet effects.
* `PetAbilityService` orchestrates equipped Pet effects. Effects are active only while the player is in Launcher mode; switching to Human stops/deactivates those effects, which may be reactivated on the next Launcher spawn.

---

# 4. LAUNCHER SYSTEM

## 4.1 Current Launcher Roster (`LauncherConfig.lua`)

The current runtime catalog defines five Launchers: `Normalduck`, `Kingduck`, `Witchduck`, `Drakeduck`, and `Shielduck`. The future catalog size is not fixed; use `LauncherConfig` lookup helpers instead of assuming a permanent count.

| ID | Role | maxHP | baseDamage | armor | regen | speed | launchPower | control | launchSpeed | reflectDamage | weight |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `Normalduck` (default) | Balanced | 16,000 | 1,000 | 0 | 1.0 | 16 | 1.00 | 1.00 | 100 | 0.05 | 100 |
| `Kingduck` | Tank | 28,000 | 700 | 0.30 | 1.4 | 12.5 | 0.85 | 0.90 | 65 | 0.12 | 130 |
| `Witchduck` | Speed | 11,000 | 650 | 0 | 0.8 | 22 | 1.05 | 1.30 | 110 | 0.03 | 80 |
| `Drakeduck` | Burst | 13,500 | 1,650 | 0 | 0.9 | 15 | 1.20 | 0.95 | 90 | 0.08 | 115 |
| `Shielduck` | Defense | 23,000 | 850 | 0.22 | 1.2 | 14 | 0.90 | 0.95 | 80 | 0.10 | 120 |

* A Launcher owns base stats, size, movement profile, and launch profile.
* A Launcher does **not** own combat status effects (Stun, Slow, DoT, etc.) — those belong exclusively to Equipment (§5).

## 4.2 Star & Level Scaling (`LauncherStatResolver.lua`)

* **Star multiplier:** `1 + (star - 1) × 0.08` — i.e., **+8% per star**.
* **Level multiplier:** `1 + (level - 1) × 0.03` — i.e., **+3% per in-match level**.
* Total growth = `starMultiplier × levelMultiplier`, applied to maxHP, baseDamage, regen, launchPower, and control.
* ❌ **The "3 identical Launchers → +1★" fusion mechanic has no implementation anywhere in the codebase.** The `star` field exists on owned-launcher data and the multiplier math is real, but nothing sets or increments `star` at runtime except hardcoded seed/mock data. See §13.
* ⚠️ Mock/seed data (`MockData.lua`) contains a `star = 4` entry, exceeding the design intent of a 3★ cap, and references launcher IDs (`FireLauncher`, `PetrifyLauncher`, `VacuumLauncher`) that **do not exist** in `LauncherConfig.Types`. Treat these as stale fixtures, not canonical content.

## 4.3 In-Match Level-Up

* No direct stat-adjustment UI during a match; leveling is driven purely by EXP from Food/kills (§6).

---

# 5. PET SYSTEM (`PetsConfig.lua`, `PetService.lua`, `PetAbilityService.lua`)

## 5.1 Ownership and equipped slots

- `PetsConfig.lua` is the definition catalog for Pet identity, rarity, effect identity, active ability identity and stat modifiers.
- `PlayerDataService` owns server-side `OwnedPets` and `EquippedPets` data. Pet ownership and equip requests are instance-based: the client supplies an `instanceId`, and `PetService` validates that the instance belongs to the player.
- The runtime profile has three equipped Pet slots. `PetService` owns equip, unequip and upgrade mutations; Pet model presentation is handled separately on the client.

## 5.2 Upgrade progression

- `PetsUpgradeConfig.lua` owns Pet-level normalization and upgrade-cost/stat-growth rules. `PetService` delegates the authoritative upgrade commit to `PlayerDataService`.
- Upgrade requests include the expected current level so the server can reject stale requests. The client preview is informational; it does not determine the upgrade result or cost.

## 5.3 Ability/effect ownership

- `PetAbilityService` orchestrates equipped Pet effect modules and dispatches their lifecycle hooks, including `OnInit`, `OnLaunch`, `OnCollision`, `OnTick`, `OnAttack` and `OnDestroy`.
- `activeAbilityId` and `effectId` are distinct fields: the former identifies an active ability, while the latter identifies the Pet effect module. Do not assume every Pet has an active skill.
- Server services remain authoritative for damage, flags, cooldowns, target validation and projectile hit resolution.

## 5.4 Pet visuals and projectiles

- Nearby Pet models are rendered locally by `ClientPetController` and range-gated through `PetRenderConfig`; the server replicates equipped Pet identity rather than welding Pet models to every pawn.
- PlasmaCannon and SlowBlaster projectile visuals are client-local and distance/count gated. Projectile simulation and hit/damage decisions remain server-authoritative.

## 5.5 Legacy Equipment documentation

The old Equipment catalog, `EquipmentService`, `EquipmentEffectService`, and Equipment model-attachment instructions no longer describe the current runtime. Use the Pet services/configuration above and verify any proposed ability against current source before treating it as implemented.

# 6. FLAG SYSTEM (`FlagService.lua` + `GameConfig.FlagConfig`)

Flags are modifiers layered on top of a player's core `MovementState`. Real, code-backed flag set:

| Flag | Duration | Notes |
|---|---|---|
| `Invulnerable` | 30s default | Blocks damage and DoT |
| `Petrify` | 5s | Interrupts charge; removes any active `Stun` on application; blocks new `Stun` while active |
| `Stun` | 5s | Interrupts charge; cannot be applied over an active `Petrify` |
| `Slow` | 3s | −25% move speed (`SlowAmount = 0.25`), not stackable |
| `Burn` | 4s | 250 dmg/tick every 1s, 1.5s post-knockback tail |
| `Poison` | 5s | 150 dmg/tick every 1s, plus a 25% slow for 3s scheduled after knockback resolves |
| `PoisonTrap` | 5s, stacks to 5 | Source-scoped (per source) |
| `LavaTrap` | 0.75s, source-scoped | 0.1 dmg/tick every 0.5s + 25% contact slow for 0.75s |
| `HPRecovering` | 3s | 500 heal/tick every 0.5s (used by HP Potion, see §7.2) |
| `EXPBoosted` | 300s | +100% EXP |
| `DamageBoosted` | 30s | +100% damage |
| `Invisible` | Explicit duration only (no default in `FlagConfig`) | Used by Shadow Cloak and by `LauncherAbilityService`'s post-launch stealth window |

* Freeze/Petrify precedence: applying `Petrify` clears an active `Stun`; applying `Stun` while `Petrify` is active is rejected.
* Any flag with a configured `DamagePerTick` is gated by `dotAllowed`, which only permits DoT ticking while round state is `EarlyGame` or `FinalPhase` (not `Lobby`/`Awaits`/`RoundEnd`).

---

# 7. FOOD SYSTEM (`ServerScriptService/Config/FoodConfig.lua`)

`FoodConfig.lua` is source-controlled at `src/ServerScriptService/Config/FoodConfig.lua` and is consumed by `FoodService`. There is no `src/ReplicatedStorage/Shared/Config/FoodConfig.lua` in the current repository tree.

## 7.1 Global Settings

* `CommonRespawnTime = 10`s, `HpFoodRespawnTime = 30`s
* `SpawnRadius = 20`, `MinNoOverlapDistance = 3`

## 7.2 Food Types

| Food | Type | HP | EXP | Heal | Diamond Chance | Diamonds | Touch-only? |
|---|---|---|---|---|---|---|---|
| CommonRed/Green/Blue | Common | — | 50 | 20/15/10 | 0% | 0 | ✅ Yes |
| UncommonIce | Uncommon | 3,000 | 25 | — | 5% | 1 | ❌ Requires attack |
| RareAmber | Rare | 5,000 | 45 | — | 8% | 1 | ❌ Requires attack |
| EpicViolet | Epic | 8,000 | 70 | — | 12% | 2 | ❌ Requires attack |
| LegendaryGold | Legendary | 12,000 | 120 | — | 18% | 3 | ❌ Requires attack |

* Common Food disappears on touch; HP Food requires a valid Launch/attack hit and is destroyed only when its HP reaches 0.
* Diamonds are granted **only** as a chance-based drop from destroying HP Food — there is no other Diamond income path in the current codebase (see §8, §13).

## 7.3 Zone Spawn Weights (`ZoneWeights`)

| Rarity | Mid Zones | Edge Zones | Center Zones |
|---|---|---|---|
| Common | 70% | 65% | 0% |
| Uncommon | 15% | 15% | 0% |
| Rare | 10% | 10% | 0% |
| Epic | 5% | 5% | 70% |
| Legendary | 0% | 5% | 30% |

## 7.4 Spawn Density (`ZoneSpawnSettings`)

* Center Zones: 1 active item per spawn point.
* Mid/Edge Zones: 10 active items per spawn point, within `SpawnRadius = 20`.

---

# 8. ECONOMY & PROGRESSION

## 8.1 EXP

* `LevelConfig.RequiredExp(level) = BaseExp(100) × level^ExpExponent(1.3)`. ✅ matches original design intent.
* `LevelConfig.MaxLevel = 200`.
* Kill EXP: a flat **`BalanceConfig.KillExp = 120`** is granted to the killer (`GrowthService`), **not** "50% of the target's lost EXP" as previously documented. ⚠️ See §13.
* ❌ **No EXP-loss-on-death penalty is applied anywhere.** `PlayerStateService:TryApplyExpPenalty` and `DamagePipelineService:ApplyExpPenalty` exist as functions, but `HandlePlayerDeath` never calls them. The "lose 30% EXP on death" rule from the previous doc does not run in the current codebase.

## 8.2 Diamonds

* `PlayerDataService` is the sole authoritative Diamonds ledger (via `PlayerStateService:SpendDiamonds`/reads).
* The **only** Diamond income path found in source is the chance-based drop on HP Food destruction (§7.2). ❌ There is no per-kill Diamond reward in code, despite it being commonly expected design.
* `LevelConfig.StartingDiamonds = 1000`.

## 8.3 Size Growth — ⚠️ Two Conflicting, Unused-vs-Used Formulas

* `PlayerStateService:ComputeSize(level)` implements `BaseSize + level × 0.08` — **this function is never called anywhere in the codebase.** Dead code.
* The formula actually applied to runtime state (`state.Size`, in `PlayerStateService`) is: `BaseSize × (1 + (Level - 1) × 0.03) × ScaleMultiplier` — i.e., **+3% size per level**, matching the Launcher stat growth rate (§4.2), not a square-root curve.
* Neither formula matches a `sqrt(Level) × 0.08` shape from earlier drafts of this document. Use the **+3%/level, multiplicative with ScaleMultiplier** formula as the authoritative one.

## 8.4 HP Potion — ⚠️ Two Conflicting Definitions

* `BalanceConfig.HpPotionHealAmount = 120` and `BalanceConfig.HpPotionCooldown = 1.5` exist but are **effectively dead** — `PlayerStateService:TryConsumeHpPotion` always resolves cooldown/heal parameters from `ItemConfig.GetById("hp_potion")` first, and that definition is always present, so the `BalanceConfig` fallback values are never reached in normal play.
* The real, live HP Potion (via `ItemConfig.Items` → `HPRecovering` flag): **500 HP every 0.5s for 3s (6 ticks = 3,000 total HP)**, on a **3-second** cooldown (`useCooldown = 3`).
* `LevelConfig`/`PlayerStateService` starting inventory: `DefaultHpPotions = 25`.

---

# 9. SAFE ZONE (`SafeZoneConfig.lua` + `SafeZoneService.lua`)

## 9.1 Shape & Shrink Timeline

* `StartRadius = 300`, `MinRadius = 0`, full shrink duration `ShrinkDurationSeconds = 600` (10 minutes).
* Relocation: when shrink progress crosses `RelocationScaleThreshold = 0.7`, the zone's center may relocate over `RelocationDurationSeconds = 10`; tracked via the `IsRelocating` attribute. This is independent of normal radius shrinking.

## 9.2 Outside-Zone Damage — ⚠️ Numbers Corrected

Real ramp (`SafeZoneService.lua` constants), not the "1%/s → 10%/s" figure from the earlier draft:

* Starts at **0.5%/s**, increases by **+0.5%** every **30 seconds**, capped at **5%/s** (`DAMAGE_START_PERCENT=0.5`, `DAMAGE_PERCENT_STEP=0.5`, `DAMAGE_STEP_INTERVAL=30`, `DAMAGE_MAX_PERCENT=5`).
* Damage per tick = `(CurrentHP × percent/100) + (15,000 × percent/100)` — i.e., there is a large **fixed base component** (`DAMAGE_FIXED_BASE = 15000`) added on top of the HP-percentage component. This makes zone damage considerably more punishing than a pure percent-of-HP tick.
* Ticks once per second (`DAMAGE_TICK_INTERVAL = 1`).

## 9.3 Traps (`TrapConfig.lua`) — ⚠️ Roster Corrected

Only **two** trap types actually exist in the codebase — **Totem** and **Toxic Smoke** traps referenced in earlier drafts do not exist anywhere in source:

| Trap | Behavior | Details |
|---|---|---|
| SpikeTrap | Hit-cooldown damage | 1,500 damage per hit, 1.5s cooldown, "Spike hit! -1500 HP" popup |
| LavaTrap | Contact DoT | Applies the `LavaTrap` flag (0.1 dmg/tick every 0.5s, plus 25% slow for 0.75s) |

---

# 10. TEAM SYSTEM — four-team selection and Rage textures

- `TeamService` assigns active-round participants across `White`, `Yellow`, `Blue`, and `Red`; each team is capped at 10 players. `PlayerState.TeamId` is canonical and is synchronized to Roblox `Player.Team` while team play is active.
- The Studio-authored `StarterGui.TeamSelectionGui` toggles `TeamPopupFrame`, displays current counts, and sends team changes through `ChangeTeam`. Server validation enforces active-round timing, a 30-second successful-change cooldown, and team capacity.
- Rage/FFA activates at 480 elapsed round seconds. Roblox team membership becomes neutral, but `PlayerState.TeamId` remains for presentation/history and `IsFriendly` returns false for distinct players.
- `LauncherTextureConfig` provides shared texture slots for White, Yellow, Blue, Red, and Rage. Replace the five `rbxassetid://0` placeholders with uploaded texture IDs. The same config is applied to all equipped Launcher visuals.
- `DamagePipelineService` remains the authority for direct damage and friendly-fire checks; `CollisionService` incorporates Titan's effective weight multiplier into collision knockback.
- The Studio-only `Assets.Prefabs.PlasmaBall` and `Assets.Prefabs.SlowBall` are required by the Octopus PlasmaCannon and Dragon SlowBlaster. Keep these models available after Rojo sync; missing prefabs produce warnings rather than runtime crashes.

---

# 11. PHYSICS & COLLISION AUTHORITY

These architectural rules are verified in source and remain accurate:

* Movement uses `LinearVelocity` + Attachment-based constraints; the server owns `PlaneVelocity`, constraint `Enabled` state, and movement-state transitions. Clients must not run their own authoritative movement constraint.
* Rotation uses `AlignOrientation`; only `LauncherService` may write the authoritative `AlignOrientation.CFrame` on the server.
* All physical constants live in `PhysicsConfig.lua` — do not hardcode physics numbers in service logic.
* Collision is event-driven (`Client Detects → Client Reports → Server Validates → Server Resolves → Replicate`), not fixed-interval polling.
* Server validation is centralized in `CollisionValidation.lua` — do not duplicate manual distance/sweep checks in individual services.
* Rate limiting (`RateLimiter`) and hit deduplication (`HitCooldownDedupe`) are mandatory parts of combat validation.
* Bounce/depenetration geometry is in `CombatCollision.lua`; damage calculations and damage authority are in `DamagePipelineService`. No `CombatService.lua` exists in the current runtime tree.

---

# 12. PLAYER STATE MACHINE

`GameStates.PlayerState`: `Idle`, `Moving`, `Charging`, `Launching`, `Knockback`, `Dead`, `Human`.

Verified legal transitions (`MovementStateTransitions`):

* `Idle → {Moving, Charging, Knockback, Dead, Human}`
* `Moving → {Idle, Charging, Knockback, Dead, Human}`
* `Charging → {Launching, Idle, Knockback, Dead, Human}`
* `Launching → {Idle, Knockback, Dead, Human}`
* `Human → {Idle, Dead}` — a Human-mode player can only return to `Idle` (going Launcher) or die conceptually, they cannot Charge/Launch directly from Human.
* `Dead → {Idle, Human}`
* `Knockback → {}` — a player cannot self-exit Knockback; only a server-side `ForceSetMovementState` (verified stop/timeout) can end it.

`Human` sits alongside the combat states as a distinct `MovementState` value (not merely a `PlayerMode` label) — when `ActivePlayerMode = Human`, `MovementState` is also forced to `Human`.

---

# 13. INCONSISTENCIES / NEEDS ALIGNMENT

This section exists so nobody has to guess. Each item below is a **real, verified gap** between prior design assumptions and the current codebase — not an invented rule.

1. **The legacy Ghost player flag and its related collision/damage/visibility filters have been removed.** The current runtime does not provide a Ghost/spectator role; do not reintroduce this flag as part of FinalPhase behavior.
2. **FinalPhase death/respawn rules remain limited.** `DamagePipelineService:HandlePlayerDeath` still calls `RespawnAfterDelay` after three seconds, and `PlayerStateService:RecordDeath` converts the player to Human when death occurs during `FinalPhase`. There is no Ghost/spectator branch in the current runtime.
3. **"3 identical Launchers → +1★" fusion has no implementation.** The star-multiplier math exists and is applied, but nothing increments `star` at runtime. Seed/mock data even contains `star = 4`, exceeding a supposed 3★ cap, and references non-existent launcher IDs.
4. **Old Equipment rarity-level caps and `EquipmentUpgradeConfig` references are legacy documentation.** Pet upgrades are configured through `PetsConfig` and `PetsUpgradeConfig`; do not carry over the old Equipment caps without checking the current Pet definitions.
5. **Legacy Equipment effect notes are not the current ability contract.** Review the Pet definition’s `effectId` and the matching module under `PetAbilityService/PetAbilities` before documenting an effect as shipped.
6. **Team core behavior is implemented, but reward rules should be verified separately.** `TeamService` assigns balanced teams and validates team changes/capacity/cooldown; friendly-fire checks are integrated with `DamagePipelineService`. Do not assume assist rewards or shared-win rewards exist without a matching runtime path.
7. **No EXP-loss-on-death penalty runs**, despite the relevant functions (`TryApplyExpPenalty`, `ApplyExpPenalty`) existing in code — they are simply never called from the death path.
8. **Kill EXP is a flat 120, not 50% of the victim's lost EXP.** There is also **no per-kill Diamond reward** anywhere in source; Diamonds only ever come from a chance-based HP Food drop.
9. **No EXP-rate difference between `Awaits` and `EarlyGame`.** `GrantExp` is round-state agnostic; the previously documented "50% EXP in Awaits, 100% in EarlyGame" scaling does not exist in code.
10. **Safe Zone outside-damage numbers were wrong.** Real ramp is 0.5%/s → 5%/s (+0.5% every 30s), plus a large fixed 15,000-point base component added to every tick — not a pure 1%→10% percent-of-HP ramp.
11. **Only two trap types exist** (SpikeTrap, LavaTrap). Totem and Toxic Smoke traps referenced in earlier drafts have no implementation anywhere in the codebase.
12. **`FoodConfig.lua` has one source-controlled runtime path:** `src/ServerScriptService/Config/FoodConfig.lua`. Older documentation referenced a Shared/Config placeholder that does not exist in the current source tree.
13. **Two conflicting HP Potion definitions exist** (`BalanceConfig.HpPotionHealAmount/Cooldown` vs. `ItemConfig`'s `hp_potion` entry). The `ItemConfig` definition is what actually runs; the `BalanceConfig` fields are dead fallback values.
14. **Size-growth formula in earlier drafts (`sqrt(Level) × 0.08`) matches neither implementation found in code.** One implementation (`ComputeSize`, +8%/level linear) is dead code, never called. The live formula, applied to runtime state, is +3%/level multiplicative — matching the Launcher stat growth rate, not a square-root curve.
15. **`CombatService`, cited in `SYSTEM_OWNERSHIP.md` as the pure-formula combat service, does not exist as a file.** Bounce/depenetration geometry lives in `CombatCollision.lua`; damage math is inlined directly in `DamagePipelineService`. `SYSTEM_OWNERSHIP.md` needs reconciling with actual module boundaries.
16. **The current Launcher catalog has five entries:** `Normalduck`, `Kingduck`, `Witchduck`, `Drakeduck`, and `Shielduck`. The future catalog size is not fixed; `LauncherConfig` lookup helpers should be used instead of assuming a permanent count.
17. **Arena size and max-player-count (20) could not be verified from source.** No `MaxPlayers`, `ArenaSize`, or similar constant exists in any `.lua` config file — these are presumably Studio/place-level settings not represented in this Rojo tree. Additionally, `SafeZoneConfig.StartRadius = 300` implies a play space with a ~600-stud diameter, which is larger than a "400×400 stud arena" claim if both are meant to describe the same space. Needs confirmation from whoever owns the Studio place file.
18. **Thorn Armor reflect integration** was previously missing; the implementation now adds equipped pet `statModifiers.Add.reflectDamage` to the resolved Launcher reflect stat (maximum 50%). Runtime validation of lethal reflection remains part of the gameplay test plan.
19. **`AbilityTrigger` dispatches active pet abilities by `activeAbilityId`** — the SkillButton chooses the first equipped pet with that field, while server dispatch validates it separately from passive/effect identity. Legacy effects with `diagnostic` strings may still be stubs.

---

# 14. ARCHITECTURE PRINCIPLES (Still Accurate)

1. Server is authoritative for all gameplay truth (HP, damage, kills, Diamonds, Pet/Launcher ownership, Food state, Safe Zone, Round state).
2. Client predicts for responsiveness only; prediction never becomes authority.
3. State defines intent; Flags modify or override behavior; the server resolves the final result.
4. Launcher defines base stats/movement role; Pet abilities/effects provide combat effects — do not blur this boundary.
5. Pet/Launcher ownership is instance-based (`instanceId`); definition IDs are never accepted as proof of ownership. Current `PlayerDataService` uses `MockProvider`, so production persistence is not implemented yet.
6. Collision is event-driven and centrally validated in `CollisionValidation`.
7. Rate limiting, hit deduplication, and clock sync are mandatory parts of combat validation.
8. Physics constants come from `PhysicsConfig.lua`; do not hardcode.
9. Runtime services resolve dependencies through `ServiceResolver`/`ServiceRegistry` — avoid direct `require()` cycles between services.
10. Configuration holds data; gameplay logic belongs in services.
11. When adding a new mechanic, check whether it's referenced only in a design doc versus actually wired into a service — this document's §13 exists precisely because that gap has historically been large in this project. Verify against source before assuming a rule is live.