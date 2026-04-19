# 🔥 SLING ARENA – AI CONTEXT (STRICT AUTHORITATIVE SPEC)

## # 1. OVERVIEW & PHILOSOPHY
- **Genre:** PvP Multiplayer Physics Arena (Round-based).
- **Control:** Sling-based movement. Player **Charge** (tích lực) -> **Release** (phóng). Không dùng WASD thuần.
- **Core Goal:** Cá lớn nuốt cá bé + Skill-based Physics. Sống sót cuối cùng để thắng (Top 1 = 1 Gacha Ticket).
- **Safe Zone:** Vòng bo thu hẹp liên tục. Ngoài bo mất % HP tăng dần theo thời gian.

---

## # 2. CORE GAME LOOP (SERVER-DRIVEN)
1. **Join:** Tham gia vào Match (Early/Final Phase).
2. **Farm:** Ăn Food -> Tăng EXP, Level, Hồi HP.
3. **Combat:** Charge (Disable move) -> Release (Server apply velocity) -> Collision (Xử lý va chạm).
4. **Death:** Chuyển sang trạng thái Ghost (Không respawn, vẫn có thể farm/level up nhưng không được Launch và bị tàng hình).
5. **End:** Trả kết quả (Rank/Rewards) -> Reset Map. *Lưu ý: Level người chơi được giữ nguyên để tính thưởng.*

---

## # 3. ROUND SYSTEM PHASES
- **Early Phase (0-8p):** Cho phép Join tự do. Chết được Respawn (Phạt -30% EXP).
- **Final Phase (8-10p):** Khóa Join (Late join = Ghost). Chết không Respawn. Chỉ người sống mới được Launch.
- **Victory:** Người cuối cùng sống sót thắng. Vòng bo ngừng gây damage cho Winner. Thông báo Reset sau 15s hiển thị Rank.

---

## # 4. CORE MECHANICS & SCALING
### 4.1 Charge / Release
- **Input:** Server nhận tín hiệu Start/Release.
- **Rule:** Khi đang Charge, tốc độ di chuyển = 0. Client chỉ hiển thị hiệu ứng, Server thực hiện tính toán lực (Force).

### 4.2 Leveling & Attributes
- **Scaling:** Mỗi Level tăng vĩnh viễn **3% toàn bộ chỉ số**.
- **Requirement:** EXP cần để lên cấp tăng theo công thức: `RequiredEXP = BaseEXP × (Level ^ 1.3)`.

### 4.3 Collision Logic
- **Trường hợp Launch:** Attacker gây damage, nhận phản damage từ Target. Cả hai bị Knockback.
- **Trường hợp Idle:** Va chạm thông thường gây sát thương nhẹ và đẩy lùi.
- **Knockback Effect:** Gây Stun ngắn, Disable di chuyển và Reset trạng thái Charge.

---

## # 5. SYSTEM COMPONENTS
- **Food System:** Spawn từ `FoodSpawns`. Ăn để tăng EXP và hồi HP. Respawn sau 10s.
- **Trap System:** Lava (Chết sau 3s), Totem (Knockback), Smoke (DOT), Spike (Damage).
- **Networking:** **Absolute Server Authoritative.** Client chỉ gửi Input (Direction/Aim). Server tính toán Physics, Position, Damage, Stats.

---

## # 6. REMOTE ARCHITECTURE (UNIFIED)

### CLIENT → SERVER (Requests)
- `JoinArena` / `LeaveArena`
- `MoveRequest` (Hướng di chuyển)
- `StartCharge` / `ReleaseCharge` (Kèm theo `AimTarget`)
- `TeamAction` (Create/Leave)

### SERVER → CLIENT (State & Events)
- `StateUpdate`: Cập nhật vị trí, HP, Level của toàn bộ Player.
- `RoundStateUpdate`: Cập nhật Phase, Timer, Số người còn sống.
- `GameplayEvent`: Event gộp (Damage, Death, LevelUp, Heal).
- `SafeZoneUpdate`: Dữ liệu vòng bo hiện tại.
- `MatchResult`: Bảng xếp hạng và phần thưởng cuối trận.

---

## # 7. AI IMPLEMENTATION GUARDS (STRICT)
1. **Source of Truth:** Server luôn đúng. Reject mọi action nếu Player chết hoặc sai Phase.
2. **Physics:** Tuyệt đối không tính toán vị trí/vận tốc tại Client để tránh Cheat.
3. **No New Remotes:** Sử dụng hệ thống RemoteEvent hiện có theo dạng Unified.
4. **Validation:** Kiểm tra trạng thái Ghost trước khi xử lý bất kỳ hành động Launch nào.
5. **Performance:** Zone Control và Round Flow là ưu tiên xử lý hàng đầu.