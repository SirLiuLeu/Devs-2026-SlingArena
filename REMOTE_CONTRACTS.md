# 🔥 REMOTE CONTRACTS (ALIGNED WITH DESIGN)

## CLIENT → SERVER

MoveRequest (SlingService) → moveDirection: Vector3 | Move input; validate Vector3, magnitude ≤ 1, player alive, not ghost, not charging.

StartCharge (SlingService) → aimTarget: Vector3 | Start charge; validate alive, not ghost, phase Early/Final, not charging.

ReleaseCharge (SlingService) → aimTarget: Vector3 | Launch; validate charging, alive, not ghost; force computed server-side.

JoinArena (RoundService) → none | Join match; Early → normal, Final → ghost.

LeaveArena (RoundService) → none | Exit match.

CreateTeam (TeamService) → targetPlayerId: number | Create team; validate both not in team, max 2 players.

LeaveTeam (TeamService) → none | Leave team.


## SERVER → CLIENT

StateUpdate (PlayerStateService) → PlayerState | Sync full state (HP, Level, Size, Velocity, Flags).

RoundStateUpdate (RoundService) → { Phase, TimeLeft, AlivePlayers } | Sync match state.

MatchResult (RoundService) → { WinnerUserId } | Announce winner.

GameplayEvent (CollisionService / LevelService / SlingService) → { EventType, Data } | Unified events:
- Damage { TargetId, Amount }
- Knockback { TargetId, Force }
- LevelUp { NewLevel }
- Death { VictimId }
- FoodConsumed { ExpGained }

SafeZoneUpdate (SafeZoneService) → { Radius, Center } | Sync zone.

PopupMessage (TrapService) → { Type, Text } | Trap feedback.


## REMOVED

Monetization (Respawn, Buff, Prestige) → không thuộc core gameplay.
Attribute/Skill UI → không có trong design.
TeleportRequest → client không được control map.
Debug remotes → không production.


## VALIDATION

- Server authoritative tuyệt đối; client chỉ gửi input.
- Không cho client set: velocity, damage, EXP, level.
- Reject: invalid type, dead player, ghost action, sai phase.


## NOTES

- Remote tối giản → dễ maintain, giảm exploit.
- GameplayEvent unified → dễ scale UI/VFX.
- StateUpdate = source of truth player.
- RoundStateUpdate = source of truth match.