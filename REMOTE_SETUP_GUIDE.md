# Remote Setup Guide (Studio)

All production remotes must be pre-created in Studio or provided through Rojo `*.model.json` files. `Main.server.lua` only reads them via `ReplicatedStorage:WaitForChild()` and warns if any required production remote is missing.

## Required hierarchy

- `ReplicatedStorage`
  - `SlingArenaRemotes` (`Folder`)
    - `MoveRequest` (`RemoteEvent`)
    - `StartCharge` (`RemoteEvent`)
    - `ReleaseCharge` (`RemoteEvent`)
    - `JoinArena` (`RemoteEvent`)
    - `LeaveArena` (`RemoteEvent`)
    - `TeleportRequest` (`RemoteEvent`)
    - `AttributeUpgrade` (`RemoteEvent`)
    - `RequestRespawn` (`RemoteEvent`)
    - `PurchaseRespawn` (`RemoteEvent`)
    - `PurchaseMatchBuff` (`RemoteEvent`)
    - `PrestigeReset` (`RemoteEvent`)
    - `ToggleSpecialUpgrade` (`RemoteEvent`)
    - `DebugSpawnFood` (`RemoteEvent`)
    - `DebugResetSling` (`RemoteEvent`)
    - `StateUpdate` (`RemoteEvent`)
    - `UIStateUpdate` (`RemoteEvent`)
    - `GameplayFeedback` (`RemoteEvent`)
    - `MatchStateUpdate` (`RemoteEvent`)
    - `RoundResult` (`RemoteEvent`)
    - `PopupMessage` (`RemoteEvent`)

## Removed production remotes

Do **not** create these for the current production build:

- `ActivateSkill`
- `RequestMatchBuff`

They were audited out because no production system currently binds or fires them.

## How to create in Studio

1. Open Explorer.
2. Right-click `ReplicatedStorage` -> Insert Object -> `Folder` -> rename to `SlingArenaRemotes`.
3. For each remote above: right-click `SlingArenaRemotes` -> Insert Object -> `RemoteEvent` and set the exact name.

## Access pattern for services

Use only:

- `local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")`
- `local move = remotes:WaitForChild("MoveRequest")`

Do not create production remotes at runtime with `Instance.new`.
