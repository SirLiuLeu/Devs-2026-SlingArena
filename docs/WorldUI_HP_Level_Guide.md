# World UI Guide: HP Bar + Level above Sling

## 1) Manual Instance Setup (Studio)

1. Select your Sling model in `Workspace/SlingPawns/<PlayerName>`.
2. Choose attachment part:
   - Preferred: `HumanoidRootPart` (or `Head` if exists).
3. Insert:
   - `BillboardGui` named `SlingWorldUI`
   - Parent: Sling attachment part.
4. Configure `SlingWorldUI`:
   - `AlwaysOnTop = true`
   - `Size = UDim2.fromOffset(160, 48)`
   - `StudsOffset = Vector3.new(0, 5, 0)`
5. Add children:
   - `Frame` named `HpBarBackground`
     - child `Frame` named `HpBarFill`
   - `TextLabel` named `LevelLabel`
   - `TextLabel` named `TeamLabel` (optional but recommended)

## 2) Script Binding

Use LocalScript to read `StateUpdate` payload (`CurrentHP`, `MaxHP`, `Level`, `TeamId`) and:
- `HpBarFill.Size = UDim2.new(CurrentHP / MaxHP, 0, 1, 0)`
- `LevelLabel.Text = "Lv." .. Level`
- Team color:
  - TeamRed: red tint
  - TeamBlue: blue tint

## 3) Runtime Safety

- If `SlingWorldUI` or any child is missing, only `warn()` and continue.
- Never hard-fail because world UI is missing.

## 4) Team-aware Color Rule

- If `TeamId == "TeamRed"`:
  - `HpBarFill.BackgroundColor3 = Color3.fromRGB(255, 84, 84)`
- If `TeamId == "TeamBlue"`:
  - `HpBarFill.BackgroundColor3 = Color3.fromRGB(90, 165, 255)`
- Else fallback neutral green.
