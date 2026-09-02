--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local MockProvider = require(script.Parent.DataProviders.MockProvider)

type Context = { EventBus: any?, Services: any?, ServiceRegistry: any? }

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService


local function buildStarterEquipmentInventory(): { [string]: any }
	local inventory = {}
	for _, definitionId in ipairs(EquipmentConfig.GetAllIds()) do
		local definition = EquipmentConfig.GetById(definitionId)
		inventory["starter_equipment_" .. definitionId] = {
			definitionId = definitionId,
			level = 1,
			rarity = (definition and definition.rarity) or "Common",
			acquiredAt = os.time(),
		}
	end
	return inventory
end

local RETIRED_EQUIPMENT_IDS = { SmokeBomb = true, MagnetCore = true }
local EQUIPMENT_ID_ALIASES = { ShadowCloakZ = "ShadowCloak" }

local function currentMondayStamp(now: number): number
	local date = os.date("!*t", now)
	local daysSinceMonday = (date.wday + 5) % 7
	date.hour = 0; date.min = 0; date.sec = 0
	return os.time(date) - (daysSinceMonday * 24 * 60 * 60)
end

function PlayerDataService.new(context: Context, provider: any?)
	local self = setmetatable({}, PlayerDataService)
	self._context = context
	self._provider = provider or MockProvider.new()
	return self
end

function PlayerDataService:BuildDefaultData(player: Player): { [string]: any }
	return {
		UserId = player.UserId,
		Level = 1,
		Coin = 0,
		ProgressPoints = {
			TotalPoints = 0,
			RoundPoints = 0,
			WeeklyPoints = 0,
			WeeklyResetAt = currentMondayStamp(os.time()),
			PendingWeeklyReward = nil,
			LastWeeklyRewardAt = 0,
		},
		QuestState = {
			DailyResetAt = 0,
			Metrics = {},
			Claimed = {},
		},
		Diamonds = 0,
		OwnedItems = {},
		OwnedEquipment = buildStarterEquipmentInventory(),
		EquippedEquipment = { [1] = nil, [2] = nil, [3] = nil },
	}
end

function PlayerDataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:LoadPlayer(player)
	end
end

function PlayerDataService:LoadPlayer(player: Player): { [string]: any }
	local data = self._provider:LoadPlayerData(player, self:BuildDefaultData(player))
	self:_ensureProgress(data)
	self:_ensureEquipmentData(data)
	return data
end

function PlayerDataService:GetData(player: Player): { [string]: any }
	return self._provider:GetPlayerData(player) or self:LoadPlayer(player)
end

function PlayerDataService:SavePlayer(player: Player): boolean
	local data = self._provider:GetPlayerData(player)
	return data ~= nil and self._provider:SavePlayerData(player, data) or false
end

function PlayerDataService:UpdateData(player: Player, updater: ({ [string]: any }) -> { [string]: any }?): { [string]: any }
	if self._provider:GetPlayerData(player) == nil then
		self:LoadPlayer(player)
	end
	local updated = self._provider:UpdatePlayerData(player, updater) or self:GetData(player)
	self:_ensureProgress(updated)
	self:_ensureEquipmentData(updated)
	return updated
end

function PlayerDataService:_ensureEquipmentData(data: { [string]: any })
	data.Diamonds = math.max(0, math.floor(tonumber(data.Diamonds) or 0))
	if type(data.OwnedItems) ~= "table" then
		data.OwnedItems = {}
	end
	if type(data.OwnedEquipment) ~= "table" then
		data.OwnedEquipment = {}
	end
	if type(data.EquippedEquipment) ~= "table" then
		data.EquippedEquipment = {}
	end
	for instanceId, equipment in pairs(data.OwnedEquipment) do
		if type(equipment) == "table" and type(equipment.definitionId) == "string" then
			equipment.definitionId = EQUIPMENT_ID_ALIASES[equipment.definitionId] or equipment.definitionId
		end
		if type(equipment) == "table" and RETIRED_EQUIPMENT_IDS[equipment.definitionId] then
			-- Migration: remove retired content before equipped-slot normalization can retain it.
			data.OwnedEquipment[instanceId] = nil
		elseif type(instanceId) ~= "string" or type(equipment) ~= "table" or type(equipment.definitionId) ~= "string" or equipment.definitionId == "" then
			data.OwnedEquipment[instanceId] = nil
		else
			equipment.level = math.max(1, math.floor(tonumber(equipment.level) or 1))
			equipment.rarity = tostring(equipment.rarity or "Common")
			equipment.isTemporary = equipment.isTemporary == true
			equipment.expiresAt = tonumber(equipment.expiresAt)
			equipment.acquiredAt = tonumber(equipment.acquiredAt) or os.time()
			if type(equipment.pity) ~= "table" then
				equipment.pity = {}
			end
		end
	end
	-- Do not mutate EquippedEquipment while iterating it: legacy and numeric keys can
	-- represent the same slot, and pairs() does not define an order. Numeric keys take
	-- precedence over numeric-string aliases and then legacy slot names.
	local legacySlotNames = { "Core", "Module", "Charm" }
	local normalizedEquipped = {}
	for slot = 1, 3 do
		local candidateKeys = { slot, tostring(slot), legacySlotNames[slot] }
		for _, candidateKey in ipairs(candidateKeys) do
			local instanceId = data.EquippedEquipment[candidateKey]
			if type(instanceId) == "string" and data.OwnedEquipment[instanceId] ~= nil then
				normalizedEquipped[slot] = instanceId
				break
			end
		end
	end
	data.EquippedEquipment = normalizedEquipped
