--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)

local MockPlayerData = {}

export type SlingEntry = {
	instanceId: string,
	definitionId: string,
	id: string,
	star: number,
	level: number,
	equipped: boolean,
	name: string?,
	icon: string?,
	stats: any?,
}

local changedEvent = Instance.new("BindableEvent")

local MOCK_PLAYER_DATA = {
	Diamonds = 300,
	Exp = 0,
	OwnedItems = {
		hp_potion = 25,
		exp_buff_x2 = 25,
		gacha_ticket = 100,
	},
	OwnedSlings = {
		{
			instanceId = "mock_NormalSling_1",
			definitionId = "NormalSling",
			id = "NormalSling",
			star = 1,
			level = 1,
			equipped = true,
		},
	},
	Equipped = {
		SlingInstanceId = "mock_NormalSling_1",
		ActiveItems = {},
	},
	SlingCapacity = 40,
}

local ITEM_ALIASES = {
	item_hp_potion = "hp_potion",
	item_buff_exp = "exp_buff_x2",
	item_size_up = "regen_boost",
	item_speed_boost = "shield_tonic",
	item_invisible = "DamagePotion",
}

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, nested in pairs(value) do
		result[key] = deepClone(nested)
	end
	return result
end

local function normalizeItemId(itemId: string): string
	return ITEM_ALIASES[itemId] or itemId
end

local function findSlingIndex(instanceOrDefinitionId: string): number?
	for index, sling in ipairs(MOCK_PLAYER_DATA.OwnedSlings) do
		if sling.instanceId == instanceOrDefinitionId or sling.definitionId == instanceOrDefinitionId or sling.id == instanceOrDefinitionId then
			return index
		end
	end
	return nil
end

local function makeSling(definitionId: string): SlingEntry
	local definition = SlingConfig.GetById(definitionId)
	return {
		instanceId = string.format("mock_%s_%s", definitionId, HttpService:GenerateGUID(false)),
		definitionId = definitionId,
		id = definitionId,
		star = 1,
		level = 1,
		equipped = false,
		name = definition and definition.name or definitionId,
		icon = definition and definition.iconId or "rbxassetid://0",
		stats = definition and definition.stats and deepClone(definition.stats) or nil,
	}
end

local function emitChanged(reason: string?)
	changedEvent:Fire(MockPlayerData.GetPlayerData(), reason)
end

function MockPlayerData.BindChanged(callback: (any, string?) -> ())
	return changedEvent.Event:Connect(callback)
end

function MockPlayerData.GetPlayerData()
	return deepClone(MOCK_PLAYER_DATA)
end

function MockPlayerData.GetInventoryState()
	return {
		OwnedItems = deepClone(MOCK_PLAYER_DATA.OwnedItems),
		OwnedSlings = deepClone(MOCK_PLAYER_DATA.OwnedSlings),
		EquippedSlingInstanceId = MOCK_PLAYER_DATA.Equipped.SlingInstanceId,
		SlingCapacity = MOCK_PLAYER_DATA.SlingCapacity,
	}
end

function MockPlayerData.AddDiamonds(amount: number, reason: string?): number
	MOCK_PLAYER_DATA.Diamonds = math.max(0, MOCK_PLAYER_DATA.Diamonds + math.floor(amount))
	emitChanged(reason or "DiamondsChanged")
	return MOCK_PLAYER_DATA.Diamonds
end

function MockPlayerData.SpendDiamonds(amount: number, reason: string?): boolean
	local cost = math.max(0, math.floor(amount))
	if MOCK_PLAYER_DATA.Diamonds < cost then
		return false
	end
	MOCK_PLAYER_DATA.Diamonds -= cost
	emitChanged(reason or "DiamondsSpent")
	return true
end

function MockPlayerData.AddExp(amount: number, reason: string?): number
	MOCK_PLAYER_DATA.Exp = math.max(0, MOCK_PLAYER_DATA.Exp + math.floor(amount))
	emitChanged(reason or "ExpChanged")
	return MOCK_PLAYER_DATA.Exp
end

function MockPlayerData.AddItem(itemId: string, quantity: number?, reason: string?): string
	local normalizedId = normalizeItemId(itemId)
	local amount = math.max(1, math.floor(quantity or 1))
	MOCK_PLAYER_DATA.OwnedItems[normalizedId] = (MOCK_PLAYER_DATA.OwnedItems[normalizedId] or 0) + amount
	emitChanged(reason or "ItemAdded")
	return normalizedId
end

function MockPlayerData.UseItem(itemId: string, reason: string?): (boolean, string)
	local normalizedId = normalizeItemId(itemId)
	local quantity = MOCK_PLAYER_DATA.OwnedItems[normalizedId] or 0
	if quantity <= 0 then
		return false, "ITEM_NOT_OWNED"
	end
	MOCK_PLAYER_DATA.OwnedItems[normalizedId] = quantity - 1
	if MOCK_PLAYER_DATA.OwnedItems[normalizedId] <= 0 then
		MOCK_PLAYER_DATA.OwnedItems[normalizedId] = nil
	end
	if normalizedId == "exp_buff_x2" then
		MOCK_PLAYER_DATA.Exp += 100
	end
	emitChanged(reason or "ItemUsed")
	local definition = ItemConfig.GetById(normalizedId)
	return true, if definition then string.format("Used %s", definition.name) else string.format("Used %s", normalizedId)
end

function MockPlayerData.AddSling(definitionId: string, reason: string?): SlingEntry
	local existingIndex = findSlingIndex(definitionId)
	if existingIndex then
		MOCK_PLAYER_DATA.OwnedSlings[existingIndex].level += 1
		emitChanged(reason or "SlingUpgraded")
		return deepClone(MOCK_PLAYER_DATA.OwnedSlings[existingIndex])
	end
	local sling = makeSling(definitionId)
	table.insert(MOCK_PLAYER_DATA.OwnedSlings, sling)
	if #MOCK_PLAYER_DATA.OwnedSlings == 1 then
		MockPlayerData.EquipSling(sling.instanceId, reason or "SlingAdded")
	else
		emitChanged(reason or "SlingAdded")
	end
	return deepClone(sling)
end

function MockPlayerData.EquipSling(instanceOrDefinitionId: string, reason: string?): boolean
	local index = findSlingIndex(instanceOrDefinitionId)
	if not index then
		return false
	end
	for _, sling in ipairs(MOCK_PLAYER_DATA.OwnedSlings) do
		sling.equipped = false
	end
	local equipped = MOCK_PLAYER_DATA.OwnedSlings[index]
	equipped.equipped = true
	MOCK_PLAYER_DATA.Equipped.SlingInstanceId = equipped.instanceId
	emitChanged(reason or "SlingEquipped")
	return true
end

function MockPlayerData.GrantReward(rewardType: string, amount: number?, itemId: string?, reason: string?)
	local normalizedType = string.lower(rewardType)
	if normalizedType == "exp" then
		MockPlayerData.AddExp(amount or 0, reason or "RewardExp")
	elseif normalizedType == "diamond" or normalizedType == "dinamond" or normalizedType == "diamonds" then
		MockPlayerData.AddDiamonds(amount or 0, reason or "RewardDiamonds")
	elseif normalizedType == "item" then
		MockPlayerData.AddItem(itemId or "hp_potion", amount or 1, reason or "RewardItem")
	elseif normalizedType == "sling" or normalizedType == "launcher" then
		MockPlayerData.AddSling(itemId or "NormalSling", reason or "RewardSling")
	end
end

return MockPlayerData
