# Arena UI & Required Instance Setup Guide

This project intentionally **does not** create UI at runtime with `Instance.new(...)` for ScreenGui/TextButton/TextLabel/etc.
If UI/Instances are missing, scripts will `warn()` and keep running.

Use this guide to create all required instances in Studio once.

---

## 1) Core UI for Lobby/Stats/Match

Create in **StarterGui**:

- `LobbyUI` (`ScreenGui`)
  - `LobbyUI` (`Frame`)
    - `RootFrame` (`Frame`)
      - `StatusLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.RootFrame.StatusLabel`
      - `JoinButton` (`TextButton`) — path: `StarterGui.LobbyUI.RootFrame.JoinButton`
      - `LeaveButton` (`TextButton`) — path: `StarterGui.LobbyUI.RootFrame.LeaveButton`
      - `DebugFood` (`TextButton`) — path: `StarterGui.LobbyUI.RootFrame.DebugFood`
      - `DebugReset` (`TextButton`) — path: `StarterGui.LobbyUI.RootFrame.DebugReset`
      - `MapName` (`TextLabel`) — path: `StarterGui.LobbyUI.RootFrame.MapName`
      - `LevelLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.RootFrame.LevelLabel`
      - `HpLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.RootFrame.HpLabel`
      - `RespawnLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.RootFrame.RespawnLabel`

- `StatsUI` (`ScreenGui`)
  - `StatsUI` (`Frame`)
    - `RootFrame` (`Frame`)
      - `ScoreLabel` (`TextLabel`) — path: `StarterGui.StatsUI.RootFrame.ScoreLabel`
      - `GoldLabel` (`TextLabel`) — path: `StarterGui.StatsUI.RootFrame.GoldLabel`
      - `WinsLabel` (`TextLabel`) — path: `StarterGui.StatsUI.RootFrame.WinsLabel`

- `MatchUI` (`ScreenGui`)
  - `MatchUI` (`Frame`)
    - `RootFrame` (`Frame`)
      - `StatusLabel` (`TextLabel`) — path: `StarterGui.MatchUI.RootFrame.StatusLabel`
      - `TimerLabel` (`TextLabel`) — path: `StarterGui.MatchUI.RootFrame.TimerLabel`
      - `AlivePlayersLabel` (`TextLabel`) — path: `StarterGui.MatchUI.RootFrame.AlivePlayersLabel`
      - `WinnerPopup` (`TextLabel`) — path: `StarterGui.MatchUI.RootFrame.WinnerPopup`

---

## 2) Sling touch UI

Create in **StarterGui**:

- `SlingArenaUI` (`Folder`)
  - `SlingUI` (`ScreenGui`)
    - `JoystickRoot` (`Frame`)
      - `Base` (`Frame`)
      - `Thumb` (`Frame`)
    - `ChargeBar` (`Frame`)
      - `Fill` (`Frame`)
    - `DirectionIndicator` (`ImageLabel`) or compatibility alias `DirectionArrow`
    - `CooldownBar` (`Frame`)
      - `Fill` (`Frame`)

Paths:
- `StarterGui.SlingArenaUI.SlingUI.JoystickRoot`
- `StarterGui.SlingArenaUI.SlingUI.ChargeBar.Fill`
- `StarterGui.SlingArenaUI.SlingUI.DirectionIndicator`
- `StarterGui.SlingArenaUI.SlingUI.CooldownBar.Fill`

---

## 3) Required Remotes (static, Rojo-managed)

These must already exist under:

- `ReplicatedStorage.SlingArenaRemotes` (`Folder`)

Required production remotes:
- `MoveRequest`
- `StartCharge`
- `ReleaseCharge`
- `JoinArena`
- `LeaveArena`
- `TeleportRequest`
- `AttributeUpgrade`
- `RequestRespawn`
- `PurchaseRespawn`
- `PurchaseMatchBuff`
- `PrestigeReset`
- `ToggleSpecialUpgrade`
- `DebugSpawnFood`
- `DebugResetSling`
- `StateUpdate`
- `UIStateUpdate`
- `GameplayFeedback`
- `MatchStateUpdate`
- `RoundResult`
- `PopupMessage`

Do **not** rely on the server to create these at runtime.

---

## 4) Teleport/Map instances (manual)

Current supported maps:
- `LobbyMap`
- `ArenaMap`

Create:

- `Workspace`
  - `Maps` (`Folder`)
    - `LobbyMap` (`Model`)
      - `SpawnPoints` (`Folder`)
        - `SpawnPoint` (`BasePart`)
    - `ArenaMap` (`Model`)
      - `SpawnPoints` (`Folder`)
        - `SpawnPoint_01..N` (`BasePart`)

Optional map rule markers in active map models:
- `AntiGiantZone` (`BasePart`)
- `SafeSpawnZone` (`BasePart`)
- `SizeRestrictedCorridor` (`BasePart`)

---

## 5) Quick verification checklist

- Play test and confirm there are no `[UI_MISSING]` warnings for intended HUDs.
- `JoinButton`/`LeaveButton` fire correctly.
- Sling joystick, charge bar, cooldown bar, and direction indicator update while charging/recovering.
- Round state labels (`StatusLabel`, `TimerLabel`, `AlivePlayersLabel`) update from server events.
