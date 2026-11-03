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

runTest("Pet_Level_Cap_And_Linear_Stats", function()
	assertEqual(PetsConfig.MaxLevel, 50, "Pet catalog max level")
	assertEqual(PetsUpgradeConfig.NormalizeLevel(99), 50, "Pet level normalization")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 1), 100, "Level 1 baseline")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 20), 195, "Level 20 +5% growth")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 21), 200, "Level 21 remains +5% growth")
	assertNear(PetsUpgradeConfig.GetStatAtLevel(100, 50), 345, "Level 50 reaches 3.45x")
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

runTest("Pet_Ability_Milestones_Reach_80_And_100_Percent", function()
	local plasma1 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 1)
	local plasma4 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 4)
	local plasma5 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 5)
	local plasma20 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 20)
	local plasma21 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 21)
	local plasma25 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 25)
	local plasma50 = PetAbilityProgressionConfig.GetParams("PlasmaCannon", 50)
	assertNear(plasma1.damage, 700, "Plasma Cannon level 1")
	assertNear(plasma4.damage, plasma1.damage, "Ability stays unchanged before milestone")
	assertNear(plasma5.damage, 800, "Legacy level-5 value retained")
	assertNear(plasma20.damage, 1100, "Legacy level-20 value retained")
	assertNear(plasma21.damage, plasma20.damage, "Ability does not improve between milestones")
	assertNear(plasma25.damage, 1116.6666667, "Level 25 adds one sixth of remaining 20%")
	assertNear(plasma50.damage, 1200, "Level 50 extended target")
	assertNear(plasma20.cooldown, 10, "Cooldown remains unchanged")
	assertNear(plasma5.projectileSpeed, 60, "Existing Plasma speed unlock remains")

	local shield20 = PetAbilityProgressionConfig.GetParams("Shield", 20)
	local shield50 = PetAbilityProgressionConfig.GetParams("Shield", 50)
	assertNear(shield20.damageMultiplier, 0.60, "Legacy Shield level-20 value retained")
	assertNear(shield50.damageMultiplier, 0.55, "Shield level-50 target")

	local titan20 = PetAbilityProgressionConfig.GetParams("Titan", 20)
	local titan50 = PetAbilityProgressionConfig.GetParams("Titan", 50)
	assertNear(titan20.weightMultiplier, 1.29, "Legacy Titan level-20 weight retained")
	assertNear(titan20.hitboxMultiplier, 1.38, "Legacy Titan level-20 hitbox retained")
	assertNear(titan50.weightMultiplier, 1.3625, "Titan weight level-50 target")
	assertNear(titan50.hitboxMultiplier, 1.475, "Titan hitbox level-50 target")
	assertNear(titan50.incomingKnockbackMultiplier, 0.6625, "Titan incoming knockback target")

	local slowBlaster5 = PetAbilityProgressionConfig.GetParams("SlowBlaster", 5)
	assertNear(slowBlaster5.projectileSpeed, 15, "SlowBlaster level-5 speed unlock")
	assertNear(PetAbilityProgressionConfig.GetParams("SlowBlaster", 20).slowDuration, 5, "Legacy SlowBlaster level-20 duration retained")
	assertNear(PetAbilityProgressionConfig.GetParams("SlowBlaster", 50).slowDuration, 5.5, "SlowBlaster level-50 duration target")
	assertNear(PetAbilityProgressionConfig.GetParams("Slow", 50).collisionExtraDuration, 5.5, "Slow level-50 duration target")
	assertNear(PetAbilityProgressionConfig.GetParams("ExpBonus", 20).expBonus, 0.50, "BrainBoost level-20 EXP bonus")
	assertNear(PetAbilityProgressionConfig.GetParams("ExpBonus", 50).expBonus, 0.55, "BrainBoost level-50 EXP bonus")
	assertNear(PetAbilityProgressionConfig.GetParams("Regeneration", 50).healAmount, 1250, "Regeneration level-50 heal target")
end)

runTest("UpgradePet_Remote_Accepts_Levels_Through_50", function()
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 50), true, "Level 50 validation")
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 51), false, "Level 51 rejection")
end)

runTest("FoodSpawn_Area_Density_And_Gaps", function()
	assertEqual(FoodConfig.GetSpawnCountForArea(100 * 100), 10, "100x100 FoodSpawn target count")
	assertEqual(FoodConfig.GetSpawnCountForArea(50 * 50), 2, "50x50 FoodSpawn target count")
	assertEqual(FoodConfig.GetSpawnCountForArea(500 * 500), 20, "FoodSpawn count cap")
	assertEqual(FoodConfig.HpFoodMinNoOverlapDistance, 4, "HP-HP edge gap")
	assertEqual(FoodConfig.MinNoOverlapDistance, 3, "Common and mixed Hitbox gap")
end)

