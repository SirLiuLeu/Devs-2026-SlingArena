# Sling Arena — Architectural Analysis & Implementation Roadmap

**Repository:** `SirLiuLeu/Devs-2026-SlingArena` (branch: `main`)
**Scope:** State/UI lifecycle hardening, EndRound freeze diagnosis, ProjectTree sync, Cooldown UI consolidation, MockData/Equipment persistence, legacy ability decoupling, and a 20-item Equipment expansion plan.
**Method:** Static analysis of the current `main` branch source tree (no code was written or modified; all line references are to the code as it exists today).

> This document is analytical only. No functional code is included, per instruction. File/line references are exact as of the current `main` HEAD so an engineer can jump straight to the relevant code.

---

## How to read this document

Each of the 8 objectives follows the requested 4-part format:
1. Target File Paths & Dependencies
2. Risk Analysis (Deployment, Synchronization, Coupling)
3. Proposed Architectural Solution
4. Step-by-Step Implementation Roadmap (No Code)

---

## 1. State Management & False Warning Elimination (Human vs. Launcher Mode)

### 1.1 Target File Paths & Dependencies
- `src/StarterPlayer/StarterPlayerScripts/LauncherUIController.client.lua` — owns `resolveUi()`, `warnMissingUiOnce()`, `isLauncherMode()`.
- `src/StarterPlayer/StarterPlayerScripts/UIBinder.client.lua` — owns `buildStartupUiPaths()`, the `STARTER_GUI_ROOTS` allow-list, and the initial `PathResolver.reportMissing(...)` startup sweep.
- `src/StarterPlayer/StarterPlayerScripts/PlayerModeController.client.lua` — owns `SelectedPlayerMode` / `ActivePlayerMode` player attributes and the `StateUpdate` / `UIStateUpdate` remote handlers.
- `src/ReplicatedStorage/Shared/Utils/PawnLocator.lua` — defines the dual-rig model: in Human mode the "pawn" is `player.Character`; in Launcher mode the pawn is a separate `Workspace.LauncherPawns.<Name>` model, while `player.Character` (with its `Humanoid`) continues to exist in the background.
- `src/ServerScriptService/Services/PlayerService/PlayerService.lua` — `_waitForHumanoidCharacterParts()`, `SpawnForActiveMode` (character/pawn lifecycle).
- `src/ServerScriptService/Services/LauncherService/LauncherService.lua` — server-side `HandleMoveRequest`, `LauncherMovement:Move`.
- `src/ReplicatedStorage/Shared/Constants/GameStates.lua` — `PlayerMode.Human` / `PlayerMode.Launcher` enum consumed by all of the above.

