--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)

local COLLISION_INTERVAL = 0.1
local CONSUME_COOLDOWN = 0.12
local DEFAULT_HIT_COOLDOWN = 0.18
local BURST_SPEED_THRESHOLD = 60
local FOOD_UI_TEMPLATE_PATH = { "Assets", "UI", "FoodWorldUI" }
local DAMAGE_MIN_VELOCITY = 20
local DAMAGE_MAX_VELOCITY = 170
local DAMAGE_BASE = 1
local FOOD_HIT_RADIUS_PADDING = 3.2

local REQUIRED_FOOD_MODELS = {
	CommonBlue = true,
	CommonGreen = true,
	CommonRed = true,
	UncommonIce = true,
	RareAmber = true,
	EpicViolet = true,
	LegendaryGold = true,
	MythicCrystal = true,
	UniqueCore = true,
	UniqueCrown = true,
}

local FoodService = {}
FoodService.__index = FoodService

local FOOD_TYPE_COLORS = {
	Common = Color3.fromRGB(84, 255, 119),
	Uncommon = Color3.fromRGB(102, 217, 255),
	Rare = Color3.fromRGB(90, 161, 255),
	Epic = Color3.fromRGB(188, 119, 255),
	Legendary = Color3.fromRGB(255, 196, 90),
	Mythic = Color3.fromRGB(255, 122, 215),
	Unique = Color3.fromRGB(255, 88, 88),
}

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function isArenaMapName(mapName: string?): boolean
	return type(mapName) == "string" and mapName ~= "LobbyMap" and mapName ~= "Lobby" and string.find(mapName, "Arena", 1, true) ~= nil
end

