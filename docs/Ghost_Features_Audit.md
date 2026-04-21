# Sling Arena Ghost Features Audit (Code vs Rule_DESIGN.md)

## CollisionService
- **Feature Name:** Gate size lock and bounce rejection.
  - **Location:** `src/ServerScriptService/Services/CollisionService.lua`.
  - **Description:** Players colliding with gate volumes are bounced back if their size exceeds gate `MaxSize`.
  - **Impact:** Adds a hidden size-based movement restriction pathway not described in the design spec.

- **Feature Name:** Exit-zone scoring and round-ending triggers.
  - **Location:** `src/ServerScriptService/Services/CollisionService.lua` + `RoundService.lua`.
  - **Description:** Touching `ExitZone` emits a server event that can grant EXP and optionally force round end if zone attribute `EndsRound` is enabled.
  - **Impact:** Introduces map-authoring win/score triggers beyond “last player alive wins.”

## CombatService
- **Feature Name:** Log(size)-based damage model with slingshot type modifier and charge multiplier.
  - **Location:** `src/ServerScriptService/Services/CombatService.lua`.
  - **Description:** Impact damage is computed from speed × `log(size+1)` × slingshot modifier × damage multiplier × charge multiplier, then clamped.
  - **Impact:** Diverges from Rule_DESIGN’s simpler formula and creates hidden scaling behavior.

- **Feature Name:** Size-ratio inversion knockback.
  - **Location:** `src/ServerScriptService/Services/CombatService.lua`.
  - **Description:** If attacker is smaller than defender (`sizeRatio < 1`), knockback direction flips.
  - **Impact:** Adds asymmetric collision outcomes not stated in rules.

## DamagePipelineService
- **Feature Name:** Reflection damage against attacker.
  - **Location:** `src/ServerScriptService/Services/DamagePipelineService.lua`.
  - **Description:** Victim reflect stat causes automatic reflected damage to attacker.
  - **Impact:** Adds retaliatory damage loop not documented in Rule_DESIGN combat flow.

- **Feature Name:** Special-upgrade max-charge self-damage branch.
  - **Location:** `src/ServerScriptService/Services/DamagePipelineService.lua` + `SkillService.lua`.
  - **Description:** Self-damage on max-charge release only applies when special upgrade toggle is active; collision self-damage also depends on this flag.
  - **Impact:** Hidden risk/reward mechanic tied to an undocumented toggle.

- **Feature Name:** Continuous HP regeneration tick service.
  - **Location:** `src/ServerScriptService/Services/DamagePipelineService.lua`.
  - **Description:** Global 1-second regen loop heals living players using base regen + attribute influence.
  - **Impact:** Persistent sustain mechanic not explicitly defined in Rule_DESIGN.

- **Feature Name:** 2-second auto-respawn on death.
  - **Location:** `src/ServerScriptService/Services/DamagePipelineService.lua`.
  - **Description:** Dead players respawn after 2 seconds regardless of round phase.
  - **Impact:** Conflicts with spec timing and final-phase “no respawn/ghost-only” expectations.

## FoodService
- **Feature Name:** Seven food tiers with zone-biased spawn pools and per-tier HP/EXP values.
  - **Location:** `src/ServerScriptService/Services/FoodService.lua`.
  - **Description:** Food type (Food1..Food7) is selected by zone, each with different stat payouts.
  - **Impact:** Hidden economy/progression granularity not represented in Rule_DESIGN food section.

- **Feature Name:** Dynamic zone inference from map center.
  - **Location:** `src/ServerScriptService/Services/FoodService.lua`.
  - **Description:** If `Zone` attribute is missing, zone is inferred from distance bands (center/middle/edge).
  - **Impact:** Creates fallback map behavior not defined in map/food rules.

- **Feature Name:** Minimum spacing solver and retry placement.
  - **Location:** `src/ServerScriptService/Services/FoodService.lua`.
  - **Description:** Spawn positions are iteratively retried to avoid close overlap inside a cluster.
  - **Impact:** More strict anti-overlap logic than spec’s high-level statement.