### 1.2 Risk Analysis
- **Deployment risk — noisy `output`/log ingestion.** `warnMissingUiOnce` in `LauncherUIController.client.lua` (lines 101–109, invoked at 274–276) fires `warn(...)` **unconditionally** whenever any expected LauncherUI descendant (`JoystickRoot`, `Base`, `Thumb`, `ChargeBar`, etc.) is missing — it does **not** check `isLauncherMode()` first, unlike the sibling check for the missing `ScreenGui` a few lines above it (line 247, which correctly gates on `isLauncherMode(lastKnownServerState)`). Any Human-mode player whose `PlayerGui.LauncherUI` hasn't finished cloning yet (a normal, expected transient state) will trip this warning even though nothing is actually broken. In a live server this pollutes logs at scale and masks genuine incidents.
- **Synchronization risk — the "no humanoid" warning is an engine-level side effect, not app code.** The exact string `"Player:Move called, but player currently has no humanoid"` does not appear anywhere in this repository — it is emitted internally by Roblox's default `PlayerModule`/`ControlModule` CoreScript, which keeps polling `Humanoid:Move` off WASD/thumbstick input for `player.Character`. Because `PawnLocator` deliberately keeps the "real" Humanoid character alive and parented (as a background object) while movement authority shifts to a separate `LauncherPawns` model, the default CoreScripts never get a signal that they should stop driving the original Humanoid. This is a genuine architectural gap, not a false positive to be silenced — the two character rigs currently have no explicit "who owns input right now" contract.
- **Coupling risk — mode-awareness is duplicated and inconsistently applied.** `isLauncherMode()` is reimplemented locally inside `LauncherUIController.client.lua` (lines 117–120) reading `player:GetAttribute("ActivePlayerMode")`; `UIBinder.client.lua` reimplements an equivalent but *not identical* check at lines 39–40 (`isHuman = activeMode == nil or activeMode == GameStates.PlayerMode.Human or player:GetAttribute("State") == GameStates.PlayerMode.Human` — note the extra, undocumented `"State"` attribute fallback that doesn't exist anywhere else in the codebase); `PlayerModeController.client.lua` tracks mode via its own local `SelectedPlayerMode`/`ActivePlayerMode` variables. Three independent, slightly-divergent readings of "what mode is this player in" is the direct cause of inconsistent warning suppression.

### 1.3 Proposed Architectural Solution
- Introduce a single shared module, e.g. `Shared/Utils/PlayerModeState.lua`, exposing `IsLauncherMode(player)`/`IsHumanMode(player)` as the **only** sanctioned way to read active mode client- and server-side. Every current inline reimplementation (`LauncherUIController`, `UIBinder`, `PlayerModeController`) is replaced with calls into this module — eliminating the divergent `"State"` attribute fallback in `UIBinder`.
- Make every UI-missing warning **mode-scoped by construction**, not by ad hoc `if isLauncherMode(...)` guards sprinkled per call site. The proposed centralized UI Bind Manager (Objective 2) should accept a `RequiredForMode` tag per UI subtree; warnings are only ever raised for subtrees whose tag matches the player's current, settled mode — never during a transition window.
- Add an explicit **debounced "mode settled" signal**: mode changes should carry a short grace period (e.g. until the next `CharacterAdded`/pawn-spawn confirmation) before any "missing UI" or "missing humanoid" diagnostics are permitted to fire, so warnings only represent genuinely stuck states, not normal transition latency.
- For the engine-level Humanoid warning: define an explicit **input-authority handoff**. When a player enters Launcher mode, disable the default `ControlModule`'s humanoid movement (e.g. via `PlayerModule:GetControls():Disable()` at the point `LauncherPawns` spawns) rather than relying on the humanoid being merely idle/hidden; re-enable it only when the player returns to Human mode and `player.Character`'s Humanoid is confirmed to be the active pawn again. This directly removes the condition that trips the engine warning instead of masking it.

### 1.4 Step-by-Step Implementation Roadmap
1. Extract and unify all `ActivePlayerMode`/`SelectedPlayerMode` reads behind one shared `PlayerModeState` module (client + server variants sharing the same enum source, `GameStates.PlayerMode`).
2. Replace the three independent mode checks in `LauncherUIController.client.lua`, `UIBinder.client.lua`, and `PlayerModeController.client.lua` with calls to the shared module; delete the undocumented `"State"` attribute fallback.
3. Gate the "LauncherUI hierarchy is incomplete" warning (`LauncherUIController.client.lua` line ~274) behind the same `isLauncherMode()` check already used for the missing-ScreenGui warning immediately above it.
4. Define and document an explicit "mode settled" grace window; suppress all UI/pawn diagnostics until it elapses after any mode transition.
5. Implement explicit input-authority handoff: disable default Roblox character controls on entering Launcher mode, re-enable on returning to Human mode, driven from the same transition point that spawns/despawns the `LauncherPawns` model in `PlayerService`.
6. Add a regression test/manual QA checklist item: toggle Human ↔ Launcher rapidly in the lobby and confirm zero warnings are emitted in `output` across 20+ consecutive toggles.

---

## 2. UI Lifecycle & Binding Standardization

### 2.1 Target File Paths & Dependencies
- `src/StarterPlayer/StarterPlayerScripts/UIBinder.client.lua`
- `src/StarterPlayer/StarterPlayerScripts/PlayerModeController.client.lua`
- `src/StarterPlayer/StarterPlayerScripts/LauncherUIController.client.lua`
- `src/ReplicatedStorage/Client/Controllers/UIController.lua` (732 lines — the largest single binder; owns `_resolveUiReferences()`, `_bindResolvedUiReferences()`, `_connectOnce()`, `_clearReferenceIfRemoved()`)
- `src/ReplicatedStorage/Shared/Utils/PathResolver.lua` — the shared low-level resolver all four binders call into.
- `src/ReplicatedStorage/Shared/ProjectTreeSpec.lua` — the path source-of-truth all binders read from.
- `src/ReplicatedStorage/Shared/Utils/WaitForUI.lua` (24 lines, currently thin/underused relative to `PathResolver`).

### 2.2 Risk Analysis
- **Coupling risk — four independent owners of the same GUI tree.** `UIBinder` resolves `ProjectTreeSpec.UI` broadly at startup (`PathResolver.reportMissing`), `UIController` re-resolves ~35 individual paths itself in `_resolveUiReferences()`, `LauncherUIController` maintains its own 10+ cached-instance locals (`cachedScreenGui`, `cachedJoystickRoot`, `cachedBase`, …) refreshed by its own `resolveUi()`, and `PlayerModeController` does a raw `playerGui:FindFirstChild("MainHUD")` walk in `findHumanLauncherToggle()` that bypasses `ProjectTreeSpec`/`PathResolver` entirely. Four different caching strategies (module-level locals vs. `self` fields vs. no cache) for overlapping UI subtrees is the direct cause of the race conditions described in the brief: a UI clone landing between two binders' resolution passes is invisible to whichever binder already cached "not found."
- **Synchronization risk — re-resolution triggers are inconsistent.** `UIController:Start()` re-resolves on `PlayerGui.ChildAdded` (line 518) and on a `Heartbeat` connection (line 640) — two different triggers doing overlapping work. `LauncherUIController` re-resolves opportunistically inside almost every input/update function via `resolveUi(false)`. `PlayerModeController` only re-resolves on `playerGui.ChildAdded` for the literal name `"MainHUD"` and on `player.CharacterAdded`. None of these are guaranteed to run in a specific order relative to each other, so it is possible for one binder to observe a fully-cloned UI tree while another still holds a stale `nil`.
- **Deployment risk — visibility and gameplay-state are entangled in the same code path.** In `LauncherUIController.client.lua`, `applyJoystickVisibilityFromState()` (lines 150–179) both resolves/validates UI *and* mutates gameplay-relevant state (`inputObject = nil`, `currentDragVector = Vector2.zero`) in the same function that decides `Visible` flags. A UI-presence bug and a gameplay-input bug are currently indistinguishable from a single stack trace.

### 2.3 Proposed Architectural Solution
- Introduce a single **UI Lifecycle/Bind Manager** (e.g. `Client/UI/UiBindManager.lua`) that:
  - Owns exactly one resolution pass per `ProjectTreeSpec` subtree, exposing a `Bind(subtreeKey) -> BindingHandle` API with reference-counted subscriptions, so `UIController`, `LauncherUIController`, and `PlayerModeController` all consume the *same* resolved/cached instances instead of independently re-walking the tree.
  - Emits a single, deduplicated event stream (`OnBound`, `OnLost`) per subtree, replacing the four separate `ChildAdded`/`Heartbeat`/ad hoc-`FindFirstChild` triggers with one authoritative signal.
  - Is the **only** component permitted to call `PathResolver`/`WaitForUI` directly; controllers become pure consumers of `BindingHandle`s.
- Enforce a strict three-layer separation per UI subtree:
  1. **Presence** (does the Instance exist right now — owned solely by the Bind Manager),
  2. **Visibility** (should it be `Visible = true` given current mode/round state — a pure function of state, no side effects),
  3. **Gameplay state** (input vectors, cooldown timers, etc. — never mutated inside a visibility function).
- Fold `WaitForUI.lua`'s responsibility into the Bind Manager so there is one blocking/async resolution primitive in the codebase, not two parallel ones (`PathResolver.waitForPath` vs. `WaitForUI`).

### 2.4 Step-by-Step Implementation Roadmap
1. Inventory every `ProjectTreeSpec.UI.*` subtree currently resolved independently by `UIBinder`, `UIController`, `LauncherUIController`, and `PlayerModeController`; produce a single ownership map (one subtree → one owning controller).
2. Build the `UiBindManager` with `Bind`/`OnBound`/`OnLost` and back it with the existing `PathResolver` (no need to replace `PathResolver`'s core traversal logic — only its call sites).
3. Migrate `LauncherUIController`'s 10+ cached locals to `BindingHandle` lookups one at a time, starting with `cachedScreenGui`/`cachedJoystickRoot` (highest reuse).
4. Migrate `UIController:_resolveUiReferences()` field-by-field to the same manager; remove its independent `Heartbeat` re-resolution once `OnBound`/`OnLost` is proven reliable.
5. Replace `PlayerModeController`'s raw `findHumanLauncherToggle()` walk with a `Bind("MainHub.HumanLauncherToggle")` call so it participates in the same lifecycle instead of bypassing `ProjectTreeSpec`.
6. Split `applyJoystickVisibilityFromState()` into a pure visibility-computation function and a separate input-state-reset function; call both explicitly rather than conflating them.
7. Deprecate `WaitForUI.lua` once its one remaining call site (if any) is migrated to the Bind Manager's async path.
8. Add an integration test that clones the entire `LauncherUI`/`MainHUD` tree *after* all four controllers have started, and asserts zero missing-reference warnings and correct final binding state.

---

## 3. EndRound Infinite Loop / Freeze Bug

### 3.1 Target File Paths & Dependencies
- `src/ServerScriptService/Services/RoundService.lua` — `Init()` (EndRound remote wiring, line ~65–68), `RequestEndRound()` (line 107), `_beginRoundEnd()` (lines 283–311), `_step()` (line 350).
- `src/ServerScriptService/Services/ProgressPointService.lua` — `AwardEndRoundPoints()` (lines 102–133), invoked synchronously inside `_beginRoundEnd`.
- `src/ServerScriptService/Services/LeaderboardService.lua` — `GetTopPlayers()` (line 207), `_getSortedPlayers()` (`table.sort` comparator, lines 142–162), `_buildRow()` (lines 191–205).
- `src/ReplicatedStorage/Client/Services/LobbyClientService.lua` — `RequestEndRound()` (line 109).
- `src/ReplicatedStorage/Client/Controllers/UIController.lua` — EndRound button binding (lines 184, 303–306).
- `src/ReplicatedStorage/Client/Services/MatchSummaryDataService.lua` — `dc()` deep-copy (line 3), `SetFromState()` (line 9), consumed by `MatchSummaryUIController.lua`.
- `src/ReplicatedStorage/Shared/ProjectTreeSpec.lua` (line 13) vs. `PROJECT_TREE.md` (line 334) — path source-of-truth for the `EndRoundButton` GUI node.
- `src/ReplicatedStorage/Shared/RemoteContracts.lua` — `EndRound` validator (line 92).

### 3.2 Risk Analysis
- **Confirmed desync (highest-confidence lead).** `ProjectTreeSpec.lua` line 13 declares `EndRoundButton = "UnitTestUI.RootFrame.EndRoundButton"`. `PROJECT_TREE.md` (the document the brief identifies as ground truth) lists the actual node under `UnitTestUI.RootFrame` as `EndRound`, **not** `EndRoundButton` (line 334). `UIController:_resolveUiReferences()` resolves this path with `shouldWarn = false` via `resolveGuiButton`, which itself calls `PathResolver.resolvePath` with no `waitTimeout` — so today this most likely just silently fails to bind (`self.EndRoundButton` stays `nil`, and the `if self.EndRoundButton then ... end` guard at line 303 never connects a click handler at all). This alone does not explain a *freeze*, but it means the current click handler is only reachable at all if a differently-named/duplicate button exists in the live Studio place file that shadows the intended one — which is a strong signal that whatever button is actually wired up in Studio right now was bound by hand against stale/adhoc naming rather than through `ProjectTreeSpec`, undermining the "path spec is authoritative" contract this objective (and Objective 4) depends on.
- **No blocking/`while`/recursive loop found server-side.** `RoundService._beginRoundEnd()`, `ProgressPointService.AwardEndRoundPoints()`, and `LeaderboardService.GetTopPlayers()`/`_getSortedPlayers()` were traced line-by-line: the `table.sort` comparator in `_getSortedPlayers()` (lines 144–160) is a valid strict-weak-ordering (points → level → UserId tie-break), so it will not hang or error; there is no unbounded `while`/`repeat` anywhere in the EndRound call chain; all loops are bounded by `Players:GetPlayers()` or a fixed leaderboard limit.
- **Latent risk identified for future regressions.** `MatchSummaryDataService.lua` line 3 defines `dc()`, a recursive deep-copy with **no cycle detection and no depth limit**, applied to every `MatchSummaryUpdate` payload (`SetFromState`, line 9). The current payload shape built in `ProgressPointService.AwardEndRoundPoints` (`table.clone(row)` over flat `LeaderboardService._buildRow` rows) is flat today, so `dc()` does not currently recurse pathologically — but it is one incautious future edit away (e.g. embedding a live `Player` reference inside a nested sub-table, or a row referencing another row) from a stack overflow that would present exactly as "clicking EndRound freezes the game," since it runs synchronously on `MatchSummaryUIController`'s data-receipt path.
- **Deployment risk — the feature is explicitly marked debug-only and untested for production traffic.** The `-- TODO: RequestEndRound is a debug-only UnitTestUI hook. Remove this remote before public release.` comment (`RoundService.lua` line 65) confirms this path has never been hardened; `RemoteContracts.lua`'s `EndRound` validator (line 92) takes no arguments and always returns `true`, so there is no server-side guard against a client spamming the remote (e.g. via a modified client or double-click) and re-entering `_beginRoundEnd()` mid-transition — `_beginRoundEnd()` does early-return on `RoundState == RoundEnd/PostRound` (line 284) which mitigates literal re-entrancy, but there's no debounce on the click itself client-side.

### 3.3 Proposed Architectural Solution
- Treat the `EndRoundButton` path mismatch as a required fix under Objective 4 (ProjectTree sync) before attempting to reproduce/diagnose the freeze further — a stale/duplicate hand-wired button is a confound that must be removed first so the freeze can be reproduced against the actual `ProjectTreeSpec`-driven binding.
- Add lightweight, always-on server-side instrumentation around the EndRound call chain (structured `debug.profilebegin`/`profileend` blocks or timestamped `print`s around `_beginRoundEnd`, `AwardEndRoundPoints`, `GetTopPlayers`) gated behind a debug flag, so the next reproduction attempt produces a timing trace rather than a bare "it froze."
- Harden `MatchSummaryDataService.dc()` with a bounded-depth, cycle-safe clone (or replace ad hoc deep-copy with a single shared, audited utility used by both `MatchSummaryDataService` and `MockData`/`MockProvider`'s existing `deepCopy` implementations, consolidating three near-duplicate deep-copy functions in the codebase into one).
- Add a debounce/one-shot guard on the client `EndRoundButton` click handler (disable-on-click, re-enable on next `MatchStateUpdate`) so accidental double-firing cannot compound whatever the root timing issue turns out to be.

### 3.4 Step-by-Step Implementation Roadmap
1. Fix the `EndRoundButton` path in `ProjectTreeSpec.lua` to match the authoritative node name in `PROJECT_TREE.md` (or vice versa, per Objective 4's sync decision) and confirm in Studio that exactly one `EndRound`-labeled button exists under `UnitTestUI.RootFrame`.
2. Re-run the reproduction with the corrected binding in a clean Studio session with `output` open; confirm whether the freeze still occurs against the *actually intended* button.
3. Add temporary profiling markers around `RequestEndRound → _beginRoundEnd → AwardEndRoundPoints → GetTopPlayers/_getSortedPlayers → FireAllClients(MatchSummaryUpdate) → MatchSummaryDataService:SetFromState → dc()` to capture where wall-clock time is actually spent.
4. If the trace shows time concentrated in `dc()`/client-side rendering, harden the deep-copy utility (cycle/depth guard) and consolidate the three duplicate deep-copy implementations (`MatchSummaryDataService.dc`, `MockData.deepCopy`, `MockProvider.deepCopy`) into one shared, tested utility.
5. If the trace shows time concentrated server-side, inspect `LeaderboardService:GetTopPlayers()` under realistic player counts (the seeded 125 mock leaderboard profiles in `MockProvider` are a good stress-test population) for `table.sort` comparator cost at scale.
6. Add a client-side click debounce and a server-side `RemoteContracts.EndRound` payload/rate validator consistent with the rate-limiting pattern already used for `MoveRequest` in `RateLimiter.lua`.
7. Once resolved, action the existing TODO: gate the `EndRound` remote/button behind a Studio-only or admin-only check before public release, rather than leaving it exposed to any client.

---

## 4. ProjectTree Synchronization & Formatting

### 4.1 Target File Paths & Dependencies
- `PROJECT_TREE.md` (717 lines) — declared ground truth for UI structure.
- `src/ReplicatedStorage/Shared/ProjectTreeSpec.lua` (345 lines) — machine-readable mirror consumed by `PathResolver`.
- Every consumer of `ProjectTreeSpec`: `UIBinder.client.lua`, `UIController.lua`, `LauncherUIController.client.lua`, `PathResolver.lua`.

### 4.2 Risk Analysis
- **Confirmed drift #1 (functional).** `ProjectTreeSpec.UI.Lobby.EndRoundButton` = `"UnitTestUI.RootFrame.EndRoundButton"` vs. `PROJECT_TREE.md` line 334's actual node name `EndRound`. This is a functional bug, not merely cosmetic — see Objective 3.
- **Confirmed drift #2 (backend Config paths).** `PROJECT_TREE.md`'s `ReplicatedStorage.Shared.Config` listing (lines ~30–43) includes `Config.lua`, `FoodConfig.lua`, and `LaunchershotConfig.lua` — none of which exist at `src/ReplicatedStorage/Shared/Config/` today. (`FoodConfig.lua` actually lives at `src/ServerScriptService/Config/FoodConfig.lua`, a different service entirely.) Conversely, several files that *do* exist there today — `LauncherAnimationIds.lua`, `NotificationConfigData.lua`, `PhysicsConfig.lua`, `QuestConfig.lua`, `RankConfig.lua`, `SafeZoneConfig.lua` — are absent from `PROJECT_TREE.md`'s listing entirely. This section of `PROJECT_TREE.md` is *not* currently more accurate than the source tree and should not be assumed authoritative without a targeted audit; the brief's instruction to treat `PROJECT_TREE.md` as ground truth should be scoped explicitly to the **UI/StarterGui hierarchy**, where the evidence supports it, and re-verified section-by-section elsewhere.
- **Confirmed drift #3 (ordering).** Both documents already violate strict A–Z ordering in multiple places today — e.g. `PROJECT_TREE.md`'s `Config` folder listing is ordered `AbilityConfig, BalanceConfig, Config.lua, EquipmentConfig, EquipmentUpgradeConfig, FoodConfig, GachaRewardConfig, GameConfig, ItemConfig, LevelConfig, LauncherConfig, LaunchershotConfig, TrapConfig` — `LevelConfig` is out of order relative to `LauncherConfig`. The `UnitTestUI.RootFrame` listing (lines 329–335) is not alphabetical either (`DebugFood, DebugReset, JoinButton, LeaveButton, Plus1Minute, EndRound, StartSafeZoneButton`). This confirms the requested alphabetization is a real, needed cleanup, not a no-op.
- **Formatting risk.** `PROJECT_TREE.md` uses hand-drawn box characters (`├─`, `│`, `└─`, plus a visually distinct nested style using `├──`/`│  ` in the `Assets` subsection, e.g. lines 63–75) with **inconsistent indentation width between sections** (compare the `Shared` subtree's 2-space-per-level box-drawing vs. the `Assets/Prefabs` subtree's 3-space variant a few lines below it). Any naive line-based alphabetical sort must preserve each line's *existing* prefix (box-drawing glyphs + whitespace) verbatim and only reorder sibling *label* text within a shared parent — a generic text-sort would corrupt the tree structure and blank margin lines.

### 4.3 Proposed Architectural Solution
- Treat synchronization as **two separate passes**, not one:
  1. A **structural audit pass**: for every leaf in `ProjectTreeSpec.lua`, confirm whether the corresponding `PROJECT_TREE.md` node exists, and vice versa, producing a diff report grouped by DataModel service (`ReplicatedStorage`, `StarterGui`, `ServerScriptService`, …). Only the `StarterGui`/UI portions should be corrected by copying `PROJECT_TREE.md`'s naming into `ProjectTreeSpec.lua` per the brief; drift found in the `ServerScriptService`/`Config` sections should be resolved by correcting `PROJECT_TREE.md` against the real source tree, since that's the section where the *code*, not the doc, is demonstrably correct.
  2. A **formatting pass**: a small offline script (run manually, not part of runtime code) that parses `PROJECT_TREE.md` into a tree of `(depth, prefix-glyphs, label)` tuples using the existing indentation as the depth signal, sorts each sibling group's labels alphabetically in place, and re-emits the file using each line's original prefix template for its depth/branch position — never touching blank margin lines, section headers (`## 🟦 ReplicatedStorage`, etc.), or comment/type annotations.
- `ProjectTreeSpec.lua` generation should ultimately be **derived from** `PROJECT_TREE.md` (or a shared intermediate JSON) rather than hand-maintained in parallel, to prevent this class of drift from recurring. Until that tooling exists, add a lightweight CI/lint check that flattens both files' UI paths and fails the build on any set difference (this is a natural extension of `PathResolver.collectPaths`, which already exists and is already used at startup).

### 4.4 Step-by-Step Implementation Roadmap
1. Run a diff between `PathResolver.collectPaths(ProjectTreeSpec.UI)` and a parsed path-set from `PROJECT_TREE.md`'s `StarterGui` section; produce a concrete mismatch list (the `EndRoundButton`/`EndRound` case is the first confirmed entry).
2. Correct `ProjectTreeSpec.lua`'s UI paths to match `PROJECT_TREE.md`'s actual node names, one subsystem at a time (Lobby → MainHub → Match → Panels), re-running the diff after each subsystem to catch regressions.
3. Separately audit the non-UI sections (`Config`, `Utils`, `Constants`) where `PROJECT_TREE.md` was shown to be stale relative to the real source tree; correct `PROJECT_TREE.md` itself here rather than the code.
4. Build the offline alphabetization script: parse indentation depth + box-drawing prefix, group by immediate parent, sort labels only, re-emit using the original per-line prefix template. Validate on a copy of the file first with a byte-level diff limited to reordered *label* text — zero changes to prefixes, glyphs, or blank lines.
5. Run the alphabetization script against the corrected `PROJECT_TREE.md`; manually spot-check the previously-noted problem areas (`Config` folder, `UnitTestUI.RootFrame`) to confirm correct ordering and unchanged margins.
6. Regenerate/hand-correct `ProjectTreeSpec.lua` once more against the now-sorted `PROJECT_TREE.md` so both stay in lockstep.
7. Add the CI/lint path-diff check described above so future edits to either file are caught automatically instead of silently drifting again.

---

## 5. Cooldown UI Component Consolidation

### 5.1 Target File Paths & Dependencies
- `src/StarterPlayer/StarterPlayerScripts/Components/CooldownOverlayComponent.lua` (radial-wipe overlay via `LeftHalf`/`RightHalf` `Clip` rotation).
- `src/StarterPlayer/StarterPlayerScripts/Components/CooldownTextComponent.lua` (numeric countdown label).
- `src/StarterPlayer/StarterPlayerScripts/Components/CooldownComponent.lua` (a third, currently-separate cooldown-related component file — its relationship to the two above should be clarified/folded into the same consolidation effort).
- `src/StarterPlayer/StarterPlayerScripts/LauncherUIController.client.lua` — sole consumer/owner of both components; `resolveUi()` (lines 267–272, construction), `updateCooldownVisuals()` (lines 365–387), `stepUi()`/`ensureUiLoopRunning()` (lines 536–572), `syncCooldownFromServerState()` (lines 619–631, 803–839).
- `src/ReplicatedStorage/Shared/Utils/LauncherCooldownService.lua` — the authoritative time-math (`Begin`, `IsActive`, `GetRatio`, `GetRemainingTime`).
- `src/ReplicatedStorage/Shared/Constants/LauncherUiConstants.lua` — `Elements.CooldownOverlay`/`Elements.CooldownText` name constants.

### 5.2 Risk Analysis — **root cause of the "fails to count down" bug identified**
- `LauncherUIController.client.lua`'s `stateUpdateRemote.OnClientEvent` handler (lines 803–839) calls `syncCooldownFromServerState(state)` (line 833) **every single time** the server broadcasts a `StateUpdate` while `state.CooldownEndTime > os.clock()` — i.e., on every network tick for the *entire* duration of an active cooldown, not just once when the cooldown begins.
- `syncCooldownFromServerState()` (lines 619–631) unconditionally calls `beginCooldown(resolvedDuration, serverCooldownEnd)` with no check for "is this the same cooldown episode I already started, or a new one?"
- `beginCooldown()` (lines 574–582) calls `cooldownService:Begin(...)` (harmless — recomputes the same start/end times) **and then explicitly calls `updateCooldownVisuals(0, cooldownDuration)`** — i.e., it forces the overlay/text to redraw at **0% progress / full remaining duration**, every time it runs.
- Independently, `stepUi()` — driven by a `RunService.RenderStepped` connection established via `ensureUiLoopRunning()` — correctly recomputes and displays the *real*, decreasing `cooldownRatio`/`remainingTime` every rendered frame (lines 553–560).
- **Net effect:** every time a `StateUpdate` arrives mid-cooldown (which, given this is the primary state-sync channel for movement/charge/mode as well, is expected to fire far more often than once per cooldown), the display is yanked back to "just started" immediately after the render loop had correctly advanced it — producing exactly the symptom described: *the cooldown UI appears frozen / fails to visibly count down*, because it is being reset almost as fast as it progresses.
- **Coupling risk.** This bug exists precisely because "did a new cooldown start" and "refresh the display from authoritative state" are not distinguished — the same function (`beginCooldown`) is used for both a true state transition (cooldown just began) and a redundant resync (cooldown already running, server merely re-confirmed it). Consolidating the two components without first fixing this call pattern would simply reproduce the same bug inside a merged component.
- **Duplication risk.** `CooldownOverlayComponent` and `CooldownTextComponent` each independently define `warnMissing(name)` and a `getGuiObject`-style existence check, each independently track a `Root` field and a `Destroy()` method, and are constructed/torn down together in lockstep at every call site in `LauncherUIController` (lines 267–272, 370–384) — they are never used independently, which is itself the argument for merging them into one component with one lifecycle.

### 5.3 Proposed Architectural Solution
- **Fix the state-vs-resync conflation first, independent of the merge.** `syncCooldownFromServerState()` should compare the incoming `serverCooldownEnd` against the cooldown service's *currently tracked* `cooldownEndTime` (already exposed via `LauncherCooldownService:GetState()`); only call `beginCooldown()` (the "reset display to 0%/full" path) when the value has actually changed (i.e., a genuinely new cooldown episode), and no-op (or, if desired, perform a cheap reconciliation without resetting the visual bucket) when it's simply reconfirming the same episode already in progress.
- **Merge `CooldownOverlayComponent` + `CooldownTextComponent`** (and audit `CooldownComponent.lua` for overlap) into a single `CooldownDisplayComponent` that:
  - Owns one `Root`/lifecycle, resolves both the radial overlay (`LeftHalf`/`RightHalf`/`Clip`) and the text label under one `joystickRoot` in one constructor pass, sharing the single `getGuiObject`/`warnMissing` helper instead of two copies.
  - Exposes one `Update(visible: boolean, progress: number?, remainingTime: number?)` entry point that internally derives both the sweep-degrees (overlay) and the bucketed display text, replacing today's two separate `:Update(...)` calls with divergent signatures.
  - Consumes `LauncherCooldownService`'s ratio/remaining-time directly (already server-authoritative-derived), so the "no client-side calculation errors" requirement is satisfied by construction rather than by convention.

### 5.4 Step-by-Step Implementation Roadmap
1. Add an "already-tracking-this-episode" guard to `syncCooldownFromServerState()` so repeated `StateUpdate` broadcasts for the same `CooldownEndTime` do not re-invoke the 0%-reset path; verify the fix with a manual test (trigger a launch, watch the overlay/text count down smoothly across multiple `StateUpdate` ticks in `output`/a debug overlay).
2. Audit `CooldownComponent.lua` to determine whether it is a leftover/experimental predecessor of the other two, or serves a distinct purpose; document the finding before deciding whether it is deleted or merged in as well.
3. Design the merged `CooldownDisplayComponent` API (single constructor, single `Update`, single `Destroy`) and confirm it covers every call site currently split across the two components in `LauncherUIController.client.lua`.
4. Replace `cooldownOverlayComponent`/`cooldownTextComponent` (two locals, lines 74–75) with a single `cooldownDisplayComponent` local; update `resolveUi()` construction (lines 267–272) and every `:Update(...)` call site (lines 171–176, 370–384) to the new unified API.
5. Remove the now-unused `CooldownOverlayComponent.lua`/`CooldownTextComponent.lua` files (and `CooldownComponent.lua` if step 2 confirms it's superseded).
6. Regression-test: verify cooldown visuals across (a) a normal single launch, (b) rapid repeated launches, (c) a mode switch mid-cooldown (Launcher → Human), (d) a `CharacterAdded`/pawn respawn mid-cooldown — all should show smooth, monotonically-decreasing countdowns with no visual "snap back."

---

## 6. Persistence & Rich MockData Generation

### 6.1 Target File Paths & Dependencies
- `src/ServerScriptService/Services/DataProviders/MockData.lua` — rich, hand-authored profiles (`OwnedEquipment` with `definitionId`/`level`/`rarity`/`acquiredAt`/`isTemporary`/`expiresAt`; `OwnedLaunchers` with `star`/`level`/`temporaryState`); exposes `GetProfileByUserId`/`GetDefaultPlayerProfile`.
- `src/ServerScriptService/Services/DataProviders/MockProvider.lua` — the actual `IDataProvider` implementation wired into gameplay; owns `MOCK_SCHEMA_DEFAULTS`, `_seedLeaderboardProfiles()`, `LoadPlayerData`/`SavePlayerData`/`GetPlayerData`/`UpdatePlayerData`.
- `src/ServerScriptService/Services/IDataProvider.lua` — the abstraction contract (`LoadPlayerData`, `SavePlayerData`, `GetPlayerData`, `UpdatePlayerData`, `ClearPlayerData`).
- `src/ServerScriptService/Services/PlayerDataService.lua` — `BuildDefaultData()` (lines 26–49), `LoadPlayer()` (line 64, calls `self._provider:LoadPlayerData(player, self:BuildDefaultData(player))`), hardcodes `require(script.Parent.DataProviders.MockProvider)` (line 5) rather than depending only on `IDataProvider`.
- `src/ServerScriptService/Services/EquipmentService/EquipmentService.lua` — equip/unequip logic consuming `PlayerDataService`'s `OwnedEquipment`/`EquippedEquipment`.
- `src/ReplicatedStorage/Shared/Config/EquipmentConfig.lua` / `LauncherConfig.lua` — definition catalogs that owned-instance `definitionId`s must resolve against.

### 6.2 Risk Analysis
- **Confirmed: `MockData.lua`'s rich profile data is currently orphaned.** `MockProvider.LoadPlayerData()` never calls `MockData.GetProfileByUserId`/`GetDefaultPlayerProfile` anywhere. Real players are seeded exclusively from `MOCK_SCHEMA_DEFAULTS` (`MockProvider.lua` lines 10–24: `OwnedEquipment = {}`, a single `default_normal_launcher`), merged with `PlayerDataService:BuildDefaultData()` (also an empty `OwnedEquipment = {}`, no launcher data at all). The two `MockPlayerAlpha`/`MockPlayerBeta` profiles in `MockData.lua`, complete with rarity/level/temporary-equipment examples, are dead code today — every real player starts with zero equipment and the single default launcher regardless of what `MockData.lua` describes.
- **Naming collision risk.** There are, confusingly, **three** distinctly-scoped files named `MockData.lua` in this codebase: `src/ServerScriptService/Services/DataProviders/MockData.lua` (server, the one relevant here), `src/ReplicatedStorage/Client/Services/MockData.lua` (client), plus a related `src/ReplicatedStorage/Client/Services/MockInventoryData.lua` and `MockPlayerData.lua`. Any engineer asked to "expand MockData" needs an explicit pointer to the correct file, and long-term this naming should be disambiguated (e.g. `ServerMockProfileSeeds.lua`) to prevent accidental edits to the wrong file.
- **Coupling risk — `PlayerDataService` hardcodes `MockProvider`.** `PlayerDataService.lua` line 5 does `require(script.Parent.DataProviders.MockProvider)` directly and line 22 defaults `self._provider = provider or MockProvider.new()`. While an injectable `provider` parameter exists (good — this is the seam a future DataStore provider would use), nothing in the current wiring path (`Main.server.lua`) demonstrates this injection actually happening anywhere else, so today `MockProvider` is a de facto hard dependency rather than a swappable one in practice. The "zero changes to gameplay logic" requirement for a future DataStore migration depends entirely on every gameplay system going through `IDataProvider`'s five methods and nothing else — this should be explicitly audited, since `EquipmentService`/`ProgressPointService` etc. currently call into `PlayerDataService` (correct layering) rather than the provider directly, which is the right pattern, but it has not been verified exhaustively across every service in this pass.
- **Data integrity risk for equipping/triggering mock equipment.** `MockData.lua`'s example `OwnedEquipment` entries reference `definitionId`s (`Poison`, `GhostFlame`, `PowerCore`) that **do** exist in `EquipmentConfig.Definitions` today — good, these are valid references. However `MockData.lua`'s `OwnedLaunchers` reference `definitionId`s (`NormalLauncher`, `FireLauncher`, `PetrifyLauncher`, `VacuumLauncher`) that were **not** verified against `LauncherConfig.lua` in this pass and must be cross-checked before the mock data is wired up live, or newly-equipped mock launchers will silently fail to resolve.

### 6.3 Proposed Architectural Solution
- Wire `MockData.lua`'s profile system into `MockProvider.LoadPlayerData()` as the actual seed path for real players (not just the 125 synthetic leaderboard-filler profiles `_seedLeaderboardProfiles()` already generates) — e.g., match by `UserId` for known test accounts and fall back to `MOCK_SCHEMA_DEFAULTS` merged with a *randomly assigned* `MockData` template for everyone else, so ordinary playtesting exercises the full equip/launcher/rarity pipeline rather than always starting from an empty inventory.
- Expand `MockData.PlayerProfiles` with additional profiles covering: multiple equipped-equipment loadouts (all 3 slots filled), at least one profile per rarity tier, at least one `isTemporary`/`expiresAt` equipment example actually near-expiry (to exercise expiry-handling code paths), and multiple launcher star/level combinations — directly satisfying "owned instances, levels, rarity, equipped state, slots, and test profiles."
- Cross-validate every `definitionId` referenced in `MockData.lua` against `EquipmentConfig.GetAllIds()`/the launcher equivalent as an explicit, scripted consistency check (analogous to the `PathResolver`/`ProjectTreeSpec` diff proposed in Objective 4) — mock data referencing a non-existent definition should fail fast at server start, not silently produce an unequippable item.
- Consolidate the three duplicate `deepCopy` implementations (`MockData.deepCopy`, `MockProvider.deepCopy`, and `MatchSummaryDataService.dc`, flagged in Objective 3) into one shared, tested utility used by all mock/data-provider code — this directly serves "MockProvider remains the exclusive persistence layer" by giving that layer one canonical, audited copy semantics instead of three near-identical hand-rolled ones.
- Formalize the `IDataProvider`-only contract: add a lightweight lint/convention check (or code-review checklist item) confirming no gameplay service ever requires `MockProvider` directly — only `PlayerDataService` may, and everything else goes through `PlayerDataService`'s public API — so the eventual DataStore-backed provider really is a drop-in replacement with zero gameplay-logic changes.

### 6.4 Step-by-Step Implementation Roadmap
1. Cross-validate all `definitionId`s in the existing `MockData.lua` profiles against `EquipmentConfig.lua` and `LauncherConfig.lua`; fix or annotate any that don't resolve.
2. Wire `MockData.GetProfileByUserId`/`GetDefaultPlayerProfile` into `MockProvider.LoadPlayerData()`, gated so it doesn't disturb the existing 125-profile synthetic leaderboard seeding (`_seedLeaderboardProfiles`), which serves a different purpose (leaderboard stress data, not equip-flow testing).
3. Expand `MockData.PlayerProfiles` with the additional coverage enumerated above (full 3-slot loadouts, all rarity tiers, near-expiry temporary equipment, varied launcher star/level).
4. Manually verify, in Studio, that a seeded mock profile's equipment can be equipped via `EquipmentService` and that the corresponding ability/effect fires correctly through `EquipmentAbilityService`/`EquipmentEffectService` (Objective 8's pipeline) end-to-end.
5. Consolidate the three duplicate deep-copy implementations into one shared utility; migrate `MockData.lua`, `MockProvider.lua`, and `MatchSummaryDataService.lua` to it.
6. Audit every current `require(...DataProviders.MockProvider)` call site outside of `PlayerDataService.lua` (if any exist) and refactor them to go through `PlayerDataService`/`IDataProvider` instead.
7. Document the `IDataProvider` contract and the "only `PlayerDataService` may construct a provider" rule directly in `IDataProvider.lua`'s header comment, so the boundary is explicit for the next engineer (and for the future DataStore-provider author).

---

## 7. Legacy Client Equipment Logic Cleanup

### 7.1 Target File Paths & Dependencies
- `src/ServerScriptService/Services/EquipmentAbilityService/EquipmentAbilityService.lua` — the new, server-authoritative active-ability pipeline (`AbilityTrigger` remote, `ChargeStarted`/`LauncherLaunched`/`DamageDealt` event-bus hooks).
- `src/ServerScriptService/Services/EquipmentEffectService/EquipmentEffectService.lua` — the new passive/collision-driven effect pipeline (`EquipmentEquipped`/`EquipmentUnequipped`/`EquipmentUpdated`/`LauncherLaunched`/`CollisionDetected`/`PlayerAttack` hooks; registered effect modules under `EquipmentEffects/`).
- `src/ServerScriptService/Services/LauncherAbilityService/LauncherAbilityService.lua` and its `Abilities/Stealth.lua`, `Abilities/Stun.lua`, `Abilities/Vacuum.lua` — the **older**, launcher-item-centric ability system that predates the Equipment system.
- `src/ServerScriptService/Services/EquipmentService/EquipmentService.lua` — equip/unequip request handling and slot validation.
- Client: `src/StarterPlayer/StarterPlayerScripts/InputController.client.lua`, `Components/BuffPanel.lua`, `Components/SkillButton.lua`, `Components/AttributePanel.lua` — the surfaces the brief flags as mixing legacy orchestration with new equipment logic.

### 7.2 Risk Analysis
- **This pass's findings differ slightly from the brief's framing and should be flagged back to the team before scoping the cleanup work.** A targeted search of every file under `src/StarterPlayer/StarterPlayerScripts/` for `Ability`, `Stealth`, and `Vacuum` returned **zero matches** in the current `main` snapshot — the client-side scripts inspected in this pass (`InputController.client.lua`, `SkillButton.lua`, `BuffPanel.lua`, `AttributePanel.lua`) are either generic UI-stub components (following the repo's `[UI_CREATION_GUIDE]` pattern, with no embedded gameplay logic) or don't reference the legacy ability vocabulary at all. This means either (a) the legacy/new mixing described in the brief has already been partially cleaned up ahead of this audit, (b) it is expressed through indirection this static pass didn't surface (e.g. generic remote payload shapes rather than named references), or (c) the primary coupling actually lives **server-side**, where `LauncherAbilityService` (old, launcher-item-triggered abilities like Stealth/Stun/Vacuum) and `EquipmentAbilityService`/`EquipmentEffectService` (new, equipment-item-triggered) currently run as two fully parallel systems against the same `AbilityTrigger`/`LauncherLaunched`/collision event surface.
- **Confirmed structural risk regardless of client findings: two parallel ability authorities exist server-side.** `LauncherAbilityService.lua` and `EquipmentAbilityService.lua` both listen to `LauncherLaunched` independently (`EquipmentAbilityService.lua` line ~38: `self._context.EventBus:On("LauncherLaunched", function(player, chargeRatio, launchState) self:_handleLaunch(player, chargeRatio, launchState) end)`), and both maintain their own per-player ability/cooldown bookkeeping. Nothing in the reviewed code establishes an explicit precedence or mutual-exclusion contract between "this stun/petrify/stealth came from an equipped Launcher" vs. "this came from equipped Equipment" — both are free to fire on the same event.
- **Comment-level evidence the split is a known, live concern.** `EquipmentAbilityService.lua` contains the inline comment `"-- Equipment-driven collision status effects and Food DoTs are owned exclusively by EquipmentEffectService."` — i.e., the team has already begun explicitly documenting ownership boundaries in-line as they encounter overlap, which corroborates that this is an active, real cleanup in progress rather than a hypothetical.

### 7.3 Proposed Architectural Solution
- Before writing any decoupling code, run a **second, deeper audit pass** specifically for indirect legacy/new mixing: trace every remote payload shape flowing through `AbilityTrigger` (both `EquipmentAbilityService` and `LauncherAbilityService` listen to related events) end-to-end from client dispatch to server handler, since the brief's description implies a coupling this static pass's direct string search did not surface. This should be the first concrete task handed to an engineer, ahead of any removal work.
- Define an explicit **single active-ability authority per trigger event**: for each of `ChargeStarted`/`LauncherLaunched`/`CollisionDetected`/`PlayerAttack`, designate exactly one owning service (per the `EquipmentAbilityService` comment's precedent — "owned exclusively by X") and either migrate `LauncherAbilityService`'s remaining launcher-item abilities (Stealth/Stun/Vacuum) into the `EquipmentEffectService`'s registered-effect-module pattern (Objective 8's extensibility point), or keep them as a genuinely separate, clearly-scoped system with a documented non-overlapping event contract — but not both ambiguously as today.
- Once server-side ownership is unambiguous, re-audit the client for any UI/input code that special-cases old launcher-ability names (`Stun`, `Stealth`, `Vacuum`) instead of treating all active abilities generically via the `AbilityTrigger` contract, and remove any such special-casing found.

### 7.4 Step-by-Step Implementation Roadmap
1. Run the deeper, indirection-aware audit described above (remote payload tracing, not just string search) to confirm or correct this pass's finding that client-side legacy/new mixing wasn't directly observable in `main` today.
2. Map every event (`ChargeStarted`, `LauncherLaunched`, `CollisionDetected`, `PlayerAttack`, `AbilityTrigger`) to its current listener(s) across both `LauncherAbilityService` and `EquipmentAbilityService`/`EquipmentEffectService`; flag every event with more than one listener as a potential ownership conflict.
3. For each flagged event, decide and document single ownership, following the precedent already set by the existing in-code comment in `EquipmentAbilityService`.
4. Migrate `LauncherAbilityService.Abilities.{Stealth,Stun,Vacuum}` into `EquipmentEffectService`'s `EquipmentEffects/` registration pattern where they conceptually belong (several — Stun, Petrify — already have direct Equipment-side equivalents in `EquipmentEffects/`), or explicitly re-scope `LauncherAbilityService` to a narrower, non-overlapping responsibility if a full migration isn't warranted this cycle.
5. Remove `LauncherAbilityService` event listeners for any event now exclusively owned by the Equipment pipeline.
6. Re-run the client audit for any residual legacy-ability-specific branching once server ownership is settled, and remove it.
7. Add an automated check (or code-review rule) that no new event listener is added to more than one ability/effect service without an explicit, documented ownership decision — preventing this ambiguity from recurring as new equipment types (Objective 8) are added.

---

## 8. Implementation Plan for 20 New Equipment Types

### 8.1 Target File Paths & Dependencies
- `src/ReplicatedStorage/Shared/Config/EquipmentConfig.lua` — the single definition catalog (`EquipmentConfig.Definitions`); the `equipment(...)` factory (lines 55–70) and existing `Categories`/`Rarities` enums.
- `src/ServerScriptService/Services/EquipmentEffectService/EquipmentEffectService.lua` — the registered-effect-module pattern (`RegisterEffect`, `Dispatch`) and its event-bus hooks (`EquipmentEquipped`/`Unequipped`/`Updated`, `LauncherLaunched` → `OnLaunch`, `CollisionDetected`/`CollisionPlayerHit` → `OnCollision`, `PlayerAttack` → `OnAttack`).
- `src/ServerScriptService/Services/EquipmentEffectService/EquipmentEffects/*.lua` — one module per registered effect id (`Poison`, `Fire`, `Slow`, `Stun`, `Petrify`, `ExpBonus`, `Magnet`, `Shield`, `Titan`, `SmokeBomb`, `NoOp`).
- `src/ServerScriptService/Services/EquipmentAbilityService/EquipmentAbilityService.lua` — the active-trigger (cooldown-gated, player-initiated) pipeline, for equipment that fires on demand rather than passively.
- `src/ServerScriptService/Services/Shared/BaseAbility.lua` — shared base class already used by `EquipmentAbilityService`.
- `src/ServerScriptService/Services/DamagePipelineService.lua`, `CollisionService.lua`, `Helpers/CollisionValidation.lua`, `Helpers/HitCooldownDedupe.lua` — combat pipeline any damage/status-effect equipment must integrate with.
- `src/ReplicatedStorage/Shared/Utils/StatusEffectVfx.lua`, `EquipmentStatResolver.lua`, `LauncherStatResolver.lua` — shared VFX and stat-aggregation utilities.
- `src/ReplicatedStorage/Assets/Equipment/` (model assets) — currently confirmed to already contain models for `Poison`, `GhostFlame`, `PowerCore`, `BrainBoost`, `ThunderHammer`, `Medusa` per `PROJECT_TREE.md`.

### 8.2 Risk Analysis
- **Confirmed: 10 of the 20 requested equipment types already exist as definitions today**, with the following overlap and — critically — two **semantic conflicts** that must be resolved before implementation, not discovered during it:

| Requested (this brief) | Existing in `EquipmentConfig.Definitions` today | Conflict? |
|---|---|---|
| Plasma Cannon | — (net new) | — |
| Magnet Core (10-stud radius) | `Magnet` (`passiveAbility.value = 10`) | Likely just a rename/skin — value already matches "10-stud radius" |
| ThunderHammer (stun) | `ThunderHammer` (`abilityId = "Stun"`) | None — already matches |
| Medusa (petrify) | `Medusa` (`abilityId = "Petrify"`) | None — already matches |
| Ice Crystal (freeze) | — (net new; no `Freeze` effect module exists — `Slow.lua` is the closest analog) | — |
| GhostFlame (DoT burn, 3s) | `GhostFlame` (`abilityId = "Fire"`, `dotFlag = "Burn"`) | Verify existing `Fire.lua` duration matches "3s"; not confirmed in this pass |
| Poison (DoT, 5s) | `Poison` (`abilityId = "Poison"`) | Verify existing `Poison.lua` duration matches "5s"; not confirmed in this pass |
| Health Core (+30% Max HP) | `training_core` (flat `+100` HP, not a %) | Different mechanic (flat add vs. percent) — needs a new definition or a `Multiply` stat modifier added to the factory pattern |
| **PowerCore (+20% Damage dealt)** | **`PowerCore` already exists but means something else today: `HealOnLaunch` (5%) + flat `+100` max HP, tagged `RegenerationHealing`**, not a damage-percent modifier | **Direct semantic conflict — same name, different mechanic. Must be resolved (rename one, or redesign) before implementation.** |
| RegenBooster (+500 HP/5s) | — (net new, though `PowerCore`'s `HealOnLaunch` type is a nearby precedent for heal-type passive abilities) | — |
| Shield (−20% incoming dmg) | `Shield` (`passiveAbility = { type = "DamageReduction", percent = 0.2 }`) | None — already matches exactly |
| Slow Blaster (projectile slow, 3s cd) | `Slow.lua` effect module exists but is currently only reachable via `PowerCore`'s `collisionFlag = "Slow"` — no standalone active-triggered "Slow Blaster" equipment exists | Needs a new active-trigger definition, reusing the existing `Slow` effect module |
| **BrainBoost (+30% EXP)** | **`BrainBoost` already exists but grants `+50%` EXP (`value = 0.5`) today**, tagged `ConditionalEffect` | **Value conflict — same name, different magnitude. Needs an explicit decision: adjust existing value to 30%, or treat as a tiered variant.** |
| ShadowCloak (idle→stealth after 5s) | No Equipment-side stealth effect exists; `LauncherAbilityService.Abilities.Stealth.lua` is a *launcher*-ability precedent (see Objective 7) | Depends on Objective 7's resolution of the legacy Stealth ownership question |
| SmokeBomb (VFX on launch) | `SmokeBomb` (`abilityId = "SmokeBomb"`, `passiveAbility.type = "SmokeOnLaunch"`) | None — already matches |
| Turbo Module (+20% move speed) | `swift_charm` (+10% move speed) is the closest precedent, not an exact match | Needs a new definition; percentage differs from precedent |
| Launch Booster (launch power %) | — (net new; overlaps conceptually with `PhysicsConfig.Charge`/`Launch` tuning, needs a stat-resolver hook, not just `statModifiers`) | — |
| Titan Core (size on level-up, knockback mods) | `Titan` exists (`sizeMultiplier`, `incomingKnockbackMultiplier`, `outgoingKnockbackMultiplier`) but is a **static** multiplier, not level-scaled | Needs new "scales with equipment level" logic — a capability that doesn't appear to exist yet for *any* current effect module |
| Quick Reload (−1s launch cooldown) | — (net new; must integrate with `LauncherCooldownService`/`PhysicsConfig.Launch.RecoveryDuration`, the same system flagged as buggy in Objective 5 — sequencing risk if both are worked on concurrently) | — |
| ThornArmor (reflect 20% dmg) | — (net new; requires a new hook into `DamagePipelineService`/`CombatCollision.lua` to reflect damage back to attacker — no existing effect module does bidirectional damage today) | — |

- **Synchronization risk.** Because `PowerCore` and `BrainBoost` already exist with *different* semantics than requested, implementing the brief literally by editing these definitions in place would silently change balance for any already-issued mock/live inventories referencing today's `PowerCore`/`BrainBoost` (per Objective 6's `MockData.lua` profiles, which already reference both by name). This must be an explicit design decision (rename the new concept, version the definition, or accept the balance change) before implementation — not something engineering resolves ad hoc.
- **Coupling risk — level-scaling and active-cooldown categories don't have existing precedent.** Titan Core's "increases physical size upon leveling up" and Quick Reload's "reduces launch cooldown" both require reading the owned-instance's `level` (already present in `MockData.lua`'s schema) inside the effect/ability pipeline — today's registered effect modules (`Poison.lua`, `Fire.lua`, etc.) were not confirmed in this pass to receive `level` as an input at all; this needs to be added to the `EquipmentEffectService:Dispatch`/`ActivateEquipment` signature as a first-class concept before any level-scaled equipment (Titan Core, and likely others going forward) can be implemented.
- **Deployment risk — VFX/asset dependency.** Per `PROJECT_TREE.md`, only 6 of the 20 requested types have any model asset under `ReplicatedStorage.Assets.Equipment` today (`Poison`, `GhostFlame`, `PowerCore`, `BrainBoost`, `ThunderHammer`, `Medusa`). The remaining 14 — including all fully-net-new types — will need art/VFX asset creation coordinated in parallel with (not blocking) the server-authoritative logic work, since the logic and the asset can be developed independently against the existing `modelPath` convention.

### 8.3 Proposed Architectural Solution
- **Group the 20 types by integration pattern, not by theme**, since the codebase's extensibility points are organized around *mechanism* (passive stat modifier, collision-triggered status effect, active-triggered ability, level-scaling passive), not flavor:
  1. **Passive stat modifiers** (pure `statModifiers.Add`/`Multiply`, no new effect module needed): Health Core, PowerCore *(redesigned, see below)*, Turbo Module, BrainBoost *(value-adjusted, see below)*. These slot directly into the existing `equipment(...)` factory with no `EquipmentEffects/` module required.
  2. **Collision-triggered status effects** (new `EquipmentEffects/` module, registered and dispatched via `OnCollision`, following `Stun.lua`/`Petrify.lua`/`Poison.lua`/`Fire.lua` precedent): ThunderHammer *(exists)*, Medusa *(exists)*, Ice Crystal *(new `Freeze.lua`)*, GhostFlame *(exists)*, Poison *(exists)*, Slow Blaster *(reuse `Slow.lua`, but as an active-trigger source instead of a passive collision side-effect)*.
  3. **Active-triggered abilities** (cooldown-gated, dispatched through `EquipmentAbilityService`/`BaseAbility`, analogous to how `LauncherAbilityService.Abilities` are structured): Plasma Cannon, Slow Blaster, Launch Booster (if implemented as an activated boost rather than a passive), Quick Reload (if implemented as a passive cooldown-reduction stat rather than an activation — recommend passive, see below).
  4. **Time-based passive/regen effects** (heartbeat-driven, following the precedent of `PowerCore`'s existing `HealOnLaunch` type and the service's existing `_ensureHeartbeat()` mechanism): RegenBooster, Health Core (if implemented as regen-adjacent rather than flat), Magnet Core (already precedent via `Magnet.lua`).
  5. **Conditional/state-machine effects** (new pattern — idle/movement/knockback-triggered, not collision-triggered): ShadowCloak. This is architecturally the odd one out and should be scoped in coordination with Objective 7's resolution of the Stealth ownership question, since it's conceptually identical to the existing `LauncherAbilityService.Abilities.Stealth` behavior.
  6. **Level-scaling passives** (requires the new `level`-aware dispatch extension described in the risk analysis): Titan Core (redesigned to scale with level rather than being static), and Quick Reload (if scoped as "cooldown reduction that improves with level" rather than a flat −1s).
  7. **Reflect/retaliation effects** (requires a new damage-pipeline hook, not currently present): ThornArmor.
- **Resolve the two naming conflicts explicitly before coding:** rename the brief's new "+20% damage" concept to a distinct id (e.g. `PowerCoreMk2`/`DamageCore`) rather than overwriting the existing `PowerCore`, and similarly either adjust the existing `BrainBoost` value to 30% (accepting the balance change, and updating `MockData.lua`'s references accordingly) or introduce a distinctly-named EXP-boost item.
- **Extend `EquipmentEffectService`'s dispatch signature to carry the owned instance's `level`** (and, ideally, `rarity`) into every effect module call, as a one-time infrastructure change that unblocks Titan Core, Quick Reload, and any future level-scaled equipment — rather than special-casing level-awareness per module.
- **Introduce a `Reflect`/`OnDamageTaken` hook in `DamagePipelineService`** analogous to the existing `OnCollision`/`OnAttack` hooks, for ThornArmor and any future retaliation-type effects.

### 8.4 Step-by-Step Implementation Roadmap
1. Resolve the `PowerCore` and `BrainBoost` naming/semantic conflicts with design sign-off; update `MockData.lua`'s existing references (Objective 6) to match whatever decision is made.
2. Extend `EquipmentEffectService`'s effect-module dispatch signature to pass `level`/`rarity` alongside the existing arguments; update all existing registered modules' signatures for consistency (no behavior change required for modules that don't yet use it).
3. Add a `Reflect`/`OnDamageTaken` hook to `DamagePipelineService` and the `EventBus`, mirroring the existing `OnCollision`/`OnAttack` wiring pattern in `EquipmentEffectService:Init()`.
4. Implement Group 1 (pure passive stat modifiers) first — lowest risk, no new modules: Health Core, Turbo Module, the redesigned PowerCore-equivalent, the value-adjusted BrainBoost.
5. Implement Group 2 (collision-triggered): author `Freeze.lua` for Ice Crystal following `Stun.lua`'s structure exactly; verify `GhostFlame`/`Poison`'s existing durations against the brief's 3s/5s spec and adjust if needed; confirm `ThunderHammer`/`Medusa` already satisfy the brief as-is.
6. Implement Group 3/4 (active triggers and time-based passives): Plasma Cannon and Slow Blaster via `EquipmentAbilityService`/`BaseAbility`; RegenBooster via the heartbeat mechanism already present in `EquipmentEffectService`; confirm Magnet Core already satisfies the brief via the existing `Magnet` definition (rename only if required).
7. Implement Group 6 (level-scaling), now unblocked by step 2: redesign `Titan.lua` to read the newly-available `level` and scale `sizeMultiplier` accordingly for Titan Core; implement Quick Reload against `LauncherCooldownService`, sequenced **after** Objective 5's cooldown-sync fix lands, to avoid compounding the two changes in the same untested code path.
8. Implement Group 5 (ShadowCloak) only after Objective 7's Stealth-ownership decision is finalized, reusing/migrating `LauncherAbilityService.Abilities.Stealth.lua`'s logic into the Equipment pipeline rather than writing a second parallel implementation.
9. Implement Group 7 (ThornArmor) against the new reflect hook from step 3.
10. For each of the 14 net-new types, add a corresponding entry under `ReplicatedStorage.Assets.Equipment` (coordinating with art in parallel, per the deployment risk noted above) and confirm `modelPath` resolution via the existing `equipment(...)` factory convention.
11. Extend `MockData.lua`'s test profiles (Objective 6) to include at least one owned instance of every new type, at multiple levels/rarities, to exercise the equip → activate → effect pipeline end-to-end for all 20 types before considering this objective complete.
12. Run a full regression pass confirming no existing equipment (`Poison`, `Fire`/`GhostFlame`, `Shield`, `SmokeBomb`, `Magnet`, `Stun`/`ThunderHammer`, `Petrify`/`Medusa`, `Titan`) changed behavior as an unintended side effect of the dispatch-signature extension in step 2.

---

## Cross-Cutting Sequencing Recommendation

Several objectives above have hard dependencies on each other; suggested execution order:

1. **Objective 4** (ProjectTree sync) first — it's a prerequisite for reliably diagnosing Objective 3 and for Objective 1/2's UI binding work to be trusted.
2. **Objective 1 + 2** together (shared root cause: no single source of mode/UI truth) — the Bind Manager from Objective 2 is the natural home for Objective 1's mode-scoped warning suppression.
3. **Objective 5** (Cooldown fix) — self-contained, high-confidence root cause already identified; low risk to land early and independently.
4. **Objective 3** (EndRound) — re-attempt reproduction only after Objective 4's path fix removes the confound.
5. **Objective 6** (MockData wiring) — unblocks realistic end-to-end testing for everything after it, especially Objective 8.
6. **Objective 7** (Legacy ability audit) — its outcome directly gates Objective 8's ShadowCloak implementation (Group 5).
7. **Objective 8** (20 equipment types) last — it depends on decisions from 6 and 7, and its own infrastructure step (level-aware dispatch) benefits from Objective 5 already being stable so Quick Reload isn't built against a known-buggy cooldown sync path.