end

function PlayerDataService:_ensureProgress(data: { [string]: any })
	local progress = data.ProgressPoints
	if type(progress) ~= "table" then
		progress = {}
		data.ProgressPoints = progress
	end
	data.Level = math.max(1, math.floor(tonumber(data.Level) or 1))
	data.Coin = math.max(0, math.floor(tonumber(data.Coin) or 0))
	progress.TotalPoints = tonumber(progress.TotalPoints) or 0
	progress.RoundPoints = tonumber(progress.RoundPoints) or 0
	progress.WeeklyPoints = tonumber(progress.WeeklyPoints) or 0
	progress.WeeklyResetAt = tonumber(progress.WeeklyResetAt) or currentMondayStamp(os.time())
	local monday = currentMondayStamp(os.time())
	if progress.WeeklyResetAt < monday then
		if progress.WeeklyPoints > 0 then
			progress.PendingWeeklyReward = {
				WeekStart = progress.WeeklyResetAt,
				WeekEnd = progress.WeeklyResetAt + (7 * 24 * 60 * 60),
				Points = progress.WeeklyPoints,
			}
		end
		progress.WeeklyPoints = 0
		progress.WeeklyResetAt = monday
	end
end

function PlayerDataService:_ensureQuestData(data: { [string]: any }, currentDay: number)
	local questState = data.QuestState
	if type(questState) ~= "table" then
		questState = {}
		data.QuestState = questState
	end
	questState.DailyResetAt = tonumber(questState.DailyResetAt) or currentDay
	if questState.DailyResetAt < currentDay then
		questState.DailyResetAt = currentDay
		questState.Claimed = {}
		local metrics = questState.Metrics
		if type(metrics) == "table" then
			metrics.OnlineTime = 0
			metrics.CollectPoints = 0
			metrics.DealDamage = 0
			metrics.CollectFoodRarity = 0
		end
	end
	if type(questState.Metrics) ~= "table" then
		questState.Metrics = {}
	end
	if type(questState.Claimed) ~= "table" then
		questState.Claimed = {}
	end
end

function PlayerDataService:EnsureQuestData(player: Player, currentDay: number): { [string]: any }
	local data = self:UpdateData(player, function(existing)
		self:_ensureQuestData(existing, currentDay)
		return existing
	end)
	return data.QuestState
end

function PlayerDataService:IncrementQuestMetric(player: Player, metricName: string, amount: number): number
	local add = math.max(0, math.floor(amount))
	local updated = self:UpdateData(player, function(data)
		self:_ensureQuestData(data, 0)
		local metrics = data.QuestState.Metrics
		metrics[metricName] = math.max(0, math.floor(tonumber(metrics[metricName]) or 0)) + add
		return data
	end)
	return updated.QuestState.Metrics[metricName]
end

function PlayerDataService:SetQuestMetric(player: Player, metricName: string, value: number): number
	local normalized = math.max(0, math.floor(value))
	local updated = self:UpdateData(player, function(data)
		self:_ensureQuestData(data, 0)
		data.QuestState.Metrics[metricName] = normalized
		return data
	end)
	return updated.QuestState.Metrics[metricName]
end

function PlayerDataService:MarkQuestClaimed(player: Player, questId: string)
	self:UpdateData(player, function(data)
		self:_ensureQuestData(data, 0)
		data.QuestState.Claimed[questId] = true
		return data
	end)
end

