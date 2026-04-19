# 🔥 SLING ARENA – MASTER GAME DESIGN SPECIFICATION (FINAL)

# 0. MỤC TIÊU THIẾT KẾ (DESIGN GOAL)
- Thể loại: Survival Physics Arena (Round-based).
- Trải nghiệm lõi: Farm Food tăng cấp, dùng vật lý để va chạm và đẩy đối thủ vào bẫy hoặc vòng bo.
- Triết lý: Kỹ năng & Phối hợp > Chỉ số thuần.
- Core Feeling: "Phóng – Va – Bật – Trượt" phải rõ ràng, có lực.

# 1. VÒNG LẶP GAME (CORE GAME LOOP)
1. Lobby: Chọn / Mua / Quay Sling, Trang bị Item, Nâng sao cho Sling
2. Start: Join Map, Farm Food, Tăng Level
3. Mid Game: Combat, Giữ vị trí, Tận dụng Trap
4. Late Game: Vòng bo thu hẹp, Ép giao tranh, Sinh tồn
5. End: Player cuối cùng sống sót thắng, Nhận thưởng, Reset round

# 2. QUY TẮC TRẬN ĐẤU (ROUND RULES)

## 2.1 World & Map
- Size: 700x700 studs (Square Arena)
- Boundary: Wall bao quanh
- Players: 12 người
- Traps: 10 (cố định)
Spawn Logic:
- Player: Spawn ngẫu nhiên gần rìa (Edge)
- Food: Spawn theo cụm (FoodSpawns)
- Traps: Fixed positions

## 2.2 Early Game (0 → 8 phút)
- Cơ chế: Farm + Combat tự do
Death:
- Respawn sau 5s
- Vị trí random trong Safe Zone
- -30% EXP hiện tại
Join:
- Player mới có thể tham gia

## 2.3 Final Phase (8 → 10 phút)
Death:
- Không respawn → chuyển Ghost
Ghost State:
- 0–5s đứng yên
- Sau đó spectate tự do (không tương tác)
Team:
- Tự động giải tán
Join Rule:
- Join sau phút 8 → thành Ghost ngay
- Vẫn farm + level
- Không được Launch
- Bị tàng hình

## 2.4 End Condition
- Winner: Player cuối cùng sống sót
After Win:
- Safe zone không gây damage nữa
Flow:
- 5s: xác định winner
- 15s: hiển thị rank + reward
- 15s: reset round

# 3. FOOD SPAWN SYSTEM (TECHNICAL)

## 3.1 Structure
- Container: Workspace/FoodSpawns
- Naming: "FoodSpawn"
- Attribute: Zone = Edge | Middle | Center

## 3.2 Spawn Rule
- Radius: ±5 studs (X, Z)
- Formula: spawnPos = FoodSpawn.Position + Vector3.new(random(-5,5), 0, random(-5,5))
- Density: 1 FoodSpawn = 5 Food active, Thiếu → respawn sau 10s

## 3.3 Food Zones
- Có 2 loại food: Foods Normal, Food có HP
- Foods Normal: chạm vào là biến mất, Player nhận exp và hồi HP từ Foods này
- Foods CÓ HP: Player cần tấn công lasthit để nhận exp+ cơ hội nhận kim cương

## 3.4 Maintenance
- Mỗi Food bị phá → respawn đúng 1 cái sau 10s
- Không được overlap trong cùng cụm

# 4. PHYSICS & COMBAT

## 4.1 Formula
- ImpactDamage = BaseDamage × CollisionSpeedMultiplier
- Size = BaseSize × (1 + sqrt(Level) × 0.08)
- RequiredEXP = BaseEXP × (Level ^ 1.3)

## 4.2 Combat Flow
- Charge → Launch → Move → Collision → Damage + Knockback
Physics: Gravity, Mass, Friction, Inertia, Knockback

# 5. SLING SYSTEM (CHARACTERS)

## 5.1 Core Stats
- MaxHP, BaseDamage, MoveSpeed, LaunchRange, ReflectDamage

## 5.2 Archetypes (Passive)
- CloneSling: Tạo clone (50% HP, tồn tại 15s)
- SupportSling: Va vào đồng đội → heal
- SplitSling: Tách hướng trái/phải khi launch
- StunSling: Stun 1s khi va chạm
- VacuumSling: Hút Mini Food xung quanh
- StealthSling: Tàng hình 1s trước khi launch
- HealSling: Launch → tự heal
- SpeedSling: +5% speed mỗi lần launch (stack)

# 6. PROGRESSION & UPGRADE

## 6.1 Star Upgrade
- 3 Sling giống nhau → +1★
- Max: 3★
Balance:
- 3★ thường có thể mạnh hơn 2★ hiếm (stat)
- Rare có skill đặc biệt

## 6.2 In-match Scaling
- Level up: Tăng Size, Tăng Damage, +3% all stats
- Attribute: +1 point / level
- UI Rule: Không mở UI chỉnh stat trong trận

# 7. ITEM & TEAM

## 7.1 Items
- HP Potion: 300 HP/s × 5s = 1500 HP, Có cooldown
- Khác: Scale potion, EXP buff, Gacha ticket
Nguồn: Daily Login, Chest, Shop, Event

## 7.2 Team
- Max: 2 người
- Friendly fire: OFF
Win: Vẫn là last man standing, Team chỉ hỗ trợ

# 8. ENVIRONMENT & SAFE ZONE

## 8.1 Safe Zone
- Thu hẹp theo thời gian, Ép combat
Outside:
- Mất % HP mỗi giây 
- Damage tăng dần ( tăng dần theo thời gian 1%/s -> 10%/s)

## 8.2 Traps
- Lava: Chết sau 3s
- Toxic Smoke / Fire: Damage over time
- Spike: Damage + Knockback
- Totem: Bắn đạn đẩy player

# 9. ECONOMY & PROGRESSION

## 9.1 Income
- Kill: Diamonds, EXP = 1/2 EXP đối thủ mất
- Khác: Chest, Event, Daily, Robux

## 9.2 VIP
- Giá: 1000 Diamonds / 7 ngày
- Buff: +20% EXP từ Food

# 10. BUILD ORDER
1. Round System
2. Physics Core
3. Food System
4. Leveling System
5. Sling System
6. Environment (Safe Zone + Traps)
7. Meta (Economy + Lobby + UI)