runTest("Food_Diamond_Drop_Rates_Are_Fourfold", function()
	assertNear(FoodConfig.Foods.UncommonIce.DiamondRate, 0.20, "Uncommon drop rate")
	assertNear(FoodConfig.Foods.RareAmber.DiamondRate, 0.32, "Rare drop rate")
	assertNear(FoodConfig.Foods.EpicViolet.DiamondRate, 0.48, "Epic drop rate")
	assertNear(FoodConfig.Foods.LegendaryGold.DiamondRate, 0.72, "Legendary drop rate")
end)

runTest("Player_Level_Scales_Only_Launcher_Base_HP_And_Damage", function()
	local base = LauncherStatResolver.Resolve("Normalduck", 1, 1, "Common", 1)
	local playerLevelFive = LauncherStatResolver.Resolve("Normalduck", 1, 1, "Common", 5)
	assertNear(playerLevelFive.maxHP / base.maxHP, 1.04, "Player Level HP multiplier")
	assertNear(playerLevelFive.baseDamage / base.baseDamage, 1.04, "Player Level Damage multiplier")
	assertEqual(playerLevelFive.regen, base.regen, "Player Level does not scale regeneration")

	local withPet = PetStatResolver.Apply(playerLevelFive, {
		{ baseStats = { maxHP = 200, baseDamage = 20 }, abilityParams = {} },
	})
	assertNear(withPet.maxHP - playerLevelFive.maxHP, 200, "Pet HP is added after Player Level multiplier")
	assertNear(withPet.baseDamage - playerLevelFive.baseDamage, 20, "Pet Damage is added after Player Level multiplier")
end)

runTest("Pet_Definition_StatModifiers_Apply_To_Resolved_Stats", function()
	local resolved = PetStatResolver.Apply(
		{ maxHP = 100, baseDamage = 100, damageMultiplier = 1, launchSpeed = 40, moveSpeed = 14, reflectDamage = 0.1, expBonus = 0 },
		{
			{ baseStats = {}, abilityParams = {}, definition = { statModifiers = { Add = { maxHP = 5000 }, Multiply = {} } } },
			{ baseStats = {}, abilityParams = {}, definition = { statModifiers = { Add = { baseDamage = 500 }, Multiply = { damageMultiplier = 1.05 } } } },
			{ baseStats = {}, abilityParams = {}, definition = { statModifiers = { Add = {}, Multiply = { launchSpeed = 1.2 } } } },
			{ baseStats = {}, abilityParams = {}, definition = { statModifiers = { Add = { launchCooldown = -1 }, Multiply = {} } } },
		}
	)
	assertNear(resolved.maxHP, 5100, "HealthCore adds maximum HP")
	assertNear(resolved.baseDamage, 600, "PowerCore adds base damage")
	assertNear(resolved.damageMultiplier, 1.05, "ThunderHammer damage multiplier applies")
	assertNear(resolved.launchSpeed, 48, "LaunchBooster launch-speed multiplier applies")
	assertNear(resolved.launchCooldown, -1, "QuickReload applies a one-second recovery reduction")

	local mixedProgressions = {
		{ baseStats = {}, abilityParams = {}, definition = { statModifiers = { Add = { moveSpeed = 10 }, Multiply = {} } } },
		{ baseStats = {}, abilityParams = {}, definition = { statModifiers = { Add = {}, Multiply = { moveSpeed = 1.2 } } } },
	}
	local forward = PetStatResolver.Apply({ moveSpeed = 14 }, mixedProgressions)
	local reverse = PetStatResolver.Apply({ moveSpeed = 14 }, { mixedProgressions[2], mixedProgressions[1] })
	assertNear(forward.moveSpeed, 28.8, "Additive and multiplicative Pet modifiers combine consistently")
	assertNear(reverse.moveSpeed, forward.moveSpeed, "Pet stat aggregation is independent of equipped slot iteration order")
end)

runTest("BrainBoost_EXP_Bonus_Flows_Into_PlayerState", function()
	local level50AbilityParams = PetAbilityProgressionConfig.GetParams("ExpBonus", 50)
	local resolved = PetStatResolver.Apply(
		{ maxHP = 100, baseDamage = 10, expBonus = 0 },
		{
			{
				baseStats = { maxHP = 100, baseDamage = 10 },
				abilityParams = level50AbilityParams,
				definition = { statModifiers = { Add = { expBonus = 0.30 }, Multiply = {} } },
			},
		}
	)
	assertNear(resolved.maxHP, 200, "Pet base HP is added")
	assertNear(resolved.baseDamage, 20, "Pet base damage is added")
	assertNear(resolved.expBonus, 0.55, "BrainBoost level-50 EXP bonus overrides its legacy static bonus")
end)

runTest("Round_And_Kill_Diamond_Reward_Tuning", function()
	assertEqual(RankConfig.ScoreSettings.KillPlayer.DiamondReward, 40, "First eligible kill reward")
	assertEqual(RankConfig.RoundDiamondRewards.Participation, 300, "Participation reward")
	assertEqual(RankConfig.RoundDiamondRewards.MaxScoreBonus, 400, "Score reward cap")
	assertEqual(RankConfig.RoundDiamondRewards.RankBonuses[1], 300, "First place reward")
end)

print("[ProgressionEconomyTests] all checks passed")
