--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local reportRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("ReportFoodHit") :: RemoteEvent

local GRID_CELL_SIZE = 48
local Y_TOLERANCE = 10
local HIT_EPSILON = 0.75
local REPORT_COOLDOWN = 0.05

local lastPos: Vector3? = nil
local lastHit: { [string]: number } = {}

local function gridKey(pos: Vector3): string
	return string.format("%d:%d", math.floor(pos.X / GRID_CELL_SIZE), math.floor(pos.Z / GRID_CELL_SIZE))
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getNearbyFood(position: Vector3): { Model }
	local out = {}
	local foodContainers = workspace:FindFirstChild("Maps")
	if not foodContainers then
		return out
	end
	local keys = {}
	local cx = math.floor(position.X / GRID_CELL_SIZE)
	local cz = math.floor(position.Z / GRID_CELL_SIZE)
	for x = cx - 1, cx + 1 do
		for z = cz - 1, cz + 1 do
			keys[string.format("%d:%d", x, z)] = true
		end
	end
	for _, map in ipairs(foodContainers:GetChildren()) do
		local container = map:FindFirstChild("FoodContainer")
		if container and container:IsA("Folder") then
			for _, food in ipairs(container:GetChildren()) do
				if food:IsA("Model") then
					local hitbox = food:FindFirstChild("Hitbox")
					if hitbox and hitbox:IsA("BasePart") and keys[gridKey(hitbox.Position)] then
						table.insert(out, food)
					end
				end
			end
		end
	end
	return out
end

RunService.RenderStepped:Connect(function()
	local root = getRoot()
	if not root then
		return
	end
	local currPos = root.Position
	for _, food in ipairs(getNearbyFood(currPos)) do
		local hitbox = food:FindFirstChild("Hitbox")
		local foodId = food:GetAttribute("FoodId")
		if hitbox and hitbox:IsA("BasePart") and typeof(foodId) == "string" then
			local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
			local foodRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + HIT_EPSILON
			local rEffective = playerRadius + foodRadius + (root.AssemblyLinearVelocity.Magnitude * (player:GetNetworkPing() * 0.5)) + HIT_EPSILON
			local dXZ = (Vector3.new(currPos.X, 0, currPos.Z) - Vector3.new(hitbox.Position.X, 0, hitbox.Position.Z)).Magnitude
			if dXZ <= rEffective and math.abs(currPos.Y - hitbox.Position.Y) <= Y_TOLERANCE then
				local now = os.clock()
				if (lastHit[foodId] or 0) <= now then
					lastHit[foodId] = now + REPORT_COOLDOWN
					food.Parent = nil
					reportRemote:FireServer({
						foodId = foodId,
						hitType = "ClientPredictedFoodOverlap",
						prevPos = lastPos,
						currPos = currPos,
					})
				end
			end
		end
	end
	lastPos = currPos
end)
