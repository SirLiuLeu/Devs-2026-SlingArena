# Sling Arena – System Ownership (Design-Aligned)

Source of truth used: `Rule_DESIGN.md`, current `/src` code, and `PROJECT_TREE.md`.

## Core gameplay services (active)

### PlayerStateService
- **Owns:** canonical per-player runtime state (HP, EXP, Level, Size, Damage, Regen, movement/charge flags, arena/lobby status).
- **Responsibilities:** state mutation APIs, state publish to `StateUpdate`, EXP/level progression, respawn/round reset state.
- **Called by:** GrowthService, SlingService, DamagePipelineService, RoundService, PlayerService, TrapService.
- **Dependencies:** `BalanceConfig`, `LevelConfig`, `SlingshotConfig`, `GameStates`.

### RoundService
- **Owns:** match phase and participant roster.
- **Responsibilities:** join/leave arena flow, round lifecycle, winner resolution, state broadcast via `MatchStateUpdate`, `UIStateUpdate`, `RoundResult`.
- **Called by:** remotes/events (`JoinArena`, `LeaveArena`, gate events).
- **Dependencies:** MapService, PlayerService, PlayerStateService.

### SlingService
- **Owns:** input cache, charge state, release cooldown/movement stepping.
- **Responsibilities:** validate move/charge/release inputs, apply launch and movement state transitions.
- **Called by:** remotes `MoveRequest`, `StartCharge`, `ReleaseCharge`.
- **Dependencies:** PlayerService, PlayerStateService, RoundService, SlingMovement helpers.

### CollisionService
- **Owns:** collision cooldown caches.
- **Responsibilities:** detect and resolve player collisions, trap overlap candidates, exit zones, wall bounce/drag.
- **Called by:** heartbeat loop.
- **Dependencies:** PlayerService, PlayerStateService, CombatService, TeamService, MapService.

### DamagePipelineService
- **Owns:** damage application pipeline and feedback dispatch (`GameplayFeedback`).
- **Responsibilities:** apply damage/kill flow, collision self-damage, regen ticks, death penalties, LevelUp growth hook.
- **Called by:** CollisionService, TrapService, EventBus listeners.
- **Dependencies:** PlayerStateService, PlayerService, RoundService.

### GrowthService
- **Owns:** EXP event routing.
- **Responsibilities:** convert events (damage/kill/food) to EXP grants.
- **Called by:** EventBus.
- **Dependencies:** PlayerStateService.

### FoodService
- **Owns:** food spawn center state and active food tracking.
- **Responsibilities:** spawn/respawn food from map `FoodSpawns`, consume-on-touch rewards, maintain per-anchor density.
- **Called by:** map load/init and touch events.
- **Dependencies:** MapService, PlayerService, PlayerStateService.

### TrapService
- **Owns:** trap cooldown state.
- **Responsibilities:** trap collision handling and trap-driven damage/feedback.
- **Called by:** CollisionService events.
- **Dependencies:** MapService, DamagePipelineService, PlayerStateService.

### MapService
- **Owns:** active map/resource caches (gates/traps/spawns/zones).
- **Responsibilities:** map activation/resource discovery, spawn resolution, lobby gate wiring.
- **Called by:** RoundService, PlayerService.
- **Dependencies:** FoodService, TrapService.

### PlayerService
- **Owns:** sling pawn lifecycle (`Workspace/SlingPawns`) and world-ui attachment.
- **Responsibilities:** spawn/despawn/teleport pawns, death listeners, world UI sync.
- **Called by:** RoundService, DamagePipelineService, MapService.
- **Dependencies:** MapService, PlayerStateService.

### TeamService (minimal)
- **Owns:** friendly-check helper only.
- **Responsibilities:** determine same-team friendly state from `PlayerState.TeamId` (no TeamRed/TeamBlue assignment).
- **Called by:** CollisionService.
- **Dependencies:** PlayerStateService.

### CombatService
- **Owns:** pure combat calculations.
- **Responsibilities:** impact damage and knockback formulas.
- **Called by:** CollisionService.
- **Dependencies:** balance config.

### LeaderboardService
- **Owns:** end-of-match leaderboard snapshot and ranking output.
- **Responsibilities:** collect and sort placement/reward presentation data.
- **Called by:** round/death/event hooks.
- **Dependencies:** PlayerStateService, RoundService.

### SlingAbilityService
- **Owns:** Logic kỹ năng bị động (Passive Skills) theo cấp sao.
- **Responsibilities:** - Kích hoạt Tàng hình/Phân thân/Hồi máu khi nhận tín hiệu từ `SlingService`.
  - Áp dụng hiệu ứng "Làm choáng" (Stun Flag) khi va chạm.
  - Gán EXP Multiplier Buff vào `PlayerStateService`.
### SafeZoneService
- **Owns:** Vòng bo tử thần.
- **Responsibilities:** Điều khiển Visual thu nhỏ, tính toán sát thương môi trường ($1\% \rightarrow 10\%$ HP/s) gửi về `DamagePipeline`.

### MonetizationService (respawn purchase, match buff purchase, prestige purchase loops) — not part of Rule_DESIGN core loop.
- Owns: Dữ liệu tiền tệ (Diamonds), danh sách sở hữu (Owned Gamepasses, Owned Slings/Skins).
- Responsibilities:
    + Xử lý giao dịch bằng Kim cương (Diamond Transactions).
    + Xử lý giao dịch bằng Robux (Gamepasses & Developer Products).
    + Kiểm tra quyền sở hữu trước khi cho phép trang bị vật phẩm.
    + Lưu trữ dữ liệu vĩnh viễn (DataStore Saving/Loading).

### DataStoreService ( Sau khi hoàn thiện Core Gameplay sẽ triển khai)
- Owns: Lưu trữ data
- Dữ liệu cần lưu trữ:
    + Số lượng Kim cương hiện có.
    + Danh sách các Sling đã sở hữu và cấp độ sao của chúng.
    + Các vật phẩm (Potion, Gacha tickets) trong kho đồ.
    + Chỉ số vĩnh viễn (Tổng số trận thắng, tổng số mạng hạ gục).
### MarketplaceService ( Khi làm Shop Robux/Gamepass sẽ triển khai)
- "Cánh cổng" doanh thu
- Các tác vụ chính:
    + Kiểm tra Gamepass:
    + Xử lý Developer Products: Khi người chơi nhấn mua "Gói 1000 Kim cương", dịch vụ này sẽ xử lý giao dịch và trả về kết quả để cộng tiền cho họ

## Removed / deprecated ownership
- **Removed from runtime boot:** `MonetizationService` 
- **Removed feature ownership:** manual stat allocation workflow (`SlingStatsUI` + `AttributeUpgrade` remote path).
- **Removed TeamRed/TeamBlue ownership model:** no fixed red/blue assignment/spawn branching.

