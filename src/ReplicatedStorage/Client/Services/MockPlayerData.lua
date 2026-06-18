--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)

local MockPlayerData = {}

export type LauncherEntry = {
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
	Level = LevelConfig.StartingLevel,
	Exp = LevelConfig.StartingExp,
	OwnedItems = {
		hp_potion = 25,
		exp_buff_x2 = 25,
		gacha_ticket = 100,
	},
	OwnedLaunchers = {
		{
			instanceId = "mock_NormalLauncher_1",
			definitionId = "NormalLauncher",
			id = "NormalLauncher",
			star = 1,
			level = 1,
			equipped = true,
		},
	},
	Equipped = {
		LauncherInstanceId = "mock_NormalLauncher_1",
		ActiveItems = {},
	},
	LauncherCapacity = 40,
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

local function findLauncherIndex(instanceOrDefinitionId: string): number?
	for index, launcher in ipairs(MOCK_PLAYER_DATA.OwnedLaunchers) do
		if launcher.instanceId == instanceOrDefinitionId or launcher.definitionId == instanceOrDefinitionId or launcher.id == instanceOrDefinitionId then
			return index
		end
	end
	return nil
end

local function makeLauncher(definitionId: string): LauncherEntry
	local definition = LauncherConfig.GetById(definitionId)
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
		OwnedLaunchers = deepClone(MOCK_PLAYER_DATA.OwnedLaunchers),
		EquippedLauncherInstanceId = MOCK_PLAYER_DATA.Equipped.LauncherInstanceId,
		LauncherCapacity = MOCK_PLAYER_DATA.LauncherCapacity,
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

local function applyExpOverflow()
	MOCK_PLAYER_DATA.Level = math.max(1, math.floor(MOCK_PLAYER_DATA.Level or LevelConfig.StartingLevel))
	MOCK_PLAYER_DATA.Exp = math.max(0, math.floor(MOCK_PLAYER_DATA.Exp or LevelConfig.StartingExp))

	while MOCK_PLAYER_DATA.Level < LevelConfig.MaxLevel do
		local requiredExp = math.max(1, math.floor(LevelConfig.RequiredExp(MOCK_PLAYER_DATA.Level)))
		if MOCK_PLAYER_DATA.Exp < requiredExp then
			break
		end
		MOCK_PLAYER_DATA.Exp -= requiredExp
		MOCK_PLAYER_DATA.Level += 1
	end
end

function MockPlayerData.SetProgress(level: number?, exp: number?, reason: string?, shouldEmit: boolean?)
	if level ~= nil then
		MOCK_PLAYER_DATA.Level = math.max(1, math.floor(level))
	end
	if exp ~= nil then
		MOCK_PLAYER_DATA.Exp = math.max(0, math.floor(exp))
	end
	applyExpOverflow()
	if shouldEmit ~= false then
		emitChanged(reason or "ProgressChanged")
	end
end

function MockPlayerData.AddExp(amount: number, reason: string?): number
	MOCK_PLAYER_DATA.Exp = math.max(0, math.floor((MOCK_PLAYER_DATA.Exp or 0) + math.floor(amount)))
	applyExpOverflow()
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

function MockPlayerData.AddLauncher(definitionId: string, reason: string?): LauncherEntry
	local existingIndex = findLauncherIndex(definitionId)
	if existingIndex then
		MOCK_PLAYER_DATA.OwnedLaunchers[existingIndex].level += 1
		emitChanged(reason or "LauncherUpgraded")
		return deepClone(MOCK_PLAYER_DATA.OwnedLaunchers[existingIndex])
	end
	local launcher = makeLauncher(definitionId)
	table.insert(MOCK_PLAYER_DATA.OwnedLaunchers, launcher)
	if #MOCK_PLAYER_DATA.OwnedLaunchers == 1 then
		MockPlayerData.EquipLauncher(launcher.instanceId, reason or "LauncherAdded")
	else
		emitChanged(reason or "LauncherAdded")
	end
	return deepClone(launcher)
end

function MockPlayerData.EquipLauncher(instanceOrDefinitionId: string, reason: string?): boolean
	local index = findLauncherIndex(instanceOrDefinitionId)
	if not index then
		return false
	end
	for _, launcher in ipairs(MOCK_PLAYER_DATA.OwnedLaunchers) do
		launcher.equipped = false
	end
	local equipped = MOCK_PLAYER_DATA.OwnedLaunchers[index]
	equipped.equipped = true
	MOCK_PLAYER_DATA.Equipped.LauncherInstanceId = equipped.instanceId
	emitChanged(reason or "LauncherEquipped")
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
	elseif normalizedType == "launcher" or normalizedType == "launcher" then
		MockPlayerData.AddLauncher(itemId or "NormalLauncher", reason or "RewardLauncher")
	end
end

return MockPlayerData
