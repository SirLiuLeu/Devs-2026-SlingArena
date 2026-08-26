--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)

local MockData = {}

-- This is the single schema for an unseeded mock player. Seeded profiles below are
-- deliberately richer fixtures and must not be used as the new-player fallback.
MockData.MOCK_SCHEMA_DEFAULTS = {
	Level = 1,
	Coin = 0,
	Diamonds = 0,
	OwnedItems = {},
	OwnedEquipment = {},
	EquippedEquipment = { [1] = nil, [2] = nil, [3] = nil },
	OwnedLaunchers = {
		default_normal_launcher = { definitionId = "NormalLauncher", star = 1, level = 1 },
	},
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
		Level = 12,
		Coin = 2500,
		Diamonds = 750,
		OwnedItems = { hp_potion = 8, exp_buff_x2 = 2, gacha_ticket = 5 },
		OwnedEquipment = {
			eq_alpha_PlasmaCannon = { definitionId = "PlasmaCannon", level = 1, rarity = (EquipmentConfig.GetById("PlasmaCannon") and EquipmentConfig.GetById("PlasmaCannon").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_SlowBlaster = { definitionId = "SlowBlaster", level = 1, rarity = (EquipmentConfig.GetById("SlowBlaster") and EquipmentConfig.GetById("SlowBlaster").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_ThunderHammer = { definitionId = "ThunderHammer", level = 1, rarity = (EquipmentConfig.GetById("ThunderHammer") and EquipmentConfig.GetById("ThunderHammer").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Medusa = { definitionId = "Medusa", level = 1, rarity = (EquipmentConfig.GetById("Medusa") and EquipmentConfig.GetById("Medusa").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_IceCrystal = { definitionId = "IceCrystal", level = 1, rarity = (EquipmentConfig.GetById("IceCrystal") and EquipmentConfig.GetById("IceCrystal").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_GhostFlame = { definitionId = "GhostFlame", level = 1, rarity = (EquipmentConfig.GetById("GhostFlame") and EquipmentConfig.GetById("GhostFlame").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Poison = { definitionId = "Poison", level = 1, rarity = (EquipmentConfig.GetById("Poison") and EquipmentConfig.GetById("Poison").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_HealthCore = { definitionId = "HealthCore", level = 1, rarity = (EquipmentConfig.GetById("HealthCore") and EquipmentConfig.GetById("HealthCore").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_PowerCore = { definitionId = "PowerCore", level = 1, rarity = (EquipmentConfig.GetById("PowerCore") and EquipmentConfig.GetById("PowerCore").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_Shield = { definitionId = "Shield", level = 1, rarity = (EquipmentConfig.GetById("Shield") and EquipmentConfig.GetById("Shield").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_BrainBoost = { definitionId = "BrainBoost", level = 1, rarity = (EquipmentConfig.GetById("BrainBoost") and EquipmentConfig.GetById("BrainBoost").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_TurboModule = { definitionId = "TurboModule", level = 1, rarity = (EquipmentConfig.GetById("TurboModule") and EquipmentConfig.GetById("TurboModule").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_LaunchBooster = { definitionId = "LaunchBooster", level = 1, rarity = (EquipmentConfig.GetById("LaunchBooster") and EquipmentConfig.GetById("LaunchBooster").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_TitanCore = { definitionId = "TitanCore", level = 1, rarity = (EquipmentConfig.GetById("TitanCore") and EquipmentConfig.GetById("TitanCore").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_QuickReload = { definitionId = "QuickReload", level = 1, rarity = (EquipmentConfig.GetById("QuickReload") and EquipmentConfig.GetById("QuickReload").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_ThornArmor = { definitionId = "ThornArmor", level = 1, rarity = (EquipmentConfig.GetById("ThornArmor") and EquipmentConfig.GetById("ThornArmor").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_RegenBooster = { definitionId = "RegenBooster", level = 1, rarity = (EquipmentConfig.GetById("RegenBooster") and EquipmentConfig.GetById("RegenBooster").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_ShadowCloak = { definitionId = "ShadowCloak", level = 1, rarity = (EquipmentConfig.GetById("ShadowCloak") and EquipmentConfig.GetById("ShadowCloak").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_SmokeBomb = { definitionId = "SmokeBomb", level = 1, rarity = (EquipmentConfig.GetById("SmokeBomb") and EquipmentConfig.GetById("SmokeBomb").rarity) or "Common", acquiredAt = 1786924800 },
			eq_alpha_MagnetCore = { definitionId = "MagnetCore", level = 1, rarity = (EquipmentConfig.GetById("MagnetCore") and EquipmentConfig.GetById("MagnetCore").rarity) or "Common", acquiredAt = 1786924800 },
		},
		EquippedEquipment = { [1] = "eq_alpha_Poison", [2] = "eq_alpha_GhostFlame", [3] = "eq_alpha_ThunderHammer" },
		OwnedLaunchers = {
			ln_alpha_normal = { definitionId = "NormalLauncher", star = 1, level = 2 },
			ln_alpha_fire = { definitionId = "FireLauncher", star = 3, level = 4, temporaryState = { skin = "TrialRed" } },
		},
		EquippedLauncherInstanceId = "ln_alpha_fire",
	},

	{
		UserId = -800002,
		Name = "MockPlayerBeta",
		DisplayName = "Mock Player Beta",
		Level = 28,
		Coin = 6400,
		Diamonds = 1400,
		OwnedItems = { hp_potion = 15, gacha_ticket = 12 },
		OwnedEquipment = {
			eq_beta_charm_medusa = { definitionId = "Medusa", level = 5, rarity = "Legendary", acquiredAt = 1786924800 },
			eq_beta_core_thunder = { definitionId = "ThunderHammer", level = 4, rarity = "Epic", acquiredAt = 1786924800 },
			eq_beta_temp_brain = { definitionId = "BrainBoost", level = 2, rarity = "Uncommon", isTemporary = true, expiresAt = 1787014800, acquiredAt = 1786924800 },
		},
		EquippedEquipment = { [1] = "eq_beta_core_thunder", [2] = "eq_beta_temp_brain", [3] = "eq_beta_charm_medusa" },
		OwnedLaunchers = {
			ln_beta_normal = { definitionId = "NormalLauncher", star = 1, level = 1 },
			ln_beta_petrify = { definitionId = "PetrifyLauncher", star = 4, level = 6 },
			ln_beta_vacuum = { definitionId = "VacuumLauncher", star = 2, level = 3 },
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
	return DeepCopy.Copy(MockData.MOCK_SCHEMA_DEFAULTS)
end

return MockData
