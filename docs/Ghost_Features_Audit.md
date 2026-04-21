# Sling Arena Ghost Features Audit (Code vs Rule_DESIGN.md)


## CombatService
- **Feature Name:** Log(size)-based damage model with slingshot type modifier and charge multiplier.
  - **Location:** `src/ServerScriptService/Services/CombatService.lua`.
  - **Description:** Impact damage is computed from speed × `log(size+1)` × slingshot modifier × damage multiplier × charge multiplier, then clamped.
  - **Impact:** Diverges from Rule_DESIGN’s simpler formula and creates hidden scaling behavior.

## DamagePipelineService
- **Feature Name:** Reflection damage against attacker.
  - **Location:** `src/ServerScriptService/Services/DamagePipelineService.lua`.
  - **Description:** Victim reflect stat causes automatic reflected damage to attacker.
  - **Impact:** Adds retaliatory damage loop not documented in Rule_DESIGN combat flow.

## TrapService
- **Feature Name:** Uniform trap payload instead of trap-type behaviors.
  - **Location:** `src/ServerScriptService/Services/TrapService.lua`.
  - **Description:** Trap hit applies fixed HP damage, fixed EXP penalty, cooldown, popup, and knockback impulse regardless of lava/smoke/spike/totem types.
  - **Impact:** Partial mismatch against spec’s distinct trap identities.

## PlayerStateService - người mới vào nên được 1 khiên bảo vệ

- **Feature Name:** Invulnerability timer support.
  - **Location:** `src/ServerScriptService/Services/PlayerStateService.lua`.
  - **Description:** State tracks `InvulnerableUntil` and blocks damage while active.
  - **Impact:** Hidden defensive state not described in rule flags.

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
