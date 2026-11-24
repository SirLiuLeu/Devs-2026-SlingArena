--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)

local MockData = {}

-- This is the single schema for an unseeded mock player. Seeded profiles below are
-- deliberately richer fixtures and must not be used as the new-player fallback.

local function buildAllPetInventory(prefix: string): { [string]: any }
	local inventory = {}
	for _, abilityId in ipairs(PetsConfig.GetAllAbilityIds()) do
		local definition = PetsConfig.GetByAbilityId(abilityId)
		inventory[prefix .. abilityId] = {
			abilityId = abilityId,
			level = 1,
			rarity = (definition and definition.rarity) or "Common",
			acquiredAt = os.time(),
		}
	end
	return inventory
end

local function buildMockLauncherInventory(): { [string]: any }
	local inventory = {}
	for _, definitionId in ipairs(LauncherConfig.GetAllIds()) do
		for copyIndex = 1, 4 do
			local isDefault = definitionId == LauncherConfig.DefaultLauncherId and copyIndex == 1
			local instanceId = if isDefault then "default_normal_launcher"
				else string.format("mock_%s_%d", string.lower(definitionId), copyIndex)
			inventory[instanceId] = {
				definitionId = definitionId,
				star = 1,
				level = copyIndex,
				rarity = "Common",
				acquiredAt = os.time(),
			}
		end
	end
	return inventory
end

MockData.MOCK_SCHEMA_DEFAULTS = {
	Coin = 0,
	Diamonds = 0,
	OwnedItems = { bomb = 3, gift_box = 1, hp_potion = 5, exp_buff_30 = 5, damage_buff_20 = 5, hp_buff_30 = 5, exp_card_500 = 5, luck_buff_clover = 5 },
	OnlineRewardState = { SchemaVersion = 1, CycleId = 1, RewardSetId = "", ElapsedSeconds = 0, ClaimedSlots = {}, LastSessionEndAt = 0, LastOnlineAt = 0 },
	DailyLoginState = { SchemaVersion = 1, CycleId = 1, CurrentDay = 1, LastClaimDayKey = 0, SelectedBundleIds = {} },
	OwnedPets = {},
	EquippedPets = { [1] = nil, [2] = nil, [3] = nil },
	OwnedLaunchers = buildMockLauncherInventory(),
	EquippedLauncherInstanceId = "default_normal_launcher",
	ProgressPoints = {
		TotalPoints = 0,
		RoundPoints = 0,
		WeeklyPoints = 0,
	},
}

