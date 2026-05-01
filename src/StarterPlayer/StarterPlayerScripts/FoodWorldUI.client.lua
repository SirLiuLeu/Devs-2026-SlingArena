--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local NEAR_DISTANCE = 120
local NEAR_DISTANCE_SQ = NEAR_DISTANCE * NEAR_DISTANCE

local function sqrMagnitude(a: Vector3, b: Vector3): number
	local d = a - b
	return d.X * d.X + d.Y * d.Y + d.Z * d.Z
end

local function updateUiForFood(foodModel: Model, rootPos: Vector3)
	local hitbox = foodModel:FindFirstChild("Hitbox")
	local ui = foodModel:FindFirstChild("FoodWorldUI")
	if not (hitbox and hitbox:IsA("BasePart") and ui and ui:IsA("BillboardGui")) then
		return
	end
	local maxHp = foodModel:GetAttribute("FoodMaxHP")
	local hp = foodModel:GetAttribute("FoodHP")
	local hasHp = typeof(maxHp) == "number" and maxHp > 0 and typeof(hp) == "number"
	local near = sqrMagnitude(rootPos, hitbox.Position) <= NEAR_DISTANCE_SQ
	ui.Enabled = hasHp and near and hp > 0

	local fill = ui:FindFirstChild("HpBarBackground")
	fill = fill and fill:FindFirstChild("HpBarFill")
	if fill and fill:IsA("Frame") and hasHp then
		local ratio = math.clamp((hp :: number) / (maxHp :: number), 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
	end
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("Hitbox")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local maps = Workspace:FindFirstChild("Maps")
	if not (maps and maps:IsA("Folder")) then
		return
	end
	local rootPos = root.Position
	for _, map in ipairs(maps:GetChildren()) do
		local foodContainer = map:FindFirstChild("FoodContainer")
		if foodContainer and foodContainer:IsA("Folder") then
			for _, food in ipairs(foodContainer:GetChildren()) do
				if food:IsA("Model") then
					updateUiForFood(food, rootPos)
				end
			end
		end
	end
end)
