--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local GameStates = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GameStates"))
local stateUpdateRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("StateUpdate") :: RemoteEvent
local reportRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("ReportFoodHit") :: RemoteEvent
local gameplayFeedbackRemote = ReplicatedStorage:WaitForChild("SlingArenaRemotes"):WaitForChild("GameplayFeedback") :: RemoteEvent

local GRID_CELL_SIZE = 48
local Y_TOLERANCE = 10
local HIT_EPSILON = 0.75
local REPORT_COOLDOWN = 0.05
local MIN_REPORT_SPEED = 8
local IMPACT_ABSORPTION = 0.6
local HITSTOP_SECONDS = 0.05
local BOUNCE_RETENTION = 0.7
local MINOR_DESYNC = 4
local MAJOR_DESYNC = 12

local lastPos: Vector3? = nil
local lastHit: { [string]: number } = {}
local predictedImpacts: { [string]: { beforeVelocity: Vector3, beforePosition: Vector3 } } = {}
local currentMovementState = GameStates.PlayerState.Idle

local function canReportForStateAndRarity(movementState: string, rarity: any): boolean
	if rarity ~= "Common" then
		return movementState == GameStates.PlayerState.Launching
	end
	return movementState ~= GameStates.PlayerState.Dead
end

local function gridKey(pos: Vector3): string
	return string.format("%d:%d", math.floor(pos.X / GRID_CELL_SIZE), math.floor(pos.Z / GRID_CELL_SIZE))
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Hitbox") :: BasePart?
end

local function applyPredictedLaunchFeel(root: BasePart, normal: Vector3)
	local velocity = root.AssemblyLinearVelocity
	local compressed = velocity * IMPACT_ABSORPTION
	root.AssemblyLinearVelocity = compressed
	task.delay(HITSTOP_SECONDS, function()
		if not root.Parent then
			return
		end
		local reflected = compressed - (2 * compressed:Dot(normal) * normal)
		root.AssemblyLinearVelocity = reflected * BOUNCE_RETENTION
	end)
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
		local rarity = food:GetAttribute("FoodRarity")
		if hitbox and hitbox:IsA("BasePart") and typeof(foodId) == "string" then
			local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
			local foodRadius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + HIT_EPSILON
			local rEffective = playerRadius + foodRadius + (root.AssemblyLinearVelocity.Magnitude * (player:GetNetworkPing() * 0.5)) + HIT_EPSILON
			local dXZ = (Vector3.new(currPos.X, 0, currPos.Z) - Vector3.new(hitbox.Position.X, 0, hitbox.Position.Z)).Magnitude
			if dXZ <= rEffective and math.abs(currPos.Y - hitbox.Position.Y) <= Y_TOLERANCE then
				local now = os.clock()
				local speed = root.AssemblyLinearVelocity.Magnitude
				local canReportNow = (lastHit[foodId] or 0) <= now
				print(string.format("[FoodCollisionClient] contact detected foodId=%s template=%s rarity=%s state=%s speed=%.2f", foodId, food.Name, tostring(rarity), tostring(currentMovementState), speed))
				if canReportNow and speed >= MIN_REPORT_SPEED then
					local canReport = canReportForStateAndRarity(currentMovementState, rarity)
					if not canReport then
						 -- print(string.format("[FoodCollisionClient] hit blocked by rarity/state rule foodId=%s template=%s rarity=%s state=%s", foodId, food.Name, tostring(rarity), tostring(currentMovementState)))
						continue
					end
					lastHit[foodId] = now + REPORT_COOLDOWN
					-- Client-side prediction: if it's a common food, make it invisible and non-collidable immediately
					if rarity == "Common" then
						for _, obj in ipairs(food:GetDescendants()) do
							if obj:IsA("BasePart") then
								obj.Transparency = 1
								obj.CanCollide = false
								obj.CanTouch = false
								obj.CanQuery = false
							elseif obj:IsA("Decal") then
								obj.Transparency = 1
							end
						end
					end
					local normal = (currPos - hitbox.Position).Magnitude > 0.001 and (currPos - hitbox.Position).Unit or Vector3.new(0, 0, -1)
					predictedImpacts[foodId] = {
						beforeVelocity = root.AssemblyLinearVelocity,
						beforePosition = currPos,
					}
					applyPredictedLaunchFeel(root, normal)
					-- Fire the remote to report the hit to the server
					print(string.format("[FoodCollisionClient] hit reported foodId=%s template=%s rarity=%s state=%s speed=%.2f", foodId, food.Name, tostring(rarity), tostring(currentMovementState), root.AssemblyLinearVelocity.Magnitude))
					reportRemote:FireServer({
						foodId = foodId,
						hitType = "ClientPredictedFoodOverlap",
						prevPos = lastPos,
						currPos = currPos,
					})
				else
					if not canReportNow then
						print(string.format("[FoodCollisionClient] hit blocked by cooldown foodId=%s rarity=%s state=%s", foodId, tostring(rarity), tostring(currentMovementState)))
					end
				end
			end
		end
	end
	lastPos = currPos
end)

stateUpdateRemote.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end
	local movementState = state.MovementState
	if typeof(movementState) == "string" then
		if movementState == "Move" then
			currentMovementState = GameStates.PlayerState.Moving
		else
			currentMovementState = movementState
		end
	end
end)

gameplayFeedbackRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or message.EventType ~= "FoodHitRejected" then
		return
	end
	local payload = message.Payload
	if type(payload) ~= "table" then
		return
	end
	local foodId = payload.FoodId
	if typeof(foodId) ~= "string" then
		return
	end
	local root = getRoot()
	local predicted = predictedImpacts[foodId]
	if root and predicted then
		root.AssemblyLinearVelocity = predicted.beforeVelocity
		local delta = (root.Position - predicted.beforePosition).Magnitude
		if delta >= MAJOR_DESYNC then
			root.CFrame = CFrame.new(predicted.beforePosition)
		elseif delta >= MINOR_DESYNC then
			root.CFrame = root.CFrame:Lerp(CFrame.new(predicted.beforePosition), 0.35)
		end
	end
	predictedImpacts[foodId] = nil
end)