## GrowthService
- **Feature Name:** EXP from raw damage dealt.
  - **Location:** `src/ServerScriptService/Services/GrowthService.lua`.
  - **Description:** Attackers earn EXP proportional to damage dealt, in addition to kill and food EXP.
  - **Impact:** Adds a major progression source not defined in economy section.

## RoundService
- **Feature Name:** Join/leave participation queue and lobby gate auto-join.
  - **Location:** `src/ServerScriptService/Services/RoundService.lua` + `MapService.lua`.
  - **Description:** Players must be in participant set; touching lobby gate auto-enqueues them.
  - **Impact:** Hidden access flow for entering active rounds.

- **Feature Name:** Additional round states (Boot, PreRound, Countdown, PostRound).
  - **Location:** `src/ServerScriptService/Services/RoundService.lua` + `Shared/Constants/GameStates.lua`.
  - **Description:** Round lifecycle includes extra intermediate states not covered by the 10-section spec.
  - **Impact:** UI/state transitions differ from documented lifecycle.

- **Feature Name:** Timeout winner fallback by damage dealt.
  - **Location:** `src/ServerScriptService/Services/RoundService.lua`.
  - **Description:** Internal timeout resolver picks winner by highest damage dealt.
  - **Impact:** Adds non-survival win path absent from end-condition rules.

## MapService
- **Feature Name:** Corridor size restriction / anti-giant map zones.
  - **Location:** `src/ServerScriptService/Services/MapService.lua`.
  - **Description:** Map supports `AntiGiantZone`, `SafeSpawnZone`, and `SizeRestrictedCorridor`; teleports can be denied by size limit.
  - **Impact:** Introduces spatial gating mechanics not defined in environment section.

- **Feature Name:** Player teleport API with round-state lockout.
  - **Location:** `src/ServerScriptService/Services/MapService.lua`.
  - **Description:** Teleport requests are allowed outside ActiveRound/Countdown and can set arena status to `Teleported:<map>`.
  - **Impact:** Adds extra navigation/state model beyond documented loop.

- **Feature Name:** Debug food spawn remote.
  - **Location:** `src/ServerScriptService/Services/MapService.lua`.
  - **Description:** Server exposes `DebugSpawnFood` event for manual spawning.
  - **Impact:** Administrative/debug pathway not in design spec.

## TrapService
- **Feature Name:** Uniform trap payload instead of trap-type behaviors.
  - **Location:** `src/ServerScriptService/Services/TrapService.lua`.
  - **Description:** Trap hit applies fixed HP damage, fixed EXP penalty, cooldown, popup, and knockback impulse regardless of lava/smoke/spike/totem types.
  - **Impact:** Partial mismatch against spec’s distinct trap identities.

## SkillService
- **Feature Name:** Passive heal while stationary and out-of-combat.
  - **Location:** `src/ServerScriptService/Services/SkillService.lua`.
  - **Description:** Heartbeat-based heal activates when movement, recent damage, and charge-state checks pass.
  - **Impact:** Hidden sustain mechanic not listed in sling/system sections.

- **Feature Name:** Attribute point spend and special-upgrade toggle remotes.
  - **Location:** `src/ServerScriptService/Services/SkillService.lua`.
  - **Description:** Players can spend stat points live and toggle a special upgrade state that affects self-damage logic.
  - **Impact:** Adds progression and combat switches beyond documented upgrade rules.

## PlayerStateService
- **Feature Name:** Extended attribute system and derived stat formulas.
  - **Location:** `src/ServerScriptService/Services/PlayerStateService.lua`.
  - **Description:** Attributes include Damage/MaxHP/Regen/Range/Reflect/LaunchSpeed/ChargeSpeed/MoveSpeed with clamped scaling and derived-stat recomputation.
  - **Impact:** Much deeper stat model than “+3% all stats” summary in Rule_DESIGN.

