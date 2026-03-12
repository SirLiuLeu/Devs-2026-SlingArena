# Remote Setup Guide (Studio)

All remotes must be pre-created in Studio. `Main.server.lua` only reads them via `ReplicatedStorage:WaitForChild()`.

## 1) Required hierarchy
Create this exact structure:

- `ReplicatedStorage`
  - `SlingArenaRemotes` (Folder)
    - `MoveRequest` (RemoteEvent)
    - `StartCharge` (RemoteEvent)
    - `ReleaseCharge` (RemoteEvent)
    - `GameplayFeedback` (RemoteEvent)
    - `StateUpdate` (RemoteEvent)
    - `UIStateUpdate` (RemoteEvent)
    - `AttributeUpgrade` (RemoteEvent)
    - `ActivateSkill` (RemoteEvent)
    - `RequestRespawn` (RemoteEvent)
    - `RequestMatchBuff` (RemoteEvent)
    - `MatchStateUpdate` (RemoteEvent)
    - `RoundResult` (RemoteEvent)
    - `PopupMessage` (RemoteEvent)
    - `PurchaseRespawn` (RemoteEvent)
    - `PurchaseMatchBuff` (RemoteEvent)
    - `PrestigeReset` (RemoteEvent)
    - `ToggleSpecialUpgrade` (RemoteEvent)
    - `JoinArena` (RemoteEvent)
    - `LeaveArena` (RemoteEvent)
    - `TeleportRequest` (RemoteEvent)
    - `DebugSpawnFood` (RemoteEvent)
    - `DebugResetSling` (RemoteEvent)

## 2) How to create in Studio
1. Open Explorer.
2. Right-click `ReplicatedStorage` -> Insert Object -> `Folder` -> rename to `SlingArenaRemotes`.
3. For each remote above: right-click `SlingArenaRemotes` -> Insert Object -> `RemoteEvent` and set exact name.

## 3) Access pattern for services
Use only:
- `local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")`
- `local move = remotes:WaitForChild("MoveRequest")`

Do not create remotes at runtime with `Instance.new`.
