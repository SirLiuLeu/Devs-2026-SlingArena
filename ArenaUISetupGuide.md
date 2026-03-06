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
      - `StatusLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.StatusLabel`
      - `JoinButton` (`TextButton`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.JoinButton`
      - `LeaveButton` (`TextButton`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.LeaveButton`
      - `TeleportForest` (`TextButton`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.TeleportForest`
      - `TeleportDesert` (`TextButton`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.TeleportDesert`
      - `DebugFood` (`TextButton`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.DebugFood`
      - `DebugReset` (`TextButton`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.DebugReset`
      - `MapName` (`TextLabel`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.MapName`
      - `LevelLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.LevelLabel`
      - `HpLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.HpLabel`
      - `RespawnLabel` (`TextLabel`) — path: `StarterGui.LobbyUI.LobbyUI.RootFrame.RespawnLabel`

- `StatsUI` (`ScreenGui`)
  - `StatsUI` (`Frame`)
    - `RootFrame` (`Frame`)
      - `ScoreLabel` (`TextLabel`) — path: `StarterGui.StatsUI.StatsUI.RootFrame.ScoreLabel`
      - `GoldLabel` (`TextLabel`) — path: `StarterGui.StatsUI.StatsUI.RootFrame.GoldLabel`
      - `WinsLabel` (`TextLabel`) — path: `StarterGui.StatsUI.StatsUI.RootFrame.WinsLabel`

- `MatchUI` (`ScreenGui`)
  - `MatchUI` (`Frame`)
    - `RootFrame` (`Frame`)
      - `StatusLabel` (`TextLabel`) — path: `StarterGui.MatchUI.MatchUI.RootFrame.StatusLabel`
      - `TimerLabel` (`TextLabel`) — path: `StarterGui.MatchUI.MatchUI.RootFrame.TimerLabel`
      - `AlivePlayersLabel` (`TextLabel`) — path: `StarterGui.MatchUI.MatchUI.RootFrame.AlivePlayersLabel`
      - `WinnerPopup` (`TextLabel`) — path: `StarterGui.MatchUI.MatchUI.RootFrame.WinnerPopup`

---

## 2) Charge/Aim Feedback UI (used by SlingMovement)

Create in **StarterGui**:

- `SlingArenaDynamicUI` (`ScreenGui`)
  - `Root` (`Frame`)
    - `ChargeBarBg` (`Frame`)
      - `Fill` (`Frame`)
    - `AimDirection` (`TextLabel`)
    - `ImpactFeedback` (`TextLabel`)

Paths:
- `StarterGui.SlingArenaDynamicUI.Root.ChargeBarBg`
- `StarterGui.SlingArenaDynamicUI.Root.ChargeBarBg.Fill`
- `StarterGui.SlingArenaDynamicUI.Root.AimDirection`
- `StarterGui.SlingArenaDynamicUI.Root.ImpactFeedback`

---

## 3) Required Remotes (auto-created by server)

These are created from `RemoteContracts` in `Main.server.lua` if missing, under:

- `ReplicatedStorage.SlingArenaRemotes` (`Folder`)

Common remote paths:
- `ReplicatedStorage.SlingArenaRemotes.JoinArena`
- `ReplicatedStorage.SlingArenaRemotes.LeaveArena`
- `ReplicatedStorage.SlingArenaRemotes.StartCharge`
- `ReplicatedStorage.SlingArenaRemotes.ReleaseCharge`
- `ReplicatedStorage.SlingArenaRemotes.StateUpdate`
- `ReplicatedStorage.SlingArenaRemotes.UIStateUpdate`
- `ReplicatedStorage.SlingArenaRemotes.RoundResult`
- `ReplicatedStorage.SlingArenaRemotes.GameplayFeedback`

---

## 4) Teleport/Map instances (manual)

If you use teleport/map debug flow, create:

- `Workspace`
  - `Maps` (`Folder`)
    - `ForestArena` (`Model`)
      - `SpawnPoints` (`Folder`)
        - `Spawn1` (`BasePart`)
    - `DesertArena` (`Model`)
      - `SpawnPoints` (`Folder`)
        - `SpawnA` (`BasePart`)

Optional map rule markers in active map models:
- `AntiGiantZone` (`BasePart`)
- `SafeSpawnZone` (`BasePart`)
- `SizeRestrictedCorridor` (`BasePart`)

---

## 5) Quick verification checklist

- Play test and confirm there are no `[UI_MISSING]` warnings for intended HUDs.
- `JoinButton`/`LeaveButton` fire correctly.
- Charge bar and aim text update while charging.
- Round state labels (`StatusLabel`, `TimerLabel`, `AlivePlayersLabel`) update from server events.

