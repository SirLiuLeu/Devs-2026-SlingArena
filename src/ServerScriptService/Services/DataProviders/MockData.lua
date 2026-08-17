--!strict

local MockData = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

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
			eq_alpha_core_poison = { definitionId = "Poison", level = 3, rarity = "Rare", acquiredAt = 1786924800 },
			eq_alpha_module_fire = { definitionId = "GhostFlame", level = 2, rarity = "Epic", acquiredAt = 1786924800 },
			eq_alpha_temp_shield = { definitionId = "PowerCore", level = 1, rarity = "Common", isTemporary = true, expiresAt = 1787011200, acquiredAt = 1786924800 },
		},
		EquippedEquipment = { [1] = "eq_alpha_core_poison", [2] = "eq_alpha_module_fire" },
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
		},
		EquippedEquipment = { [1] = "eq_beta_core_thunder", [3] = "eq_beta_charm_medusa" },
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
			return deepCopy(profile)
		end
	end
	return nil
end

function MockData.GetDefaultPlayerProfile(): { [string]: any }
	return deepCopy(MockData.PlayerProfiles[1])
end

return MockData