local function anchorFoodModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function flattenXZ(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function sqrDistanceXZ(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

local function distancePointToSegmentSquaredXZ(point: Vector3, segStart: Vector3, segEnd: Vector3): number
	local sx = segStart.X
	local sz = segStart.Z
	local ex = segEnd.X
	local ez = segEnd.Z
	local px = point.X
	local pz = point.Z
	local vx = ex - sx
	local vz = ez - sz
	local wx = px - sx
	local wz = pz - sz
	local segLenSq = vx * vx + vz * vz
	if segLenSq <= 1e-6 then
		local dx = px - sx
		local dz = pz - sz
		return dx * dx + dz * dz
	end
	local t = math.clamp((wx * vx + wz * vz) / segLenSq, 0, 1)
	local cx = sx + (vx * t)
	local cz = sz + (vz * t)
	local dx = px - cx
	local dz = pz - cz
	return dx * dx + dz * dz
end

function FoodService.new(context)
	local self = setmetatable({}, FoodService)
	self._context = context
	self._foodModels = {}
	self._foodSpawnsByZone = {}
	self._foodEntries = {}
	self._foodByInstance = {}
	self._playerConsumeCooldown = {}
	self._slingFoodHitCooldown = {}
	self._lastPawnPos = {}
	self._heartbeatConnection = nil
	return self
end

function FoodService:_resolveFoodUiTemplate(): BillboardGui?
	local current = ReplicatedStorage
	for _, childName in ipairs(FOOD_UI_TEMPLATE_PATH) do
		current = current and current:FindFirstChild(childName)
	end
	if current and current:IsA("BillboardGui") then
		return current
	end
	return nil
end

function FoodService:_attachFoodUI(entry: any, hitbox: BasePart)
	local template = self:_resolveFoodUiTemplate()
	if not template then
		return
	end
	local ui = template:Clone()
	ui.Name = "FoodWorldUI"
	ui.Adornee = hitbox
	ui.Enabled = false
	ui.Parent = entry.Instance
	local fill = ui:FindFirstChild("HpBarBackground")
	fill = fill and fill:FindFirstChild("HpBarFill")
	if fill and fill:IsA("Frame") then
		local foodType = FoodConfig.Foods[entry.FoodType] and FoodConfig.Foods[entry.FoodType].Type
		fill.BackgroundColor3 = FOOD_TYPE_COLORS[foodType] or FOOD_TYPE_COLORS.Common
	end
	entry.WorldUI = ui
end

function FoodService:_publishFoodHp(entry: any)
	if not entry or not entry.Instance then
		return
	end
	entry.Instance:SetAttribute("FoodHP", math.max(0, entry.CurrentHP))
	entry.Instance:SetAttribute("FoodMaxHP", math.max(1, entry.MaxHP))
end

function FoodService:Init()
	print("[FoodService] Init called")
	self:_loadFoodModels()
	self:_scanAndSpawnAllArenaMaps()
	self:_startCollisionLoop()
end

function FoodService:_loadFoodModels()
	self._foodModels = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("FoodModels")

	if not (folder and folder:IsA("Folder")) then
		warn("[FoodService] Missing ReplicatedStorage.Assets.FoodModels")
		return
	end
	
	for foodName in pairs(REQUIRED_FOOD_MODELS) do
		local model = folder:FindFirstChild(foodName)
		if model and model:IsA("Model") then
			local hitbox = model:FindFirstChild("Hitbox")
			local visual = model:FindFirstChild("Visual")
			if hitbox and hitbox:IsA("BasePart") and visual then
				self._foodModels[foodName] = model
			else
				warn(string.format("[FoodService] Invalid food model shape: %s", model:GetFullName()))
			end
		else
			warn(string.format("[FoodService] Missing food model: %s", foodName))
		end
	end
end

function FoodService:_scanAndSpawnAllArenaMaps()
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not (mapsRoot and mapsRoot:IsA("Folder")) then
		return
	end
	for _, child in ipairs(mapsRoot:GetChildren()) do
		if child:IsA("Model") and isArenaMapName(child.Name) then
			self:ClearMapFood(child)
			self:SpawnFoodForMap(child)
		end
	end
end

function FoodService:_pickWeightedType(zoneName: string): string?
	local weights = FoodConfig.ZoneWeights[zoneName]
	if not weights then
		return nil
	end
	local totalWeight = 0
	for rarity, weight in pairs(weights) do
		if weight > 0 and FoodConfig.TypePools[rarity] then
			totalWeight += weight
		end
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = math.random() * totalWeight
	local run = 0
	for rarity, weight in pairs(weights) do
		if weight > 0 and FoodConfig.TypePools[rarity] then
			run += weight
			if roll <= run then
				local pool = FoodConfig.TypePools[rarity]
				if #pool > 0 then
					return pool[math.random(1, #pool)]
				end
			end
		end
	end
	return nil
end

function FoodService:_buildSpawnPosition(spawnPart: BasePart, usedPositions: { Vector3 }): Vector3
	local radius = FoodConfig.SpawnRadius
	local minDistance = FoodConfig.MinNoOverlapDistance
	local minDistanceSq = minDistance * minDistance
	local fallback = spawnPart.Position
	for _ = 1, 6 do
		local offset = Vector3.new(math.random(-radius, radius), 0, math.random(-radius, radius))
		local candidate = spawnPart.Position + offset
		local overlaps = false
		for _, prior in ipairs(usedPositions) do
			if sqrDistanceXZ(candidate, prior) < minDistanceSq then
				overlaps = true
				break
			end
		end
		if not overlaps then
			return candidate
		end
	end
	return fallback
end

function FoodService:_spawnFoodOnSpawn(mapModel: Model, foodContainer: Folder, spawnPart: BasePart, zoneName: string)
	local foodType = self:_pickWeightedType(zoneName)
	if not foodType then
		return
	end
	local foodRule = FoodConfig.Foods[foodType]
	local template = self._foodModels[foodType]
	if not (foodRule and template) then
		return
	end
	local usedPositions = self._foodSpawnsByZone[spawnPart] or {}
	local spawnPos = self:_buildSpawnPosition(spawnPart, usedPositions)
	table.insert(usedPositions, spawnPos)
	self._foodSpawnsByZone[spawnPart] = usedPositions

	local clone = template:Clone()
	clone.Name = foodType
	clone.Parent = foodContainer
	anchorFoodModel(clone)
	local hitbox = clone:FindFirstChild("Hitbox") :: BasePart?
	if not hitbox then
		clone:Destroy()
		return
	end
	clone.PrimaryPart = hitbox
	clone:PivotTo(CFrame.new(spawnPos))
	local entry = {
		Instance = clone,
		FoodType = foodType,
		SpawnPart = spawnPart,
		ZoneName = zoneName,
		IsActive = true,
		IsConsumed = false,
		MaxHP = math.max(0, foodRule.HP),
		CurrentHP = math.max(0, foodRule.HP),
		LastHitBy = nil,
	}
	if entry.MaxHP > 0 then
		self:_attachFoodUI(entry, hitbox)
	end
	self:_publishFoodHp(entry)
	self._foodEntries[clone] = entry
	self._foodByInstance[clone] = entry
end

function FoodService:ClearMapFood(mapModel: Model)
	for instance, entry in pairs(self._foodEntries) do
		if instance and instance.Parent and instance:IsDescendantOf(mapModel) then
			entry.IsActive = false
			instance:Destroy()
			self._foodEntries[instance] = nil
			self._foodByInstance[instance] = nil
		end
	end
end

function FoodService:SpawnFoodForMap(mapModel: Model)
	local foodContainer = mapModel:FindFirstChild("FoodContainer")
	local foodSpawns = mapModel:FindFirstChild("FoodSpawns")
	if not (foodContainer and foodContainer:IsA("Folder")) then
		warn(string.format("[FoodService] Missing required folder: %s", mapModel:GetFullName() .. ".FoodContainer"))
		return
	end
	if not (foodSpawns and foodSpawns:IsA("Folder")) then
		warn(string.format("[FoodService] Missing required folder: %s", mapModel:GetFullName() .. ".FoodSpawns"))
		return
	end
	for _, zoneFolder in ipairs(foodSpawns:GetChildren()) do
		if zoneFolder:IsA("Folder") and FoodConfig.ZoneWeights[zoneFolder.Name] then
			for _, spawnPart in ipairs(zoneFolder:GetChildren()) do
				if spawnPart:IsA("BasePart") then
					self:_spawnFoodOnSpawn(mapModel, foodContainer, spawnPart, zoneFolder.Name)
				end
			end
		end
	end
end

function FoodService:_isPlayerAlive(player: Player): boolean
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return true
	end
	local state = stateService:GetState(player)
	return state ~= nil and state.IsAlive == true
end

function FoodService:_rewardFoodKill(entry: any)
	local player = entry.LastHitBy
	local rule = FoodConfig.Foods[entry.FoodType]
	if not (player and rule) then
		return
	end
	self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
	if rule.DiamondRate > 0 and rule.DiamondAmount > 0 and math.random() <= rule.DiamondRate then
		local stateService = getService(self._context, "PlayerStateService")
		local state = stateService and stateService:GetState(player)
		if state then
			state.Diamonds = math.max(0, state.Diamonds + rule.DiamondAmount)
			stateService:PublishState(player)
		end
	end
end

function FoodService:_consumeFood(entry: any, player: Player)
	if not entry.IsActive or entry.IsConsumed then
		return
	end
	entry.IsConsumed = true
	entry.IsActive = false
	local instance = entry.Instance
	self._foodEntries[instance] = nil
	self._foodByInstance[instance] = nil
	if instance and instance.Parent then
		instance:Destroy()
	end
	local rule = FoodConfig.Foods[entry.FoodType]
	if rule then
		self._context.EventBus:Fire("CollisionDetected", "Food", player, nil, {})
		local stateService = getService(self._context, "PlayerStateService")
		if rule.Touch then
			self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
		end
		if stateService and rule.HealHP > 0 then
			stateService:Heal(player, rule.HealHP)
			stateService:PublishState(player)
		end
		local respawnDelay = rule.RespawnTime
		task.delay(respawnDelay, function()
			if entry.SpawnPart and entry.SpawnPart.Parent then
				local mapModel = entry.SpawnPart:FindFirstAncestorOfClass("Model")
				if mapModel then
					local foodContainer = mapModel:FindFirstChild("FoodContainer")
					if foodContainer and foodContainer:IsA("Folder") then
						self:_spawnFoodOnSpawn(mapModel, foodContainer, entry.SpawnPart, entry.ZoneName)
					end
				end
			end
		end)
	end
end

function FoodService:_applySlingDamage(entry: any, player: Player, velocity: number)
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule or entry.CurrentHP <= 0 then
		return
	end
	local clampedVelocity = math.clamp(velocity, DAMAGE_MIN_VELOCITY, DAMAGE_MAX_VELOCITY)
	local damage = clampedVelocity * DAMAGE_BASE
	entry.LastHitBy = player
	entry.CurrentHP = math.max(0, entry.CurrentHP - damage)
	self:_publishFoodHp(entry)
	if entry.CurrentHP <= 0 then
		self:_rewardFoodKill(entry)
		self:_consumeFood(entry, player)
	end
end

function FoodService:_processPlayerFoodCollision(player: Player, pawn: Model, pawnPos: Vector3, prevPos: Vector3?)
	if not self:_isPlayerAlive(player) then
		return
	end
	if (self._playerConsumeCooldown[player] or 0) > os.clock() then
		return
	end
	for _, entry in pairs(self._foodEntries) do
		if entry.IsActive and not entry.IsConsumed then
			local instance = entry.Instance
			local hitbox = instance and instance:FindFirstChild("Hitbox")
			if hitbox and hitbox:IsA("BasePart") then
				local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + FOOD_HIT_RADIUS_PADDING
				local radiusSq = radius * radius
				local canTouch = FoodConfig.Foods[entry.FoodType].Touch == true
				local isBurst = flattenXZ((pawn.PrimaryPart and pawn.PrimaryPart.AssemblyLinearVelocity or Vector3.zero)).Magnitude >= BURST_SPEED_THRESHOLD
				local collides = sqrDistanceXZ(pawnPos, hitbox.Position) <= radiusSq
				if (not collides) and isBurst and prevPos then
					collides = distancePointToSegmentSquaredXZ(hitbox.Position, prevPos, pawnPos) <= radiusSq
				end
				if collides then
					if canTouch then
						self._playerConsumeCooldown[player] = os.clock() + CONSUME_COOLDOWN
						self:_consumeFood(entry, player)
						return
					elseif entry.MaxHP > 0 then
						local now = os.clock()
						local perPlayer = self._slingFoodHitCooldown[player]
						if not perPlayer then
							perPlayer = {}
							self._slingFoodHitCooldown[player] = perPlayer
						end
						local hitCooldown = DEFAULT_HIT_COOLDOWN
						local cooldownKey = entry.Instance
						local nextAllowedAt = perPlayer[cooldownKey] or 0
						if nextAllowedAt <= now then
							local speed = flattenXZ((pawn.PrimaryPart and pawn.PrimaryPart.AssemblyLinearVelocity or Vector3.zero)).Magnitude
							self:_applySlingDamage(entry, player, speed)
							perPlayer[cooldownKey] = now + hitCooldown
							return
						end
					end
				end
			end
		end
	end
end

function FoodService:_startCollisionLoop()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
	local accum = 0
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < COLLISION_INTERVAL then
			return
		end
		accum = 0
		local playerService = getService(self._context, "PlayerService")
		if not playerService then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local pawn = playerService:GetPawn(player)
			local root = pawn and (pawn.PrimaryPart or pawn:FindFirstChild("Hitbox"))
			if pawn and root and root:IsA("BasePart") then
				local currPos = root.Position
				local prevPos = self._lastPawnPos[player]
				self:_processPlayerFoodCollision(player, pawn, currPos, prevPos)
				self._lastPawnPos[player] = currPos
			end
		end
	end)
end

function FoodService:LoadMapResources(mapName: string)
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not (mapsRoot and mapsRoot:IsA("Folder")) then
		return
	end
	local mapModel = mapsRoot:FindFirstChild(mapName)
	if mapModel and mapModel:IsA("Model") and isArenaMapName(mapName) then
		self:ClearMapFood(mapModel)
		self:SpawnFoodForMap(mapModel)
	end
end

function FoodService:SpawnFoodForActiveMap()
	local mapService = getService(self._context, "MapService")
	local arena = mapService and mapService:GetArenaModel()
	if arena then
		self:SpawnFoodForMap(arena)
	end
end

function FoodService:SpawnFoodForMapName(mapName: string)
	self:LoadMapResources(mapName)
end

return FoodService