- **Feature Name:** Post-level-30 size soft-scaling.
  - **Location:** `src/ServerScriptService/Services/PlayerStateService.lua`.
  - **Description:** Size growth curve is reduced beyond level 30 via separate scalar.
  - **Impact:** Hidden late-game balancing layer not in progression rules.

- **Feature Name:** Randomized level-up damage bonus and additive growth package.
  - **Location:** `src/ServerScriptService/Services/PlayerStateService.lua`.
  - **Description:** Level-up applies +scale multiplier, +bonus max HP, +bonus damage multiplier, and random per-level damage increments capped by config.
  - **Impact:** Introduces random/stat-package growth details missing from documentation.

- **Feature Name:** Invulnerability timer support.
  - **Location:** `src/ServerScriptService/Services/PlayerStateService.lua`.
  - **Description:** State tracks `InvulnerableUntil` and blocks damage while active.
  - **Impact:** Hidden defensive state not described in rule flags.

- **Feature Name:** Prestige reset economy loop.
  - **Location:** `src/ServerScriptService/Services/PlayerStateService.lua`.
  - **Description:** Players can reset progression in exchange for diamonds derived from level.
  - **Impact:** Major meta-progression loop absent from specification.

## MonetizationService
- **Feature Name:** Paid/free respawn retention model.
  - **Location:** `src/ServerScriptService/Services/MonetizationService.lua`.
  - **Description:** Respawn purchases consume diamonds, are capped per match, and retain fractions of level/size differently for paid vs free respawn.
  - **Impact:** Undocumented economy + comeback mechanic with direct gameplay effect.

- **Feature Name:** Buyable match buff and prestige remote endpoints.
  - **Location:** `src/ServerScriptService/Services/MonetizationService.lua`.
  - **Description:** Players can spend diamonds for temporary in-match stat boosts; separate prestige reset endpoint exists.
  - **Impact:** Adds monetized power/progression flows not documented in the core design.

## TeamService
- **Feature Name:** Forced global two-team assignment (TeamRed/TeamBlue).
  - **Location:** `src/ServerScriptService/Services/TeamService.lua`.
  - **Description:** Players are auto-assigned to one of two teams for balance at join.
  - **Impact:** Conflicts with Rule_DESIGN’s “max team size 2 players” party-style team concept.

## UI / Client Controllers
- **Feature Name:** Developer debug buttons wired to server remotes.
  - **Location:** `src/ReplicatedStorage/Client/Controllers/UIController.lua` + `LobbyClientService.lua`.
  - **Description:** UI includes debug spawn-food and debug reset-sling controls.
  - **Impact:** Exposes non-player-facing admin flows not captured in spec.

- **Feature Name:** Quick HP potion hotkey button with anti-spam interval.
  - **Location:** `src/ReplicatedStorage/Client/Controllers/UIController.lua`.
  - **Description:** Dedicated quick-consume button throttles requests to 0.2s and reflects potion count from state.
  - **Impact:** Additional UX/mechanic not described in item section.

- **Feature Name:** Sling UI cooldown synchronized to release duration.
  - **Location:** `src/StarterGui/SlingArenaUI/SlingUIController.client.lua`.
  - **Description:** Cooldown duration is dynamically derived from actual launch travel/recovery timing and mirrored from server state.
  - **Impact:** Hidden control cadence details beyond basic move/charge/launch loop.

- **Feature Name:** Gameplay feedback event channel.
  - **Location:** `src/ServerScriptService/Services/DamagePipelineService.lua` + `Shared/RemoteContracts.lua`.
  - **Description:** Server emits typed feedback events (`DamageTaken`, `DamageDealt`, `SelfDamage`, `Impact`, `LevelUp`) via remote event.
  - **Impact:** Extra UI/VFX integration surface not defined in Rule_DESIGN.
