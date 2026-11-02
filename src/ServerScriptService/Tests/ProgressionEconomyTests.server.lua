--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local PetAbilityProgressionConfig = require(ReplicatedStorage.Shared.Config.PetAbilityProgressionConfig)
local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local LauncherStatResolver = require(ReplicatedStorage.Shared.Utils.LauncherStatResolver)
local PetStatResolver = require(ReplicatedStorage.Shared.Utils.PetStatResolver)
local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)

local function assertEqual(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(string.format("%s | expected=%s actual=%s", message, tostring(expected), tostring(actual)))
	end
end

local function assertNear(actual: number, expected: number, message: string)
	if math.abs(actual - expected) > 0.0001 then
		error(string.format("%s | expected=%.4f actual=%.4f", message, expected, actual))
	end
end

local function runTest(name: string, testFn: () -> ())
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[ProgressionEconomyTests] PASS %s", name))
	else
		warn(string.format("[ProgressionEconomyTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

runTest("Pet_Level_Cap_And_Piecewise_Stats", function()
	assertEqual(PetsConfig.MaxLevel, 50, "Pet catalog max level")
	assertEqual(PetsUpgradeConfig.NormalizeLevel(99), 50, "Pet level normalization")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 1), 100, "Level 1 baseline")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 20), 195, "Level 20 +5% growth")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 21), 198, "Level 21 starts +3% growth")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 50), 285, "Level 50 final growth")
end)

runTest("Pet_Linear_Cost_And_Rarity_Multipliers", function()
	assertEqual(PetsUpgradeConfig.GetUpgradeCost(1, "Common"), 50, "Common level 1 cost")
	assertEqual(PetsUpgradeConfig.GetUpgradeCost(49, "Common"), 2450, "Common level 49 cost")
	assertEqual(PetsUpgradeConfig.GetUpgradeCost(1, "Rare"), 63, "Rare rarity multiplier")
	assertEqual(PetsUpgradeConfig.GetUpgradeCost(50, "Common"), 0, "Max-level upgrade cost")
	local totalCommon = 0
	for level = 1, 49 do
		totalCommon += PetsUpgradeConfig.GetUpgradeCost(level, "Common")
	end
	assertEqual(totalCommon, 61250, "Total Common cost from level 1 to 50")
end)

runTest("Pet_Abilities_Stop_At_Level_20", function()
	local level20 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 20)
	local level50 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 50)
	assertEqual(level50.damage, level20.damage, "Plasma Cannon damage cap")
	local titan20 = PetAbilityProgressionConfig.GetParams("Titan", 20)
	local titan50 = PetAbilityProgressionConfig.GetParams("Titan", 50)
	assertEqual(titan50.weightMultiplier, titan20.weightMultiplier, "Titan weight cap")
	assertEqual(titan50.hitboxMultiplier, titan20.hitboxMultiplier, "Titan hitbox cap")
end)

runTest("UpgradePet_Remote_Accepts_Levels_Through_50", function()
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 50), true, "Level 50 validation")
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 51), false, "Level 51 rejection")
end)

runTest("Food_Diamond_Drop_Rates_Are_Fourfold", function()
	assertNear(FoodConfig.Foods.UncommonIce.DiamondRate, 0.20, "Uncommon drop rate")
	assertNear(FoodConfig.Foods.RareAmber.DiamondRate, 0.32, "Rare drop rate")
	assertNear(FoodConfig.Foods.EpicViolet.DiamondRate, 0.48, "Epic drop rate")
	assertNear(FoodConfig.Foods.LegendaryGold.DiamondRate, 0.72, "Legendary drop rate")
end)

runTest("RoundLevel_Scales_Only_Launcher_Base_HP_And_Damage", function()
	local base = LauncherStatResolver.Resolve("Normalduck", 1, 1, "Common", 1)
	local roundLevelFive = LauncherStatResolver.Resolve("Normalduck", 1, 1, "Common", 5)
	assertNear(roundLevelFive.maxHP / base.maxHP, 1.04, "RoundLevel HP multiplier")
	assertNear(roundLevelFive.baseDamage / base.baseDamage, 1.04, "RoundLevel Damage multiplier")
	assertEqual(roundLevelFive.regen, base.regen, "RoundLevel does not scale regeneration")

	local withPet = PetStatResolver.Apply(roundLevelFive, {
		{ baseStats = { maxHP = 200, baseDamage = 20 } },
	})
	assertNear(withPet.maxHP - roundLevelFive.maxHP, 200, "Pet HP is added after RoundLevel multiplier")
	assertNear(withPet.baseDamage - roundLevelFive.baseDamage, 20, "Pet Damage is added after RoundLevel multiplier")
end)

runTest("Round_And_Kill_Diamond_Reward_Tuning", function()
	assertEqual(RankConfig.ScoreSettings.KillPlayer.DiamondReward, 40, "First eligible kill reward")
	assertEqual(RankConfig.RoundDiamondRewards.Participation, 300, "Participation reward")
	assertEqual(RankConfig.RoundDiamondRewards.MaxScoreBonus, 400, "Score reward cap")
	assertEqual(RankConfig.RoundDiamondRewards.RankBonuses[1], 300, "First place reward")
end)

print("[ProgressionEconomyTests] all checks passed")