function PlayerDataService:GrantReward(player: Player, reward: any, reason: string?)
	self:UpdateData(player, function(data)
		self:_ensureEquipmentData(data)
		local diamonds = tonumber(reward.Diamonds or reward.diamonds) or 0
		data.Diamonds += math.max(0, math.floor(diamonds))
		for _, itemReward in ipairs(reward.Items or reward.items or {}) do
			local itemId = tostring(itemReward.Id or itemReward.ItemId or itemReward.id or "")
			if itemId ~= "" then
				local quantity = math.max(1, math.floor(tonumber(itemReward.Quantity or itemReward.Amount or itemReward.quantity) or 1))
				data.OwnedItems[itemId] = math.max(0, math.floor(tonumber(data.OwnedItems[itemId]) or 0)) + quantity
			end
		end
		return data
	end)
	if self._context.EventBus then
		self._context.EventBus:Fire("PlayerRewardGranted", player, reward, reason)
	end
end

function PlayerDataService:GetDiamonds(player: Player): number
	local data = self:GetData(player)
	self:_ensureEquipmentData(data)
	return data.Diamonds
end

function PlayerDataService:SpendDiamonds(player: Player, amount: number, reason: string?): boolean
	local cost = math.max(0, math.floor(tonumber(amount) or 0))
	local spent = false
	self:UpdateData(player, function(data)
		self:_ensureEquipmentData(data)
		if data.Diamonds >= cost then
			data.Diamonds -= cost
			spent = true
		end
		return data
	end)
	if spent and self._context.EventBus then
		self._context.EventBus:Fire("DiamondsSpent", player, cost, reason)
	end
	return spent
end

function PlayerDataService:GetOwnedEquipment(player: Player): { [string]: any }
	local data = self:GetData(player)
	self:_ensureEquipmentData(data)
	return data.OwnedEquipment
end

function PlayerDataService:GetEquippedEquipment(player: Player): { [string]: any }
	local data = self:GetData(player)
	self:_ensureEquipmentData(data)
	return data.EquippedEquipment
end

function PlayerDataService:ConsumePendingWeeklyReward(player: Player): any?
	local consumed = nil
	self:UpdateData(player, function(data)
		self:_ensureProgress(data)
		local progress = data.ProgressPoints
		local pending = progress.PendingWeeklyReward
		if type(pending) == "table" and (tonumber(pending.WeekStart) or 0) > (tonumber(progress.LastWeeklyRewardAt) or 0) then
			consumed = pending
			progress.LastWeeklyRewardAt = pending.WeekStart
			progress.PendingWeeklyReward = nil
		end
		return data
	end)
	return consumed
end

function PlayerDataService:AddRoundProgressPoints(player: Player, amount: number): number
	local add = math.max(0, math.floor(amount))
	local updated = self:UpdateData(player, function(data)
		self:_ensureProgress(data)
		local progress = data.ProgressPoints
		progress.RoundPoints += add
		return data
	end)
	local roundPoints = updated.ProgressPoints.RoundPoints
	if self._context.EventBus then
		self._context.EventBus:Fire("ProgressPointsChanged", player, updated.ProgressPoints.TotalPoints, updated.ProgressPoints.WeeklyPoints, roundPoints)
	end
	return roundPoints
end

function PlayerDataService:ResetRoundProgressPoints(player: Player)
	self:UpdateData(player, function(data)
		self:_ensureProgress(data)
		data.ProgressPoints.RoundPoints = 0
		return data
	end)
	if self._context.EventBus then
		self._context.EventBus:Fire("ProgressPointsChanged", player, self:GetProgressPoints(player))
	end
end

function PlayerDataService:AddCoins(player: Player, amount: number): number
	local add = math.max(0, math.floor(amount))
	local updated = self:UpdateData(player, function(data)
		self:_ensureProgress(data)
		data.Coin += add
		return data
	end)
	return updated.Coin
end

function PlayerDataService:AddProgressPoints(player: Player, amount: number): (number, number)
	local add = math.max(0, math.floor(amount))
	local updated = self:UpdateData(player, function(data)
		self:_ensureProgress(data)
		local progress = data.ProgressPoints
		progress.TotalPoints += add
		progress.WeeklyPoints += add
		return data
	end)
	local progress = updated.ProgressPoints
	if self._context.EventBus then
		self._context.EventBus:Fire("ProgressPointsChanged", player, progress.TotalPoints, progress.WeeklyPoints)
	end
	return progress.TotalPoints, progress.WeeklyPoints
end

function PlayerDataService:GetProgressPoints(player: Player): (number, number)
	local data = self:GetData(player)
	self:_ensureProgress(data)
	return data.ProgressPoints.TotalPoints, data.ProgressPoints.WeeklyPoints
end

function PlayerDataService:GetProvider(): any
	return self._provider
end

function PlayerDataService:GetRoundProgressPoints(player: Player): number
	local data = self:GetData(player)
	self:_ensureProgress(data)
	return data.ProgressPoints.RoundPoints
end

return PlayerDataService
