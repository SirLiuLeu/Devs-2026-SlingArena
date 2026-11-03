--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local PetAbilityProgressionConfig = require(ReplicatedStorage.Shared.Config.PetAbilityProgressionConfig)
local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local LauncherStatResolver = require(ReplicatedStorage.Shared.Utils.LauncherStatResolver)
local PetStatResolver = require(ReplicatedStorage.Shared.Utils.PetStatResolver)
local PetProgression = require(ReplicatedStorage.Shared.Utils.PetProgression)
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

runTest("Remaining_Pet_Abilities_Reach_Level_50_Targets", function()
	assertNear(PetAbilityProgressionConfig.GetParams("Stun", 1).collisionExtraDuration, 1.25, "ThunderHammer level-1 Stun")
	assertNear(PetAbilityProgressionConfig.GetParams("Stun", 20).collisionExtraDuration, 1.60, "ThunderHammer level-20 Stun")
	assertNear(PetAbilityProgressionConfig.GetParams("Stun", 50).collisionExtraDuration, 1.80, "ThunderHammer level-50 Stun")
	assertNear(PetAbilityProgressionConfig.GetParams("Petrify", 1).collisionExtraDuration, 5.0, "Medusa level-1 Petrify")
	assertNear(PetAbilityProgressionConfig.GetParams("Petrify", 20).collisionExtraDuration, 6.0, "Medusa level-20 Petrify")
	assertNear(PetAbilityProgressionConfig.GetParams("Petrify", 50).collisionExtraDuration, 6.5, "Medusa level-50 Petrify")
	assertNear(PetAbilityProgressionConfig.GetParams("Burn", 1).damagePerTick, 250, "GhostFlame level-1 Burn")
	assertNear(PetAbilityProgressionConfig.GetParams("Burn", 20).damagePerTick, 325, "GhostFlame level-20 Burn")
	assertNear(PetAbilityProgressionConfig.GetParams("Burn", 50).damagePerTick, 375, "GhostFlame level-50 Burn")
	assertNear(PetAbilityProgressionConfig.GetParams("Poison", 1).damagePerTick, 150, "Poison level-1 DoT")
	assertNear(PetAbilityProgressionConfig.GetParams("Poison", 20).damagePerTick, 195, "Poison level-20 DoT")
	assertNear(PetAbilityProgressionConfig.GetParams("Poison", 50).damagePerTick, 225, "Poison level-50 DoT")
	assertNear(PetAbilityProgressionConfig.GetParams("HealthCore", 1).maxHPBonus, 5000, "HealthCore level-1 HP")
	assertNear(PetAbilityProgressionConfig.GetParams("HealthCore", 20).maxHPBonus, 6000, "HealthCore level-20 HP")
	assertNear(PetAbilityProgressionConfig.GetParams("HealthCore", 50).maxHPBonus, 6500, "HealthCore level-50 HP")
	assertNear(PetAbilityProgressionConfig.GetParams("PowerCore", 1).baseDamageBonus, 500, "PowerCore level-1 damage")
	assertNear(PetAbilityProgressionConfig.GetParams("PowerCore", 20).baseDamageBonus, 600, "PowerCore level-20 damage")
	assertNear(PetAbilityProgressionConfig.GetParams("PowerCore", 50).baseDamageBonus, 650, "PowerCore level-50 damage")
	assertNear(PetAbilityProgressionConfig.GetParams("TurboModule", 1).moveSpeedBonus, 10, "TurboModule level-1 speed")
	assertNear(PetAbilityProgressionConfig.GetParams("TurboModule", 20).moveSpeedBonus, 12, "TurboModule level-20 speed")
	assertNear(PetAbilityProgressionConfig.GetParams("TurboModule", 50).moveSpeedBonus, 13, "TurboModule level-50 speed")
	assertNear(PetAbilityProgressionConfig.GetParams("LaunchBooster", 1).launchSpeedMultiplier, 1.20, "LaunchBooster level-1 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("LaunchBooster", 20).launchSpeedMultiplier, 1.24, "LaunchBooster level-20 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("LaunchBooster", 50).launchSpeedMultiplier, 1.26, "LaunchBooster level-50 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("QuickReload", 1).launchCooldownReduction, 1.0, "QuickReload level-1 reduction")
	assertNear(PetAbilityProgressionConfig.GetParams("QuickReload", 20).launchCooldownReduction, 1.2, "QuickReload level-20 reduction")
	assertNear(PetAbilityProgressionConfig.GetParams("QuickReload", 50).launchCooldownReduction, 1.3, "QuickReload level-50 reduction")
	assertNear(PetAbilityProgressionConfig.GetParams("ThornArmor", 1).reflectDamageBonus, 0.20, "ThornArmor level-1 reflect")
	assertNear(PetAbilityProgressionConfig.GetParams("ThornArmor", 20).reflectDamageBonus, 0.24, "ThornArmor level-20 reflect")
	assertNear(PetAbilityProgressionConfig.GetParams("ThornArmor", 50).reflectDamageBonus, 0.25, "ThornArmor level-50 reflect")
	assertNear(PetAbilityProgressionConfig.GetParams("IdleStealth", 1).idleSeconds, 3.0, "ShadowCloak level-1 stealth delay")
	assertNear(PetAbilityProgressionConfig.GetParams("IdleStealth", 20).idleSeconds, 2.5, "ShadowCloak level-20 stealth delay")
	assertNear(PetAbilityProgressionConfig.GetParams("IdleStealth", 50).idleSeconds, 2.25, "ShadowCloak level-50 stealth delay")

	local healthProgression = PetProgression.Resolve(PetsConfig.GetById("HealthCore"), { definitionId = "HealthCore", level = 50 })
	local thornProgression = PetProgression.Resolve(PetsConfig.GetById("ThornArmor"), { definitionId = "ThornArmor", level = 50 })
	assertNear(healthProgression.abilityParams.maxHPBonus, 6500, "Stat-only Pet resolves progression by PetId")
	assertNear(thornProgression.abilityParams.reflectDamageBonus, 0.25, "NoOp Pet resolves progression by PetId")
end)

runTest("Level_Scaled_Pet_Stat_Bonuses_Override_Legacy_Static_Modifiers", function()
	local function buildProgression(petId: string, level: number)
		return {
			baseStats = {},
			abilityParams = PetAbilityProgressionConfig.GetParams(petId, level),
			definition = PetsConfig.GetById(petId),
		}
	end

	local level1 = PetStatResolver.Apply(
		{ maxHP = 1000, baseDamage = 100, moveSpeed = 15, launchSpeed = 100, reflectDamage = 0.05 },
		{
			buildProgression("HealthCore", 1),
			buildProgression("PowerCore", 1),
			buildProgression("TurboModule", 1),
			buildProgression("LaunchBooster", 1),
			buildProgression("QuickReload", 1),
			buildProgression("ThornArmor", 1),
		}
	)
	assertNear(level1.maxHP, 6000, "HealthCore level-1 bonus is applied once")
	assertNear(level1.baseDamage, 600, "PowerCore level-1 bonus is applied once")
	assertNear(level1.moveSpeed, 25, "TurboModule level-1 bonus is applied once")
	assertNear(level1.launchSpeed, 120, "LaunchBooster level-1 multiplier is applied once")
	assertNear(level1.launchCooldown, -1.0, "QuickReload level-1 cooldown reduction is applied")
	assertNear(level1.reflectDamage, 0.25, "ThornArmor level-1 reflect is applied once")

	local level50 = PetStatResolver.Apply(
		{ maxHP = 1000, baseDamage = 100, moveSpeed = 15, launchSpeed = 100, reflectDamage = 0.05 },
		{
			buildProgression("HealthCore", 50),
			buildProgression("PowerCore", 50),
			buildProgression("TurboModule", 50),
			buildProgression("LaunchBooster", 50),
			buildProgression("QuickReload", 50),
			buildProgression("ThornArmor", 50),
		}
	)
	assertNear(level50.maxHP, 7500, "HealthCore level-50 bonus is applied once")
	assertNear(level50.baseDamage, 750, "PowerCore level-50 bonus is applied once")
	assertNear(level50.moveSpeed, 28, "TurboModule level-50 bonus is applied once")
	assertNear(level50.launchSpeed, 126, "LaunchBooster level-50 multiplier is applied once")
	assertNear(level50.launchCooldown, -1.3, "QuickReload level-50 cooldown reduction is applied")
	assertNear(level50.reflectDamage, 0.30, "ThornArmor level-50 reflect is applied once")
end)

runTest("UpgradePet_Remote_Accepts_Levels_Through_50", function()
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 50), true, "Level 50 validation")
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 51), false, "Level 51 rejection")
end)

runTest("FoodSpawn_Area_Density_And_Gaps", function()
	assertEqual(FoodConfig.SpawnAreaPerFood, 500, "Food density uses half the previous area per item")
	assertEqual(FoodConfig.MaxFoodPerSpawn, 40, "FoodSpawn count cap doubles")
	assertEqual(FoodConfig.GetSpawnCountForArea(100 * 100), 20, "100x100 FoodSpawn target count doubles")
	assertEqual(FoodConfig.GetSpawnCountForArea(50 * 50), 5, "50x50 FoodSpawn target count doubles")
	assertEqual(FoodConfig.GetSpawnCountForArea(500 * 500), 40, "FoodSpawn count cap")
	assertEqual(FoodConfig.ZoneSpawnSettings.CenterZones.ActivePerSpawn, 2, "Center FoodSpawn target count doubles")
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