MockData.PlayerProfiles = {
	{
		UserId = -800001,
		Name = "MockPlayerAlpha",
		DisplayName = "Mock Player Alpha",
		Coin = 2500,
		Diamonds = 750,
		OwnedItems = { bomb = 3, gift_box = 1, hp_potion = 8, exp_buff_30 = 5, damage_buff_20 = 5, hp_buff_30 = 5, exp_card_500 = 5, luck_buff_clover = 5 },
		OwnedPets = {
			eq_alpha_Titan = { abilityId = "Titan", level = 1, rarity = (PetsConfig.GetByAbilityId("Titan") and PetsConfig.GetByAbilityId("Titan").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_LastStand = { abilityId = "LastStand", level = 1, rarity = (PetsConfig.GetByAbilityId("LastStand") and PetsConfig.GetByAbilityId("LastStand").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_LauncherBoost = { abilityId = "LauncherBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("LauncherBoost") and PetsConfig.GetByAbilityId("LauncherBoost").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Lifesteal = { abilityId = "Poison", level = 1, rarity = (PetsConfig.GetByAbilityId("Poison") and PetsConfig.GetByAbilityId("Poison").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_PetBaseBoost = { abilityId = "PetBaseBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("PetBaseBoost") and PetsConfig.GetByAbilityId("PetBaseBoost").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Burn = { abilityId = "Burn", level = 1, rarity = (PetsConfig.GetByAbilityId("Burn") and PetsConfig.GetByAbilityId("Burn").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Lifesteal = { abilityId = "Poison", level = 1, rarity = (PetsConfig.GetByAbilityId("Poison") and PetsConfig.GetByAbilityId("Poison").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_MaxHPBoost = { abilityId = "MaxHPBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("MaxHPBoost") and PetsConfig.GetByAbilityId("MaxHPBoost").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_DamageBoost = { abilityId = "DamageBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("DamageBoost") and PetsConfig.GetByAbilityId("DamageBoost").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_AbsorbShield = { abilityId = "AbsorbShield", level = 1, rarity = (PetsConfig.GetByAbilityId("AbsorbShield") and PetsConfig.GetByAbilityId("AbsorbShield").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_ExpBonus = { abilityId = "ExpBonus", level = 1, rarity = (PetsConfig.GetByAbilityId("ExpBonus") and PetsConfig.GetByAbilityId("ExpBonus").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_MoveSpeedBoost = { abilityId = "MoveSpeedBoost", level = 1, rarity = (PetsConfig.GetByAbilityId("MoveSpeedBoost") and PetsConfig.GetByAbilityId("MoveSpeedBoost").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_LaunchBooster = { abilityId = "LaunchBooster", level = 1, rarity = (PetsConfig.GetByAbilityId("LaunchBooster") and PetsConfig.GetByAbilityId("LaunchBooster").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_FullForce = { abilityId = "FullForce", level = 1, rarity = (PetsConfig.GetByAbilityId("FullForce") and PetsConfig.GetByAbilityId("FullForce").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_QuickReload = { abilityId = "QuickReload", level = 1, rarity = (PetsConfig.GetByAbilityId("QuickReload") and PetsConfig.GetByAbilityId("QuickReload").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_ThornArmor = { abilityId = "ThornArmor", level = 1, rarity = (PetsConfig.GetByAbilityId("ThornArmor") and PetsConfig.GetByAbilityId("ThornArmor").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Regeneration = { abilityId = "Regeneration", level = 1, rarity = (PetsConfig.GetByAbilityId("Regeneration") and PetsConfig.GetByAbilityId("Regeneration").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_IdleStealth = { abilityId = "IdleStealth", level = 1, rarity = (PetsConfig.GetByAbilityId("IdleStealth") and PetsConfig.GetByAbilityId("IdleStealth").rarity) or "Common", acquiredAt = 1786924800 },
		},
		EquippedPets = { [1] = "eq_alpha_Lifesteal", [2] = "eq_alpha_Burn", [3] = "eq_alpha_LauncherBoost" },
		OwnedLaunchers = {
			ln_alpha_normal = { definitionId = "Normalduck", star = 1, level = 2 },
			ln_alpha_fire = { definitionId = "Drakeduck", star = 3, level = 4, temporaryState = { skin = "TrialRed" } },
		},
		EquippedLauncherInstanceId = "ln_alpha_fire",
	},

	{
		UserId = -800002,
		Name = "MockPlayerBeta",
		DisplayName = "Mock Player Beta",
		Coin = 6400,
		Diamonds = 1400,
		OwnedItems = { bomb = 3, gift_box = 1, hp_potion = 15, exp_buff_30 = 5, damage_buff_20 = 5, hp_buff_30 = 5, exp_card_500 = 5, luck_buff_clover = 5 },
		OwnedPets = {
			eq_beta_charm_medusa = { definitionId = "Medusa", level = 5, rarity = "Legendary", acquiredAt = 1786924800 },
			eq_beta_core_thunder = { definitionId = "ThunderHammer", level = 4, rarity = "Epic", acquiredAt = 1786924800 },
			eq_beta_brain = { definitionId = "BrainBoost", level = 2, rarity = "Uncommon", acquiredAt = 1786924800 },
		},
		EquippedPets = { [1] = "eq_beta_core_thunder", [2] = "eq_beta_brain", [3] = "eq_beta_charm_medusa" },
		OwnedLaunchers = {
			ln_beta_normal = { definitionId = "Normalduck", star = 1, level = 1 },
			ln_beta_petrify = { definitionId = "Shielduck", star = 4, level = 6 },
			ln_beta_vacuum = { definitionId = "Witchduck", star = 2, level = 3 },
		},
		EquippedLauncherInstanceId = "ln_beta_petrify",
	},
}

function MockData.GetProfileByUserId(userId: number): { [string]: any }?
	for _, profile in ipairs(MockData.PlayerProfiles) do
		if profile.UserId == userId then
			return DeepCopy.Copy(profile)
		end
	end
	return nil
end

function MockData.GetDefaultPlayerProfile(): { [string]: any }
	local profile = DeepCopy.Copy(MockData.MOCK_SCHEMA_DEFAULTS)
	profile.OwnedPets = buildAllPetInventory("starter_pet_")
	return profile
end

return MockData
