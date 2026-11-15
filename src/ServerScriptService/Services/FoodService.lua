--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)
local CollisionValidation = require(script.Parent.Helpers.CollisionValidation)

local FOOD_UI_TEMPLATE_PATH = { "Assets", "UI", "FoodWorldUI" }
local FOOD_HIT_RADIUS_PADDING = PhysicsConfig.Collision.Range
local NORMAL_EPSILON = 1e-5
local MIN_SPEED_EPSILON = 1e-3
local SPAWN_SCHEDULER_INTERVAL_SECONDS = math.max(tonumber(FoodConfig.SpawnSchedulerInterval) or 0.1, 0.05)
local MAX_SPAWN_PER_SCHEDULER_TICK = math.max(1, math.floor(tonumber(FoodConfig.MaxSpawnPerTick) or 16))
local MAX_POOLED_FOOD_PER_TYPE = math.max(0, math.floor(tonumber(FoodConfig.MaxPooledPerType) or 12))
local DEBUG_FOOD_HIT_REJECTS = false

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)

local function getFoodWorldPosition(food: Instance?): Vector3?
	if not food then return nil end
	local hitbox = food:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then return hitbox.Position end
	if food:IsA("BasePart") then return food.Position end
	if food:IsA("Model") then return food:GetPivot().Position end
	return nil
end

local function buildRequiredFoodModels(): { [string]: boolean }
	local required = {}
	for foodName in pairs(FoodConfig.Foods) do
		required[foodName] = true
	end
	return required
end

local FoodService = {}
FoodService.__index = FoodService

local FOOD_TYPE_COLORS = {
	Common = Color3.fromRGB(84, 255, 119),
	Uncommon = Color3.fromRGB(102, 217, 255),
	Rare = Color3.fromRGB(90, 161, 255),
	Epic = Color3.fromRGB(188, 119, 255),
	Legendary = Color3.fromRGB(255, 196, 90),
}


local function isArenaMapName(mapName: string?): boolean
	return type(mapName) == "string" and mapName ~= "LobbyMap" and mapName ~= "Lobby" and string.find(mapName, "Arena", 1, true) ~= nil
end

local function buildPhysicalProperties(): PhysicalProperties
	local physical = PhysicsConfig.PhysicalProperties
	return PhysicalProperties.new(
		physical.Density,
		physical.Friction,
		physical.Elasticity,
		physical.FrictionWeight,
		physical.ElasticityWeight
	)
end

local function anchorFoodModel(model: Model)
	local physicalProperties = buildPhysicalProperties()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CustomPhysicalProperties = physicalProperties
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function resolveFoodHitbox(foodModel: Model): BasePart?
	local hitbox = foodModel:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		if foodModel.PrimaryPart ~= hitbox then
			foodModel.PrimaryPart = hitbox
		end
		return hitbox
	end

	local primaryPart = foodModel.PrimaryPart
	return if primaryPart and primaryPart:IsA("BasePart") then primaryPart else nil
end

