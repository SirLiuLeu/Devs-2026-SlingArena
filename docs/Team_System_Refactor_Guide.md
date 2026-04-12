# Team System Refactor Guide (FFA -> Team Control)

## Required Instances

### Teams service
- `Teams/TeamRed` (`Team`, bright red, AutoAssignable=false)
- `Teams/TeamBlue` (`Team`, bright blue, AutoAssignable=false)

### Spawn locations
- `Workspace/Maps/<ArenaMap>/SpawnPoints/RedSpawn` (`SpawnLocation` or `Part`)
- `Workspace/Maps/<ArenaMap>/SpawnPoints/BlueSpawn` (`SpawnLocation` or `Part`)

### HUD
- `StarterGui/MainHUD/Root/TeamIndicator` (`TextLabel`)

## Player Flow

1. Player joins server.
2. `TeamService` assigns balanced team.
3. `PlayerStateService.TeamId` is updated.
4. Spawn phase:
   - TeamRed -> `RedSpawn`
   - TeamBlue -> `BlueSpawn`
5. Client receives `StateUpdate` and updates team HUD indicator.

## UI Structure and Binding

- Main team indicator path:
  - `MainHUD.Root.TeamIndicator`
- Data source:
  - `StateUpdate.TeamId`
- Dynamic update:
  - Team text and color are refreshed each state packet.

## System Connections

### Spawn
- `PlayerService` asks `MapService:GetSpawnCFrame(..., teamId)`
- `MapService` resolves `RedSpawn` / `BlueSpawn`

### UI
- `UIController` binds team label and exp/team visuals from `StateUpdate`

### Gameplay logic
- `CollisionService` checks `TeamService:IsFriendly(attacker, defender)`
- Friendly collision: keep knockback/CC, set damage = 0

### Data layer
- `PlayerState.TeamId` added for server-authoritative team compatibility
- Future systems (team rewards/scoring) can key off `TeamId`
