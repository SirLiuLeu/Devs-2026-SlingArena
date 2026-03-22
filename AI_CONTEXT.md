# Sling Arena - Project Context

## 1. Project Overview

Sling Arena là một game PvP multiplayer đấu trường vật lý.

Mỗi người chơi điều khiển một "Sling", là một vật thể có thể tự phóng (launch) bản thân qua bản đồ bằng cơ chế charge và release.

Mục tiêu chính:
- Thu thập Food để tăng EXP
- Tăng level và kích thước
- Hạ gục Sling nhỏ hơn

Gameplay mang phong cách:
- "cá lớn nuốt cá bé"
- kết hợp vật lý va chạm và chiến thuật định hướng lực bắn.

Không có điều kiện thắng tuyệt đối. Arena luôn active và người chơi có thể:
- tham gia
- rời đi
- respawn
- tiếp tục chiến đấu

Leaderboard dựa trên:
- level
- size
- EXP

---

# 2. Core Gameplay Loop

Vòng lặp gameplay chính:

1. Spawn
   Player xuất hiện ở Lobby → Join Arena.

2. Collect Food
   Player di chuyển trong Arena để thu thập Food.

3. Charge
   Player giữ phím để tích lực bắn.
   Trong trạng thái charge:
   - Sling không thể di chuyển.

4. Release
   Khi thả phím:
   - server tính toán lực phóng
   - áp dụng velocity cho Sling.

5. Physics Movement
   Sling di chuyển theo vật lý.

6. Collision
   Sling va chạm với:
   - Sling khác
   - Trap
   - Map geometry.

7. Result
   Tùy thuộc vào:
   - size
   - trạng thái release
   - va chạm

   Kết quả có thể:
   - gây damage
   - nhận phản damage
   - knockback
   - stun
   - death.

8. Respawn hoặc Lobby
   Sling chết có thể:
   - chờ respawn
   - quay về lobby.

9. Loop continues.

---

# 3. Key Mechanics

## 3.1 Charge / Release System

Player giữ phím để charge năng lượng.

Properties:

- charge_time tăng theo thời gian giữ phím
- release_velocity phụ thuộc vào charge_time

Rules:

- khi charge:
  Sling không thể di chuyển

- khi release:
  server tính toán velocity

Client không được phép tự tính physics.

---

# 3.2 Size System

Khi ăn Food:

- Sling nhận EXP
- Khi đủ EXP → level up

Level up sẽ:

- tăng size
- tăng collision power
- tăng khả năng knockback

Game có cơ chế anti power scaling:

Level càng cao:
- EXP cần thiết càng lớn
- việc tăng level khó hơn

Mục đích:
tránh sling quá OP.

---

# 3.3 Collision Outcomes

### Case 1: A release trúng B

A gây damage lên B.

A nhận phản damage từ B dựa trên stat của B.

Kết quả:

- nếu cả hai không chết:
  cả hai bị knockback

- nếu một Sling chết:
  Sling đó vỡ ra và biến mất
  chỉ gây knockback nhẹ cho đối thủ

Trong thời gian knockback:

- Sling bị stun
- không thể move
- charge bị reset

---

### Case 2: A và B va chạm khi không release

Cả hai Sling nhận:

- phản damage từ đối phương

---

### Collision parameters

Các giá trị chi tiết như:

- knockback force
- stun duration
- damage ratio

được định nghĩa trong game design rules.

---

# 4. Food System

Food là vật phẩm giúp tăng EXP.

Food spawn tại:

FoodSpawns trên map.

Khi Sling ăn Food:

- Food biến mất
- Sling nhận EXP

Sau một thời gian:

Food respawn:

- tại spawn point
- hoặc gần spawn point.

---

# 5. Trap System

Trap là bẫy đặt sẵn trên map.

Trap spawn tại:

TrapSpawns.

Khi Sling chạm Trap:

Trap có thể gây:

- damage
- stun
- slow
- hiệu ứng tiêu cực khác

Chi tiết phụ thuộc loại trap.

---

# 6. Networking Model

Game sử dụng server-authoritative architecture.

Client chỉ gửi input.

Server chịu trách nhiệm:

- physics
- movement
- collision
- gameplay logic

Client không được:

- tự thay đổi velocity
- tự thay đổi position
- tự thay đổi stats.

---

# 7. RemoteEvent Architecture

Client gửi input thông qua RemoteEvents.

RemoteEvents được đặt tại:

ReplicatedStorage.SlingArenaRemotes

Tất cả RemoteEvents phải:

- được tạo sẵn trong Studio
- không tạo runtime.

---

# 8. Client → Server Events

JoinArena
ReplicatedStorage.SlingArenaRemotes.JoinArena

LeaveArena
ReplicatedStorage.SlingArenaRemotes.LeaveArena

MoveRequest
ReplicatedStorage.SlingArenaRemotes.MoveRequest

StartCharge
ReplicatedStorage.SlingArenaRemotes.StartCharge

ReleaseCharge
ReplicatedStorage.SlingArenaRemotes.ReleaseCharge

TeleportRequest
ReplicatedStorage.SlingArenaRemotes.TeleportRequest

AttributeUpgrade
ReplicatedStorage.SlingArenaRemotes.AttributeUpgrade

RequestRespawn
ReplicatedStorage.SlingArenaRemotes.RequestRespawn

PurchaseRespawn
ReplicatedStorage.SlingArenaRemotes.PurchaseRespawn

PurchaseMatchBuff
ReplicatedStorage.SlingArenaRemotes.PurchaseMatchBuff

PrestigeReset
ReplicatedStorage.SlingArenaRemotes.PrestigeReset

ToggleSpecialUpgrade
ReplicatedStorage.SlingArenaRemotes.ToggleSpecialUpgrade

DebugSpawnFood
ReplicatedStorage.SlingArenaRemotes.DebugSpawnFood

DebugResetSling
ReplicatedStorage.SlingArenaRemotes.DebugResetSling

---

# 9. Server → Client Events

StateUpdate
ReplicatedStorage.SlingArenaRemotes.StateUpdate

UIStateUpdate
ReplicatedStorage.SlingArenaRemotes.UIStateUpdate

GameplayFeedback
ReplicatedStorage.SlingArenaRemotes.GameplayFeedback

MatchStateUpdate
ReplicatedStorage.SlingArenaRemotes.MatchStateUpdate

RoundResult
ReplicatedStorage.SlingArenaRemotes.RoundResult

PopupMessage
ReplicatedStorage.SlingArenaRemotes.PopupMessage

---

# 10. Important Notes for AI

AI implementing code must follow rules:

1. Server authoritative physics
2. Client only sends input
3. RemoteEvents must already exist
4. Do not create new RemoteEvents at runtime
5. Do not trust client physics
6. Food and Trap spawn system must be deterministic