local function flattenXZ(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function sanitizeUnit(v: Vector3, fallback: Vector3): Vector3
	if v.Magnitude <= NORMAL_EPSILON then
		return fallback
	end
	return v.Unit
end

function FoodService.new(context)
	local self = setmetatable({}, FoodService)
	self._context = context
	self._foodModels = {}
	self._spawnSlotsByPart = {}
	self._spawnSchedulerRunning = false
	self._foodPool = {}
	self._foodEntries = {}
	self._foodById = {}
	self._foodByInstance = {}
	self._playerConsumeCooldown = {}
	self._foodHitByLaunchTarget = {}
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
	self:_loadFoodModels()
	self:_scanAndSpawnAllArenaMaps()
end

function FoodService:_loadFoodModels()
	self._foodModels = {}

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("FoodModels")
	if not (folder and folder:IsA("Folder")) then
		warn("[FoodService] Missing ReplicatedStorage.Assets.FoodModels")
		return
	end

	for foodName in pairs(buildRequiredFoodModels()) do
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

function FoodService:_assignFoodTypesForZone(zoneName: string, spawnPoints: { any })
	if #spawnPoints == 0 then
		return
	end

	local weights = FoodConfig.ZoneWeights[zoneName]
	local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local availableRarities = {}
	local totalWeight = 0
	local remainders = {}

	for order, rarity in ipairs(rarityOrder) do
		local weight = tonumber(weights and weights[rarity]) or 0
		local hasAvailableModel = false
		for _, foodType in ipairs(FoodConfig.TypePools[rarity] or {}) do
			if self._foodModels[foodType] and FoodConfig.Foods[foodType] then
				hasAvailableModel = true
				break
			end
		end
		if weight > 0 and hasAvailableModel then
			totalWeight += weight
			table.insert(availableRarities, { Rarity = rarity, Weight = weight, Order = order })
		end
	end

	if totalWeight <= 0 then
		warn(string.format("[FoodService] Zone %s has FoodSpawn markers but no configured Food model is available.", zoneName))
		return
	end

	-- Center markers are individually rolled; Mid/Edge preserve the configured zone proportions across markers.
	if zoneName == "CenterZones" then
		for _, point in ipairs(spawnPoints) do
			local roll = math.random() * totalWeight
			local cumulativeWeight = 0
			for _, data in ipairs(availableRarities) do
				cumulativeWeight += data.Weight
				if roll <= cumulativeWeight then
					point.Rarity = data.Rarity
					break
				end
			end
		end
		return
	end

	local rarityCounts = {}
	local allocatedCount = 0
	for _, data in ipairs(availableRarities) do
		local exactCount = #spawnPoints * data.Weight / totalWeight
		local wholeCount = math.floor(exactCount)
		rarityCounts[data.Rarity] = wholeCount
		allocatedCount += wholeCount
		table.insert(remainders, {
			Rarity = data.Rarity,
			Fraction = exactCount - wholeCount,
			Order = data.Order,
		})
	end

	table.sort(remainders, function(a, b)
		if a.Fraction == b.Fraction then
			return a.Order < b.Order
		end
		return a.Fraction > b.Fraction
	end)

	for index = 1, #spawnPoints - allocatedCount do
		local remainder = remainders[index]
		if remainder then
			rarityCounts[remainder.Rarity] = (rarityCounts[remainder.Rarity] or 0) + 1
		end
	end

	local assignedRarities = {}
	for _, rarity in ipairs(rarityOrder) do
		for _ = 1, rarityCounts[rarity] or 0 do
			table.insert(assignedRarities, rarity)
		end
	end
	for index = #assignedRarities, 2, -1 do
		local swapIndex = math.random(1, index)
		assignedRarities[index], assignedRarities[swapIndex] = assignedRarities[swapIndex], assignedRarities[index]
	end

	for index, point in ipairs(spawnPoints) do
		point.Rarity = assignedRarities[index]
	end
end

local function buildSpawnOffset(slotIndex: number, slotCount: number): Vector3
	local maxRadius = math.max(0, tonumber(FoodConfig.SpawnOffsetRadius) or 2)
	if maxRadius <= 0 then
		return Vector3.zero
	end

	local baseAngle = ((slotIndex - 1) / math.max(1, slotCount)) * math.pi * 2
	local angleJitter = (math.random() - 0.5) * (math.pi / math.max(1, slotCount))
	local radius = math.random() * maxRadius
	return Vector3.new(math.cos(baseAngle + angleJitter) * radius, 0, math.sin(baseAngle + angleJitter) * radius)
end

function FoodService:_buildFoodSlotsForSpawnPoint(point: any): number
	local rarity = point.Rarity
	if not rarity then
		return 0
	end

	local availableTypes = {}
	for _, foodType in ipairs(FoodConfig.TypePools[rarity] or {}) do
		local template = self._foodModels[foodType]
		if template and resolveFoodHitbox(template) and FoodConfig.Foods[foodType] then
			table.insert(availableTypes, foodType)
		end
	end
	if #availableTypes == 0 then
		warn(string.format(
			"[FoodService] No valid Food models for rarity %s at %s",
			tostring(rarity),
			point.SpawnPart:GetFullName()
		))
		return 0
	end

	local slotCount = if rarity == "Common"
		then math.max(1, math.floor(tonumber(FoodConfig.CommonFoodsPerSpawn) or 4))
		else 1

	for index = 1, slotCount do
		local foodType = availableTypes[math.random(1, #availableTypes)]
		local slot = {
			MapModel = point.MapModel,
			FoodContainer = point.FoodContainer,
			SpawnPart = point.SpawnPart,
			ZoneName = point.ZoneName,
			FoodType = foodType,
			LocalOffset = buildSpawnOffset(index, slotCount),
			Index = index,
			State = "Pending",
			NextAttemptAt = 0,
			Entry = nil,
		}
		table.insert(point.Slots, slot)
	end

	return slotCount
end

function FoodService:_clearCommonFoodsAtSpawnPart(spawnPart: BasePart, hpSlot: any)
	local record = self._spawnSlotsByPart[spawnPart]
	if record then
		for _, slot in ipairs(record.Slots) do
			local rule = FoodConfig.Foods[slot.FoodType]
			if rule and rule.Type == "Common" and slot ~= hpSlot then
				slot.State = "Disabled"
				slot.Entry = nil
			end
		end
	end

	local toRemove = {}
	for _, entry in pairs(self._foodEntries) do
		local rule = FoodConfig.Foods[entry.FoodType]
		if entry.SpawnPart == spawnPart and rule and rule.Type == "Common" then
			table.insert(toRemove, entry)
		end
	end

	for _, entry in ipairs(toRemove) do
		local instance = entry.Instance
		entry.IsActive = false
		entry.IsConsumed = true
		self._foodEntries[instance] = nil
		if entry.Id then
			self._foodById[entry.Id] = nil
		end
		self._foodByInstance[instance] = nil
		if entry.Slot then
			entry.Slot.Entry = nil
			entry.Slot.State = "Disabled"
		end
		if instance and instance.Parent then
			self:_returnFoodModelToPool(entry.FoodType, instance)
		end
	end
end

function FoodService:_acquireFoodModel(foodType: string): Model?
	local pool = self._foodPool[foodType]
	local model = if pool and #pool > 0 then table.remove(pool) else nil
	if not model then
		local template = self._foodModels[foodType]
		model = template and template:Clone() or nil
	end
	if not model then
		return nil
	end

	model.Parent = nil
	local oldUi = model:FindFirstChild("FoodWorldUI")
	if oldUi then
		oldUi:Destroy()
	end
	model:SetAttribute("FoodId", nil)
	model:SetAttribute("FoodRarity", nil)
	model:SetAttribute("FoodZone", nil)
	model:SetAttribute("FoodSpawnPart", nil)
	model:SetAttribute("FoodSlotIndex", nil)
	model:SetAttribute("FoodHP", nil)
	model:SetAttribute("FoodMaxHP", nil)
	return model
end

function FoodService:_returnFoodModelToPool(foodType: string, model: Model)
	local oldUi = model:FindFirstChild("FoodWorldUI")
	if oldUi then
		oldUi:Destroy()
	end
	model:SetAttribute("FoodId", nil)
	model:SetAttribute("FoodRarity", nil)
	model:SetAttribute("FoodZone", nil)
	model:SetAttribute("FoodSpawnPart", nil)
	model:SetAttribute("FoodSlotIndex", nil)
	model:SetAttribute("FoodHP", nil)
	model:SetAttribute("FoodMaxHP", nil)
	model.Parent = nil

	local pool = self._foodPool[foodType]
	if not pool then
		pool = {}
		self._foodPool[foodType] = pool
	end
	if #pool >= MAX_POOLED_FOOD_PER_TYPE then
		model:Destroy()
		return
	end
	table.insert(pool, model)
end

function FoodService:_trySpawnSlot(slot: any): boolean
	if slot.State ~= "Pending" then
		return false
	end

	local spawnPart = slot.SpawnPart
	local record = spawnPart and self._spawnSlotsByPart[spawnPart]
	if not (record and record.MapModel and record.MapModel.Parent and record.FoodContainer and record.FoodContainer.Parent and spawnPart.Parent) then
		slot.State = "Disabled"
		return false
	end

	local foodType = slot.FoodType
	local rule = foodType and FoodConfig.Foods[foodType]
	local template = foodType and self._foodModels[foodType]
	if not (foodType and rule and template and resolveFoodHitbox(template)) then
		slot.State = "Disabled"
		warn(string.format("[FoodService] Disabled spawn slot because Food model/config is unavailable: %s", tostring(foodType)))
		return false
	end

	-- An HP Food owns the full marker. Remove any Common group still attached to this pivot first.
	if rule.Type ~= "Common" then
		self:_clearCommonFoodsAtSpawnPart(spawnPart, slot)
	end

	local model = self:_acquireFoodModel(foodType)
	if not model then
		slot.State = "Disabled"
		warn(string.format("[FoodService] Could not acquire Food model for spawn slot: %s", foodType))
		return false
	end

	model.Name = foodType
	anchorFoodModel(model)
	local targetPivot = spawnPart:GetPivot() * CFrame.new(slot.LocalOffset or Vector3.zero)
	model:PivotTo(targetPivot)

	local hitbox = resolveFoodHitbox(model)
	if not hitbox then
		self:_returnFoodModelToPool(foodType, model)
		slot.State = "Disabled"
		warn(string.format("[FoodService] Food model lost its Hitbox during spawn: %s", foodType))
		return false
	end

	local entry = {
		Id = game:GetService("HttpService"):GenerateGUID(false),
		Instance = model,
		FoodType = foodType,
		SpawnPart = spawnPart,
		ZoneName = slot.ZoneName,
		Slot = slot,
		IsActive = true,
		IsConsumed = false,
		MaxHP = math.max(0, rule.HP),
		CurrentHP = math.max(0, rule.HP),
		LastHitBy = nil,
	}
	model:SetAttribute("FoodId", entry.Id)
	model:SetAttribute("FoodRarity", rule.Type)
	model:SetAttribute("FoodZone", slot.ZoneName)
	model:SetAttribute("FoodSpawnPart", spawnPart:GetFullName())
	model:SetAttribute("FoodSlotIndex", slot.Index)
	model.Parent = record.FoodContainer
	if entry.MaxHP > 0 then
		self:_attachFoodUI(entry, hitbox)
	end
	self:_publishFoodHp(entry)
	self._foodEntries[model] = entry
	self._foodById[entry.Id] = entry
	self._foodByInstance[model] = entry

	slot.Entry = entry
	slot.State = "Occupied"
	return true
end

function FoodService:_startSpawnScheduler()
	if self._spawnSchedulerRunning then
		return
	end
	self._spawnSchedulerRunning = true

	task.spawn(function()
		while self._spawnSchedulerRunning do
			local now = os.clock()
			local pendingHpSlots = {}
			local pendingCommonSlots = {}

			for spawnPart, record in pairs(self._spawnSlotsByPart) do
				if not (spawnPart.Parent and record.MapModel.Parent and record.FoodContainer.Parent) then
					for _, slot in ipairs(record.Slots) do
						slot.State = "Disabled"
						slot.Entry = nil
					end
					self._spawnSlotsByPart[spawnPart] = nil
				else
					for _, slot in ipairs(record.Slots) do
						if slot.State == "Pending" and slot.NextAttemptAt <= now then
							local rule = FoodConfig.Foods[slot.FoodType]
							if rule and rule.Type == "Common" then
								table.insert(pendingCommonSlots, slot)
							else
								table.insert(pendingHpSlots, slot)
							end
						end
					end
				end
			end

			-- HP Food respawns are always attempted before Common Food respawns.
			local processedCount = 0
			for _, queue in ipairs({ pendingHpSlots, pendingCommonSlots }) do
				for _, slot in ipairs(queue) do
					if processedCount >= MAX_SPAWN_PER_SCHEDULER_TICK then
						break
					end
					processedCount += 1
					self:_trySpawnSlot(slot)
				end
				if processedCount >= MAX_SPAWN_PER_SCHEDULER_TICK then
					break
				end
			end

			task.wait(SPAWN_SCHEDULER_INTERVAL_SECONDS)
		end
	end)
end

function FoodService:ClearMapFood(mapModel: Model)
	for spawnPart, record in pairs(self._spawnSlotsByPart) do
		if spawnPart and spawnPart:IsDescendantOf(mapModel) then
			for _, slot in ipairs(record.Slots) do
				slot.State = "Disabled"
				slot.Entry = nil
			end
			self._spawnSlotsByPart[spawnPart] = nil
		end
	end

	for instance, entry in pairs(self._foodEntries) do
		if instance and instance.Parent and instance:IsDescendantOf(mapModel) then
			entry.IsActive = false
			entry.IsConsumed = true
			self._foodEntries[instance] = nil
			if entry.Id then
				self._foodById[entry.Id] = nil
			end
			self._foodByInstance[instance] = nil
			if entry.Slot then
				entry.Slot.Entry = nil
				entry.Slot.State = "Disabled"
			end
			self:_returnFoodModelToPool(entry.FoodType, instance)
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

	local zoneFolders = {}
	for _, child in ipairs(foodSpawns:GetChildren()) do
		if child:IsA("Folder") and FoodConfig.ZoneWeights[child.Name] then
			table.insert(zoneFolders, child)
		end
	end
	table.sort(zoneFolders, function(a, b)
		return a.Name < b.Name
	end)

	for _, zoneFolder in ipairs(zoneFolders) do
		local spawnParts = {}
		for _, child in ipairs(zoneFolder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(spawnParts, child)
			end
		end
		table.sort(spawnParts, function(a, b)
			return a.Name < b.Name
		end)

		local spawnPoints = {}
		for _, spawnPart in ipairs(spawnParts) do
			local point = {
				MapModel = mapModel,
				FoodContainer = foodContainer,
				SpawnPart = spawnPart,
				ZoneName = zoneFolder.Name,
				Rarity = nil,
				Slots = {},
			}
			self._spawnSlotsByPart[spawnPart] = point
			table.insert(spawnPoints, point)
		end

		self:_assignFoodTypesForZone(zoneFolder.Name, spawnPoints)

		local rarityCounts = {}
		local commonFoodSlotCount = 0
		local hpFoodSlotCount = 0
		for _, point in ipairs(spawnPoints) do
			if point.Rarity then
				rarityCounts[point.Rarity] = (rarityCounts[point.Rarity] or 0) + 1
				local slotCount = self:_buildFoodSlotsForSpawnPoint(point)
				if point.Rarity == "Common" then
					commonFoodSlotCount += slotCount
				else
					hpFoodSlotCount += slotCount
				end
			end
		end

		local raritySummary = {}
		for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
			local count = rarityCounts[rarity] or 0
			if count > 0 then
				table.insert(raritySummary, string.format("%s:%d", rarity, count))
			end
		end

		print(string.format(
			"[FoodService] Pivot spawn points prepared. map=%s zone=%s markers=%d commonFoods=%d hpFoods=%d rarity=%s",
			mapModel.Name,
			zoneFolder.Name,
			#spawnPoints,
			commonFoodSlotCount,
			hpFoodSlotCount,
			table.concat(raritySummary, ",")
		))
	end
end

function FoodService:_rewardFoodKill(entry: any)
	local player = entry.LastHitBy
	local rule = FoodConfig.Foods[entry.FoodType]
	if not (player and rule) then
		return
	end
	self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
	-- Touch foods are counted by _consumeFood. This branch handles only
	-- hit-to-destroy food so bomb area damage cannot count a Touch food twice.
	if not rule.Touch then
		self._context.EventBus:Fire("DailyQuestFoodCollected", player, entry.FoodType, rule.Type)
	end

	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local reward = { Diamonds = 0, Items = {} }
	local hasReward = false

	if rule.Type == "Legendary" then
		table.insert(reward.Items, { Id = "gift_box", Quantity = 1 })
		hasReward = true
	end

	-- LuckBoosted affects only this server-side roll; it never changes the diamond amount.
	local diamondRate = rule.DiamondRate
	local luckFlag = stateService and stateService:GetFlag(player, "LuckBoosted")
	local luckPercent = luckFlag and luckFlag.Data and tonumber(luckFlag.Data.DiamondDropChanceBonusPercent) or 0
	diamondRate = math.clamp(diamondRate * (1 + math.max(0, luckPercent) / 100), 0, 1)
	if diamondRate > 0 and rule.DiamondAmount > 0 and math.random() <= diamondRate then
		reward.Diamonds = rule.DiamondAmount
		hasReward = true
	end

	if hasReward and dataService and typeof(dataService.GrantReward) == "function" then
		local reason = if rule.Type == "Legendary" then "LegendaryFoodLastHit" else "FoodConsumed"
		dataService:GrantReward(player, reward, reason)
		if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
			stateService:RecalculateDerivedStats(player, false)
		end
		local itemService = ServiceResolver.Get(self._context, "ItemService")
		if itemService and typeof(itemService.PublishInventory) == "function" then
			itemService:PublishInventory(player)
		end
	elseif hasReward and rule.Type == "Legendary" then
		warn("[FoodService] PlayerDataService unavailable; Legendary Gift Box reward was not granted.")
	end
end

function FoodService:_consumeFood(entry: any, player: Player)
	if not entry.IsActive or entry.IsConsumed then
		return
	end
	local soundPosition = getFoodWorldPosition(entry.Instance)
	entry.IsConsumed = true
	entry.IsActive = false
	local instance = entry.Instance
	self._foodEntries[instance] = nil
	if entry.Id then
		self._foodById[entry.Id] = nil
	end
	self._foodByInstance[instance] = nil
	if instance and instance.Parent then
		self:_returnFoodModelToPool(entry.FoodType, instance)
	end
	local rule = FoodConfig.Foods[entry.FoodType]
	if rule then
		if rule.Touch and rule.Type == "Common" and soundPosition then
			SoundManager.Play("SFX_Food_Consume", soundPosition)
		end
		self._context.EventBus:Fire("CollisionDetected", "Food", player, nil, {})
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		if rule.Touch then
			self._context.EventBus:Fire("FoodConsumed", player, rule.Exp)
			self._context.EventBus:Fire("DailyQuestFoodCollected", player, entry.FoodType, rule.Type)
		end
		if stateService and rule.HealHP > 0 then
			stateService:Heal(player, rule.HealHP)
			stateService:PublishState(player)
		end
		local slot = entry.Slot
		if slot then
			slot.Entry = nil
			slot.State = "Pending"
			slot.NextAttemptAt = os.clock() + math.max(0, tonumber(rule.RespawnTime) or 1)
			slot.BlockedAttempts = 0
			slot.WarnedBlocked = false
		end
	end
end

function FoodService:_rejectFoodHit(player: Player, reason: string, payload: any, details: { [string]: any }?)
	if not DEBUG_FOOD_HIT_REJECTS then
		return
	end
	local foodId = if type(payload) == "table" then payload.foodId else nil
	local fields = {
		`player={player.Name}`,
		`reason={reason}`,
		`foodId={tostring(foodId)}`,
	}
	if details then
		for key, value in pairs(details) do
			table.insert(fields, `{key}={tostring(value)}`)
		end
	end
	warn(`[FoodHitRejected] {table.concat(fields, " ")}`)
end

function FoodService:_validateFoodHit(player: Player, entry: any, payload: any): (boolean, string?, { [string]: any }?, CollisionValidation.ValidationResult?)
	if not entry then
		return false, "missing_or_already_consumed_target", nil, nil
	end
	if not (entry.IsActive and not entry.IsConsumed and entry.Instance and entry.Instance.Parent) then
		return false, "missing_or_already_consumed_target", {
			isActive = entry.IsActive,
			isConsumed = entry.IsConsumed,
		}, nil
	end
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule then
		return false, "missing_food_rule", { foodType = entry.FoodType }, nil
	end
	local hitbox = entry.Instance:FindFirstChild("Hitbox")
	if not (hitbox and hitbox:IsA("BasePart")) then
		return false, "missing_or_already_consumed_target", { missingHitbox = true }, nil
	end
	local validation = CollisionValidation.ValidateAttackerTarget(self._context, player, {
		Kind = "Food",
		Player = nil,
		Part = hitbox,
		RadiusPadding = FOOD_HIT_RADIUS_PADDING,
		RequiresLaunching = (not rule.Touch) and entry.MaxHP > 0,
		AllowTouchStates = rule.Touch == true,
	}, payload)
	if not validation.Ok then
		return false, validation.Reason, validation.Details, validation
	end
	return true, nil, nil, validation
end

function FoodService:_resolveFoodCollisionVelocity(root: BasePart, hitbox: BasePart, payload: any, rule: any): Vector3
	local rootVelocity = CombatCollision.FlattenXZ(root.AssemblyLinearVelocity)
	local reportedVelocity = (payload and typeof(payload.velocity) == "Vector3")
		and CombatCollision.FlattenXZ(payload.velocity)
		or Vector3.zero
	local velocity = if rootVelocity.Magnitude >= reportedVelocity.Magnitude then rootVelocity else reportedVelocity
	if rule.Touch then
		return velocity
	end
	local normal = self:_computeCollisionNormal(root.Position, hitbox.Position, velocity)
	return CombatCollision.ResolveAttackerBounce(velocity, Vector3.zero, normal).AttackerVelocity
end


function FoodService:ApplyDamageToFood(foodOrEntry: any, amount: number, player: Player?, shouldPlayHitSound: boolean?, allowHumanAttacker: boolean?): boolean
	local entry = if type(foodOrEntry) == "table" then foodOrEntry else self._foodByInstance[foodOrEntry]
	local rule = entry and FoodConfig.Foods[entry.FoodType]
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if (stateService and stateService:IsHuman(player) and allowHumanAttacker ~= true) or not (entry and rule and player) or entry.CurrentHP <= 0 or entry.IsConsumed then
		return false
	end
	local damage = math.max(0, amount)
	if damage <= 0 then
		return false
	end
	local before = entry.CurrentHP
	entry.LastHitBy = player
	entry.CurrentHP = math.max(0, entry.CurrentHP - damage)
	local soundPosition = getFoodWorldPosition(entry.Instance)
	if soundPosition and entry.CurrentHP <= 0 then
		SoundManager.Play("SFX_Food_Destroy", soundPosition)
	elseif soundPosition and shouldPlayHitSound ~= false then
		SoundManager.Play("SFX_Food_Hit", soundPosition)
	end
	local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	if hitbox and hitbox:IsA("BasePart") and playerService and entry.CurrentHP ~= before then
		playerService:ShowFloatingText(hitbox, "Damage", before - entry.CurrentHP)
	end
	self:_publishFoodHp(entry)
	if entry.CurrentHP <= 0 then
		self:_rewardFoodKill(entry)
		self:_consumeFood(entry, player)
	end
	return true
end

-- Bomb area damage is resolved by FoodService so LastHitBy, food rewards,
-- respawn scheduling, and FoodConsumed events remain owned by this service.
function FoodService:ApplyAreaDamageToFood(center: Vector3, radius: number, amount: number, player: Player, maxDamageFalloffPercent: number?): number
	if typeof(center) ~= "Vector3" or not player or radius < 0 or amount <= 0 then
		return 0
	end

	local falloffPercent = math.clamp(tonumber(maxDamageFalloffPercent) or 0, 0, 100) / 100
	local candidates = {}
	for _, entry in pairs(self._foodEntries) do
		if entry and entry.IsActive and not entry.IsConsumed and entry.Instance and entry.Instance.Parent then
			local position = getFoodWorldPosition(entry.Instance)
			local distance = if position then (position - center).Magnitude else math.huge
			if position and distance <= radius then
				table.insert(candidates, { Entry = entry, Distance = distance })
			end
		end
	end

	local damagedCount = 0
	for _, candidate in ipairs(candidates) do
		local distanceRatio = if radius > 0 then math.clamp(candidate.Distance / radius, 0, 1) else 0
		local scaledDamage = amount * (1 - falloffPercent * distanceRatio)
		if self:ApplyDamageToFood(candidate.Entry, scaledDamage, player, false, true) then
			damagedCount += 1
		end
	end
	return damagedCount
end

function FoodService:_applyLauncherDamage(entry: any, player: Player, velocity: number)
	local rule = FoodConfig.Foods[entry.FoodType]
	if not rule or entry.CurrentHP <= 0 then
		return
	end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local damagePipeline = ServiceResolver.Get(self._context, "DamagePipelineService")
	local attackerState = stateService and stateService:GetState(player) or {}
	local damage = if damagePipeline and typeof(damagePipeline.ComputeCollisionDamage) == "function"
		then damagePipeline:ComputeCollisionDamage(attackerState, velocity, {
			SourceType = "FoodLauncherCollision",
			InitialImpactSpeed = velocity,
			AttackerAbsoluteSpeed = velocity,
			LaunchEnergy = velocity,
			LauncherMaxSpeed = attackerState and attackerState.LaunchSpeed or PhysicsConfig.Launch.SpeedMin,
			CollisionCount = 0,
			AngleFactor = 1,
		})
		else 0
	self:ApplyDamageToFood(entry, damage, player)
end

function FoodService:_computeCollisionNormal(playerPosition: Vector3, foodPosition: Vector3, velocity: Vector3): Vector3
	local planarVelocity = CombatCollision.FlattenXZ(velocity)
	local fallbackNormal = sanitizeUnit(CombatCollision.FlattenXZ(-velocity), Vector3.new(0, 0, -1))
	local normal = sanitizeUnit(playerPosition - foodPosition, fallbackNormal)
	if planarVelocity.Magnitude > MIN_SPEED_EPSILON and planarVelocity:Dot(normal) < 0 then
		normal = -normal
	end
	return normal
end

function FoodService:_resolvePenetration(root: BasePart, hitbox: BasePart, normal: Vector3)
	local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.5 + FOOD_HIT_RADIUS_PADDING
	local currentOffset = root.Position - hitbox.Position
	local planarDistance = flattenXZ(currentOffset).Magnitude
	local penetrationDepth = radius - planarDistance
	if penetrationDepth <= 0 then
		return
	end
	local pushNormal = sanitizeUnit(flattenXZ(normal), Vector3.new(0, 0, -1))
	local pushOut = pushNormal * (penetrationDepth + 0.05)
	root.CFrame = root.CFrame + Vector3.new(pushOut.X, 0, pushOut.Z)
end

function FoodService:_startCollisionLoop()
	return
end

function FoodService:Start()
	self:_startSpawnScheduler()
	local remote = self._context.Remotes:FindFirstChild("ReportFoodHit")
	local feedbackRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		local now = os.clock()
		local rateLimiter = ServiceResolver.Get(self._context, "RateLimiter")
		if rateLimiter and not rateLimiter:Allow(RemoteContracts.Names.ReportFoodHit, tostring(player.UserId), 1, now) then
			self:_rejectFoodHit(player, "rate_limited", payload, nil)
			return
		end
		local entry = (type(payload) == "table") and self._foodById[payload.foodId] or nil
		local dedupeService = ServiceResolver.Get(self._context, "HitCooldownDedupe")

		if type(payload) ~= "table" then
			self:_rejectFoodHit(player, "invalid_payload", payload, nil)
			return
		end
		if entry and entry.Id and dedupeService and not dedupeService:TryAcquire("FoodHit", `{player.UserId}:{entry.Id}`, PhysicsConfig.Collision.Cooldown, now) then
			self:_rejectFoodHit(player, "same_target_dedupe", payload, { foodId = entry.Id })
			return
		end

		local valid, reason, details = self:_validateFoodHit(player, entry, payload)
		if not valid then
			self:_rejectFoodHit(player, reason or "validation_failed", payload, details)
			if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
				feedbackRemote:FireClient(player, {
					EventType = "FoodHitRejected",
					Payload = {
						FoodId = payload.foodId,
						Reason = reason,
						ServerResync = true,
					},
				})
			end
			return
		end

		local rule = FoodConfig.Foods[entry.FoodType]
		if not rule then
			self:_rejectFoodHit(player, "missing_food_rule", payload, { foodType = entry.FoodType })
			return
		end
		if rule.Touch then
			self:_consumeFood(entry, player)
		elseif entry.MaxHP > 0 then
			local playerService = ServiceResolver.Get(self._context, "PlayerService")
			local root = playerService and playerService:GetRoot(player)
			local hitbox = entry.Instance and entry.Instance:FindFirstChild("Hitbox")
			if not (root and hitbox and hitbox:IsA("BasePart")) then
				self:_rejectFoodHit(player, "missing_player_or_target_root", payload, nil)
				return
			end
			local serverHorizontalSpeed = flattenXZ(root.AssemblyLinearVelocity).Magnitude
			local clientObservedSpeed = if typeof(payload.observedSpeed) == "number" then payload.observedSpeed else 0
			local horizontalSpeed = math.max(serverHorizontalSpeed, clientObservedSpeed)

			self._context.EventBus:Fire("CollisionDetected", "Food", player, entry.Instance, { FoodId = entry.Id })
			self:_applyLauncherDamage(entry, player, horizontalSpeed)
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
	local mapService = ServiceResolver.Get(self._context, "MapService")
	local arena = mapService and mapService:GetArenaModel()
	if arena then
		self:ClearMapFood(arena)
		self:SpawnFoodForMap(arena)
	end
end

function FoodService:SpawnFoodForMapName(mapName: string)
	self:LoadMapResources(mapName)
end

return FoodService
