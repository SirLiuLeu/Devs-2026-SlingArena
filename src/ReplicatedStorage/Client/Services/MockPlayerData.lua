--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
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
		exp_buff_30 = 5,
		damage_buff_20 = 5,
		hp_buff_30 = 5,
		exp_card_500 = 5,
		luck_buff_clover = 5,
		bomb = 3,
		gift_box = 2,
	},
	OwnedLaunchers = (function()
		local launchers = {}
		for _, definitionId in ipairs(LauncherConfig.GetAllIds()) do
			for copyIndex = 1, 4 do
				local isDefault = definitionId == LauncherConfig.DefaultLauncherId and copyIndex == 1
				local instanceId = if isDefault then "default_normal_launcher"
					else string.format("mock_%s_%d", string.lower(definitionId), copyIndex)
				local definition = LauncherConfig.GetById(definitionId)
				table.insert(launchers, {
					instanceId = instanceId,
					definitionId = definitionId,
					id = definitionId,
					star = 1,
					level = copyIndex,
					equipped = isDefault,
					name = definition and definition.name or definitionId,
				})
			end
		end
		return launchers
	end)(),
	OwnedPets = {
		mock_Titan_1 = { abilityId = "Titan", level = 1, rarity = (PetsConfig.GetByAbilityId("Titan") and PetsConfig.GetByAbilityId("Titan").rarity) or "Common", acquiredAt = 1786924800 },
		mock_LastStand_1 = { abilityId = "LastStand", level = 1, rarity = (PetsConfig.GetByAbilityId("LastStand") and PetsConfig.GetByAbilityId("LastStand").rarity) or "Common", acquiredAt = 1786924800 },
		mock_LauncherBoost_1 = { abilityId = "LauncherBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("LauncherBoost") and PetsConfig.GetByAbilityId("LauncherBoost").rarity) or "Common", acquiredAt = 1786924800 },
		mock_Poison_1 = { abilityId = "Poison", level = 1, rarity = (PetsConfig.GetByAbilityId("Poison") and PetsConfig.GetByAbilityId("Poison").rarity) or "Common", acquiredAt = 1786924800 },
		mock_PetBaseBoost_1 = { abilityId = "PetBaseBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("PetBaseBoost") and PetsConfig.GetByAbilityId("PetBaseBoost").rarity) or "Common", acquiredAt = 1786924800 },
		mock_Burn_1 = { abilityId = "Burn", level = 1, rarity = (PetsConfig.GetByAbilityId("Burn") and PetsConfig.GetByAbilityId("Burn").rarity) or "Common", acquiredAt = 1786924800 },
		mock_Lifesteal_1 = { abilityId = "Lifesteal", level = 1, rarity = (PetsConfig.GetByAbilityId("Lifesteal") and PetsConfig.GetByAbilityId("Lifesteal").rarity) or "Common", acquiredAt = 1786924800 },
		mock_MaxHPBoost_1 = { abilityId = "MaxHPBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("MaxHPBoost") and PetsConfig.GetByAbilityId("MaxHPBoost").rarity) or "Common", acquiredAt = 1786924800 },
		mock_DamageBoost_1 = { abilityId = "DamageBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("DamageBoost") and PetsConfig.GetByAbilityId("DamageBoost").rarity) or "Common", acquiredAt = 1786924800 },
		mock_AbsorbShield_1 = { abilityId = "AbsorbShield", level = 1, rarity = (PetsConfig.GetByAbilityId("AbsorbShield") and PetsConfig.GetByAbilityId("AbsorbShield").rarity) or "Common", acquiredAt = 1786924800 },
		mock_ExpBonus_1 = { abilityId = "ExpBonus", level = 1, rarity = (PetsConfig.GetByAbilityId("ExpBonus") and PetsConfig.GetByAbilityId("ExpBonus").rarity) or "Common", acquiredAt = 1786924800 },
		mock_MoveSpeedBoost_1 = { abilityId = "MoveSpeedBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("MoveSpeedBoost") and PetsConfig.GetByAbilityId("MoveSpeedBoost").rarity) or "Common", acquiredAt = 1786924800 },
		mock_LaunchBooster_1 = { abilityId = "LaunchBooster", level = 1, rarity = (PetsConfig.GetByAbilityId("LaunchBooster") and PetsConfig.GetByAbilityId("LaunchBooster").rarity) or "Common", acquiredAt = 1786924800 },
		mock_FullForce_1 = { abilityId = "FullForce", level = 1, rarity = (PetsConfig.GetByAbilityId("FullForce") and PetsConfig.GetByAbilityId("FullForce").rarity) or "Common", acquiredAt = 1786924800 },
		mock_QuickReload_1 = { abilityId = "QuickReload", level = 1, rarity = (PetsConfig.GetByAbilityId("QuickReload") and PetsConfig.GetByAbilityId("QuickReload").rarity) or "Common", acquiredAt = 1786924800 },
		mock_ThornArmor_1 = { abilityId = "ThornArmor", level = 1, rarity = (PetsConfig.GetByAbilityId("ThornArmor") and PetsConfig.GetByAbilityId("ThornArmor").rarity) or "Common", acquiredAt = 1786924800 },
		mock_Regeneration_1 = { abilityId = "Regeneration", level = 1, rarity = (PetsConfig.GetByAbilityId("Regeneration") and PetsConfig.GetByAbilityId("Regeneration").rarity) or "Common", acquiredAt = 1786924800 },
		mock_IronBody_1 = { abilityId = "IronBody", level = 1, rarity = (PetsConfig.GetByAbilityId("IronBody") and PetsConfig.GetByAbilityId("IronBody").rarity) or "Common", acquiredAt = 1786924800 },
	},
	EquippedPets = { [1] = "mock_Lifesteal_1", [2] = "mock_Burn_1", [3] = "mock_LauncherBoost_1" },
	Equipped = {
		LauncherInstanceId = "default_normal_launcher",
		ActiveItems = {},
	},
	LauncherCapacity = 40,
}

local ITEM_ALIASES = {
	item_hp_potion = "hp_potion",
	item_buff_exp = "exp_buff_30",
	item_invisible = "damage_buff_20",
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
		OwnedPets = deepClone(MOCK_PLAYER_DATA.OwnedPets),
		EquippedPets = deepClone(MOCK_PLAYER_DATA.EquippedPets),
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
	if normalizedId == "exp_card_500" then
		MOCK_PLAYER_DATA.Exp += 500
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
		MockPlayerData.AddLauncher(itemId or "Normalduck", reason or "RewardLauncher")
	end
end

return MockPlayerData
