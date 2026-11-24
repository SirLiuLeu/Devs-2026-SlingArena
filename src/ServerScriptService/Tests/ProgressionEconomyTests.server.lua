--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local PurchasePetConfig = require(ReplicatedStorage.Shared.Config.PurchasePetConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local PetAbilityProgressionConfig = require(ReplicatedStorage.Shared.Config.PetAbilityProgressionConfig)
local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)
local RoundRewardConfig = require(ReplicatedStorage.Shared.Config.RoundRewardConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local LauncherStatResolver = require(ReplicatedStorage.Shared.Utils.LauncherStatResolver)
local PetStatResolver = require(ReplicatedStorage.Shared.Utils.PetStatResolver)
local PetProgression = require(ReplicatedStorage.Shared.Utils.PetProgression)
local PetDisplayFormatter = require(ReplicatedStorage.Shared.Utils.PetDisplayFormatter)
local DamagePipelineService = require(script.Parent.Parent.Services.DamagePipelineService)
local PetAnimationConfig = require(ReplicatedStorage.Shared.Config.PetAnimationConfig)
local FoodConfig = require(script.Parent.Parent.Config.FoodConfig)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)

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

runTest("Pet_Definitions_Use_AbilityID_As_Sole_Identity", function()
	local titan = PetsConfig.GetByAbilityId("Titan")
	if not titan then error("Titan AbilityID definition is missing") end
	assertEqual(titan.abilityId, "Titan", "AbilityID is the sole canonical Pet identity")
	assertEqual(titan.modelName, "Octopus", "Titan resolves the Octopus model")
	assertEqual(titan.type, nil, "Duplicate Pet type field is removed")
	assertEqual(titan.PetId, nil, "Legacy PetId field is removed")
	assertEqual(titan.effectId, nil, "Duplicate effectId field is removed")
	assertEqual(titan.activeAbilityId, nil, "No separate active ability identifier is retained")
	assertEqual(PetsConfig.GetByAbilityId("PlasmaCannon"), nil, "Retired Pet ID is not a catalog key")
	assertEqual(PetsConfig.LegacyPetDefinitionIdAliases.PlasmaCannon, "Titan", "Old Pet ID migrates to Titan AbilityID")
	assertEqual(PetsConfig.GetByAbilityId("HealthCore"), nil, "Retired HealthCore ID is not a catalog key")
	assertEqual(PetsConfig.LegacyPetDefinitionIdAliases.HealthCore, "MaxHPBoost", "HealthCore migrates to its AbilityID")
	assertEqual(PetsConfig.GetByAbilityId("IronBody").modelName, "Elephant", "Elephant maps to IronBody")
	assertEqual(PetsConfig.GetByAbilityId("AbsorbShield").modelName, "Unicorn", "Unicorn maps to AbsorbShield")
	assertEqual(PetsConfig.LegacyPetDefinitionIdAliases.Shield, "IronBody", "Legacy Shield Pet identity migrates to Elephant IronBody")
	assertEqual(PetsConfig.LegacyPetDefinitionIdAliases.ShadowCloak, "AbsorbShield", "Legacy Unicorn Pet identity migrates to AbsorbShield")
	assertEqual(PetsConfig.GetByAbilityId("IdleStealth"), nil, "Retired IdleStealth is not in the Pet catalog")
	assertEqual(PetAbilityProgressionConfig.Abilities.IdleStealth, nil, "Retired IdleStealth has no progression row")
	assertEqual(PurchasePetConfig.Prices.IdleStealth, nil, "Retired IdleStealth has no Shop price")
	assertEqual(PurchasePetConfig.GetPrice("AbsorbShield"), 1600, "Unicorn AbsorbShield uses Legendary Shop pricing")
	assertEqual(PurchasePetConfig.GetPrice("IronBody"), 650, "Elephant IronBody uses Rare Shop pricing")
	assertEqual(PetsConfig.GetByAbilityId("Poison").modelName, "Snake", "Poison remains the Snake AbilityID")
	assertEqual(PetsConfig.GetByAbilityId("Petrify"), nil, "Retired Petrify ability is not a catalog key")
	assertEqual(PetsConfig.GetByAbilityId("Stun"), nil, "Retired Stun ability is not a catalog key")
	assertEqual(PetsConfig.GetByAbilityId("Shield"), nil, "Retired Shield identifier is not a catalog key")
	assertEqual(PetsConfig.LegacyPetDefinitionIdAliases.Poison, "Lifesteal", "Old Poison Pet ID migrates to Lifesteal")
	assertEqual(titan.modelName, "Octopus", "Model name remains a visual asset reference")
	assertEqual(titan.statModifiers, nil, "Empty stat modifier tables are omitted")
end)

runTest("Pet_AbilityID_Migration_Is_One_Time_And_Preserves_Ownership", function()
	local legacyV0 = {
		Diamonds = 0,
		OwnedItems = {},
		PetIdentityMigrationVersion = 0,
		OwnedPets = {
			oldHydra = { definitionId = "Hydra", level = 4 },
			oldDragon = { definitionId = "Dragon", level = 5 },
			oldUnicorn = { definitionId = "ShadowCloak", level = 6 },
			oldElephant = { definitionId = "Shield", level = 8 },
		},
		EquippedPets = { [1] = "oldHydra", [2] = "oldDragon", [3] = "oldUnicorn" },
	}
	PlayerDataService._ensurePetData(PlayerDataService, legacyV0)
	assertEqual(legacyV0.OwnedPets.oldHydra.abilityId, "FullForce", "Pre-v1 Hydra receives the historical model swap before AbilityID migration")
	assertEqual(legacyV0.OwnedPets.oldDragon.abilityId, "LastStand", "Pre-v1 Dragon receives the historical model swap before AbilityID migration")
	assertEqual(legacyV0.OwnedPets.oldUnicorn.abilityId, "AbsorbShield", "Legacy ShadowCloak/Unicorn migrates to AbsorbShield")
	assertEqual(legacyV0.OwnedPets.oldElephant.abilityId, "IronBody", "Legacy Shield/Elephant migrates to IronBody")
	assertEqual(legacyV0.OwnedPets.oldHydra.definitionId, nil, "Legacy definitionId is cleared")
	assertEqual(legacyV0.OwnedPets.oldDragon.definitionId, nil, "Legacy definitionId is cleared")
	assertEqual(legacyV0.EquippedPets[1], "oldHydra", "First equipped instance ID is preserved")
	assertEqual(legacyV0.EquippedPets[2], "oldDragon", "Second equipped instance ID is preserved")
	assertEqual(legacyV0.EquippedPets[3], "oldUnicorn", "Unicorn equipped slot is preserved")
	assertEqual(legacyV0.OwnedPets.oldHydra.level, 4, "Old Hydra level is preserved")
	assertEqual(legacyV0.OwnedPets.oldDragon.level, 5, "Old Dragon level is preserved")
	assertEqual(legacyV0.OwnedPets.oldElephant.level, 8, "Old Elephant level is preserved")
	assertEqual(legacyV0.PetIdentityMigrationVersion, 3, "Profile advances to canonical roster migration version 3")

	local legacyV1 = {
		Diamonds = 0,
		OwnedItems = {},
		PetIdentityMigrationVersion = 1,
		OwnedPets = {
			oldPoisonPet = { definitionId = "Poison", abilityId = "Petrify", effectId = "Petrify", level = 7 },
			oldSnakePet = { definitionId = "Medusa", abilityId = "Petrify", effectId = "Petrify", level = 3 },
		},
		EquippedPets = { [1] = "oldPoisonPet", [2] = "oldSnakePet" },
	}
	PlayerDataService._ensurePetData(PlayerDataService, legacyV1)
	assertEqual(legacyV1.OwnedPets.oldPoisonPet.abilityId, "Lifesteal", "Retired Poison Pet ID migrates to Lifesteal, not the Snake Poison ability")
	assertEqual(legacyV1.OwnedPets.oldSnakePet.abilityId, "Poison", "Medusa Pet ID migrates to the Snake Poison ability")
	assertEqual(legacyV1.OwnedPets.oldPoisonPet.definitionId, nil, "Legacy Poison definitionId is cleared")
	assertEqual(legacyV1.OwnedPets.oldPoisonPet.effectId, nil, "Legacy effectId is cleared")
	assertEqual(legacyV1.EquippedPets[1], "oldPoisonPet", "Old Poison instance remains equipped in slot 1")
	assertEqual(legacyV1.EquippedPets[2], "oldSnakePet", "Old Snake instance remains equipped in slot 2")

	local legacyV1AbilityOnly = {
		Diamonds = 0,
		OwnedItems = {},
		PetIdentityMigrationVersion = 1,
		OwnedPets = {
			snake = { abilityId = "Poison", level = 2 },
			caterpillar = { abilityId = "Lifesteal", level = 3 },
			phoenix = { abilityId = "Fire", level = 4 },
		},
		EquippedPets = { [1] = "snake", [2] = "caterpillar", [3] = "phoenix" },
	}
	PlayerDataService._ensurePetData(PlayerDataService, legacyV1AbilityOnly)
	assertEqual(legacyV1AbilityOnly.OwnedPets.snake.abilityId, "Poison", "Ability-only Snake record is not passed through Pet-ID aliases")
	assertEqual(legacyV1AbilityOnly.OwnedPets.caterpillar.abilityId, "Lifesteal", "Ability-only Lifesteal record remains canonical")
	assertEqual(legacyV1AbilityOnly.OwnedPets.phoenix.abilityId, "Burn", "Legacy ability aliases still migrate ability-only records")
	assertEqual(legacyV1AbilityOnly.EquippedPets[1], "snake", "Ability-only Snake keeps its equipped slot")
	assertEqual(legacyV1AbilityOnly.EquippedPets[2], "caterpillar", "Ability-only Lifesteal keeps its equipped slot")

	local currentV2 = {
		Diamonds = 0,
		OwnedItems = {},
		PetIdentityMigrationVersion = 2,
		OwnedPets = {
			snake = { abilityId = "Poison", definitionId = "Medusa", effectId = "Petrify", level = 2 },
			caterpillar = { abilityId = "Lifesteal", definitionId = "Poison", effectId = "Lifesteal", level = 3 },
			unicorn = { abilityId = "IdleStealth", level = 4 },
			elephant = { abilityId = "AbsorbShield", level = 5 },
		},
		EquippedPets = { [1] = "snake", [2] = "caterpillar" },
	}
	PlayerDataService._ensurePetData(PlayerDataService, currentV2)
	PlayerDataService._ensurePetData(PlayerDataService, currentV2)
	assertEqual(currentV2.OwnedPets.snake.abilityId, "Poison", "Current version-2 Snake Poison AbilityID is not aliased")
	assertEqual(currentV2.OwnedPets.caterpillar.abilityId, "Lifesteal", "Current version-2 Lifesteal AbilityID is not aliased")
	assertEqual(currentV2.OwnedPets.unicorn.abilityId, "AbsorbShield", "Version-2 IdleStealth ownership migrates to Unicorn AbsorbShield")
	assertEqual(currentV2.OwnedPets.elephant.level, 5, "Migrated Elephant keeps its Pet level")
	assertEqual(currentV2.OwnedPets.elephant.abilityId, "IronBody", "Version-2 Elephant AbsorbShield identity migrates to IronBody")
	assertEqual(currentV2.OwnedPets.snake.definitionId, nil, "V2 stale Pet definitionId is removed")
	assertEqual(currentV2.OwnedPets.snake.effectId, nil, "V2 stale effectId is removed")
	assertEqual(currentV2.OwnedPets.caterpillar.definitionId, nil, "V2 stale Caterpillar definitionId is removed")
	assertEqual(currentV2.OwnedPets.caterpillar.effectId, nil, "V2 stale Caterpillar effectId is removed")
	assertEqual(currentV2.EquippedPets[1], "snake", "Version-2 Snake instance remains equipped")
	assertEqual(currentV2.EquippedPets[2], "caterpillar", "Version-2 Caterpillar instance remains equipped")
	assertEqual(currentV2.EquippedPets[3], "unicorn", "Migrated Unicorn instance remains in its equipped slot")
	assertEqual(currentV2.PetIdentityMigrationVersion, 3, "Repeated normalization remains at version 3")
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

runTest("DamagePipeline_Uses_Pet_AbilityIDs_For_Lifesteal_And_Conditional_Damage", function()
	local player = {} :: any
	local ownedPets = {
		lifesteal = { abilityId = "Lifesteal", level = 1, rarity = "Rare", acquiredAt = 1 },
		poison = { abilityId = "Poison", level = 1, rarity = "Rare", acquiredAt = 1 },
		fullForce = { abilityId = "FullForce", level = 1, rarity = "Epic", acquiredAt = 1 },
		lastStand = { abilityId = "LastStand", level = 1, rarity = "Epic", acquiredAt = 1 },
		ironBodyLevel1 = { abilityId = "IronBody", level = 1, rarity = "Rare", acquiredAt = 1 },
		ironBodyLevel50 = { abilityId = "IronBody", level = 50, rarity = "Rare", acquiredAt = 1 },
		absorbShield = { abilityId = "AbsorbShield", level = 1, rarity = "Rare", acquiredAt = 1 },
	}
	local equippedPets = { [1] = "lifesteal" }
	local playerState = { MaxHP = 1000, CurrentHP = 1000 }
	local dataService = {
		GetOwnedPets = function(_self, _player) return ownedPets end,
		GetEquippedPets = function(_self, _player) return equippedPets end,
	}
	local stateService = {
		GetState = function(_self, _player) return playerState end,
	}
	local services: { [string]: any } = {
		PlayerDataService = dataService,
		PlayerStateService = stateService,
	}
	local registry = {
		GetOptional = function(_self, name: string) return services[name] end,
	}
	local service: any = setmetatable({
		_context = { ServiceRegistry = registry },
	}, DamagePipelineService)

	assertNear(service:_getPetAbilityParams(player, "Lifesteal", "playerLifestealPercent"), 0.02, "Lifesteal Player healing reads Lifesteal progression")
	assertNear(service:_getPetAbilityParams(player, "Poison", "playerLifestealPercent"), 0, "Poison DoT does not inherit Lifesteal progression")

	equippedPets = { [1] = "fullForce" }
	assertNear(service:_getConditionalPetDamageMultiplier(player), 1.10, "FullForce applies its damage bonus at full HP")

	equippedPets = { [1] = "lastStand" }
	playerState.CurrentHP = 200
	assertNear(service:_getConditionalPetDamageMultiplier(player), 1.20, "LastStand applies its maximum bonus at low HP")

	equippedPets = { [1] = "ironBodyLevel1" }
	assertNear(service:_getIronBodyDamageMultiplier(player), 0.80, "Elephant IronBody reduces incoming damage by 20% at level 1")
	equippedPets = { [1] = "ironBodyLevel50" }
	assertNear(service:_getIronBodyDamageMultiplier(player), 0.55, "Elephant IronBody reduces incoming damage by 45% at level 50")
	equippedPets = { [1] = "ironBodyLevel1", [2] = "ironBodyLevel50" }
	assertNear(service:_getIronBodyDamageMultiplier(player), 0.55, "Duplicate IronBody copies use the strongest single mitigation, not multiplicative stacking")
	equippedPets = { [1] = "absorbShield" }
	assertNear(service:_getIronBodyDamageMultiplier(player), 1, "Unicorn AbsorbShield does not also apply IronBody damage reduction")

	service._absorbShieldStates = {}
	assertNear(service:_applyAbsorbShield(player, 1000, true), 1000, "Bypassed damage does not consume AbsorbShield capacity")
	assertNear(service:_applyAbsorbShield(player, 1000, false), 0, "AbsorbShield blocks damage when no bypass applies")
end)

runTest("Pet_Ability_Milestones_Reach_80_And_100_Percent", function()
	local titan20 = PetAbilityProgressionConfig.GetParams("Titan", 20)
	local titan50 = PetAbilityProgressionConfig.GetParams("Titan", 50)
	assertNear(titan20.weightMultiplier, 1.29, "Titan level-20 weight retained")
	assertNear(titan20.hitboxMultiplier, 1.38, "Titan level-20 hitbox retained")
	assertNear(titan50.weightMultiplier, 1.3625, "Titan level-50 weight target")
	assertNear(titan50.hitboxMultiplier, 1.475, "Titan level-50 hitbox target")
	assertNear(titan50.incomingKnockbackMultiplier, 0.6625, "Titan level-50 incoming knockback target")

	local burn1 = PetAbilityProgressionConfig.GetParams("Burn", 1)
	local burn20 = PetAbilityProgressionConfig.GetParams("Burn", 20)
	local burn50 = PetAbilityProgressionConfig.GetParams("Burn", 50)
	assertNear(burn1.damagePerTick, 250, "Burn level-1 damage")
	assertNear(burn20.damagePerTick, 325, "Burn level-20 damage")
	assertNear(burn50.damagePerTick, 375, "Burn level-50 damage")

	local poison1 = PetAbilityProgressionConfig.GetParams("Poison", 1)
	local poison20 = PetAbilityProgressionConfig.GetParams("Poison", 20)
	local poison50 = PetAbilityProgressionConfig.GetParams("Poison", 50)
	assertNear(poison1.damagePerTick, 150, "Poison level-1 damage")
	assertNear(poison20.damagePerTick, 195, "Poison level-20 damage")
	assertNear(poison50.damagePerTick, 225, "Poison level-50 damage")

	local shield = PetAbilityProgressionConfig.GetParams("AbsorbShield", 1)
	assertNear(shield.absorbCapacity, 5000, "AbsorbShield capacity")
	assertNear(shield.refreshInterval, 10, "AbsorbShield refresh interval")
	assertNear(PetAbilityProgressionConfig.GetParams("ExpBonus", 20).expBonus, 0.50, "ExpBonus level-20 value")
	assertNear(PetAbilityProgressionConfig.GetParams("ExpBonus", 50).expBonus, 0.55, "ExpBonus level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("Regeneration", 50).healAmount, 10, "Regeneration fixed healing")
	assertNear(PetAbilityProgressionConfig.GetParams("Regeneration", 50).tickInterval, 1, "Regeneration tick interval")
end)

runTest("Remaining_Pet_Abilities_Reach_Level_50_Targets", function()
	assertNear(PetAbilityProgressionConfig.GetParams("LastStand", 1).lastStandMaxDamageBonus, 0.20, "LastStand level-1 damage")
	assertNear(PetAbilityProgressionConfig.GetParams("LastStand", 50).lastStandMaxDamageBonus, 0.40, "LastStand level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("FullForce", 1).fullForceDamageBonus, 0.10, "FullForce level-1 damage")
	assertNear(PetAbilityProgressionConfig.GetParams("FullForce", 50).fullForceDamageBonus, 0.25, "FullForce level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("Lifesteal", 1).playerLifestealPercent, 0.02, "Lifesteal player percent")
	assertNear(PetAbilityProgressionConfig.GetParams("Lifesteal", 1).foodLifestealPercent, 0.01, "Lifesteal Food percent")
	assertNear(PetAbilityProgressionConfig.GetParams("MaxHPBoost", 1).maxHPMultiplier, 1.10, "MaxHPBoost level-1 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("MaxHPBoost", 50).maxHPMultiplier, 1.25, "MaxHPBoost level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("DamageBoost", 1).baseDamageMultiplier, 1.10, "DamageBoost level-1 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("DamageBoost", 50).baseDamageMultiplier, 1.20, "DamageBoost level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("MoveSpeedBoost", 1).moveSpeedMultiplier, 1.05, "MoveSpeedBoost level-1 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("MoveSpeedBoost", 50).moveSpeedMultiplier, 1.15, "MoveSpeedBoost level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("LaunchBooster", 1).launchSpeedMultiplier, 1.20, "LaunchBooster level-1 multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("LaunchBooster", 50).launchSpeedMultiplier, 1.26, "LaunchBooster level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("QuickReload", 1).launchCooldownReduction, 1.0, "QuickReload level-1 reduction")
	assertNear(PetAbilityProgressionConfig.GetParams("QuickReload", 50).launchCooldownReduction, 1.3, "QuickReload level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("ThornArmor", 1).reflectDamageBonus, 0.20, "ThornArmor level-1 reflect")
	assertNear(PetAbilityProgressionConfig.GetParams("ThornArmor", 50).reflectDamageBonus, 0.25, "ThornArmor level-50 target")
	assertNear(PetAbilityProgressionConfig.GetParams("IronBody", 1).damageMultiplier, 0.80, "IronBody level-1 leaves 80% damage")
	assertNear(PetAbilityProgressionConfig.GetParams("IronBody", 50).damageMultiplier, 0.55, "IronBody level-50 leaves 55% damage")

	local hpProgression = PetProgression.Resolve(PetsConfig.GetByAbilityId("MaxHPBoost"), { abilityId = "MaxHPBoost", level = 50 })
	local thornProgression = PetProgression.Resolve(PetsConfig.GetByAbilityId("ThornArmor"), { abilityId = "ThornArmor", level = 50 })
	assertNear(hpProgression.abilityParams.maxHPMultiplier, 1.25, "MaxHPBoost resolves final HP multiplier")
	assertNear(thornProgression.abilityParams.reflectDamageBonus, 0.25, "ThornArmor resolves level-50 reflect")
end)

runTest("Level_Scaled_Pet_Stat_Bonuses_Override_Legacy_Static_Modifiers", function()
	local function buildProgression(abilityId: string, level: number)
		return {
			baseStats = {},
			abilityParams = PetAbilityProgressionConfig.GetParams(abilityId, level),
			definition = PetsConfig.GetByAbilityId(abilityId),
		}
	end

	local level1 = PetStatResolver.Apply(
		{ maxHP = 1000, baseDamage = 100, moveSpeed = 15, launchSpeed = 100, reflectDamage = 0.05 },
		{
			buildProgression("MaxHPBoost", 1),
			buildProgression("DamageBoost", 1),
			buildProgression("MoveSpeedBoost", 1),
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
			buildProgression("MaxHPBoost", 50),
			buildProgression("DamageBoost", 50),
			buildProgression("MoveSpeedBoost", 50),
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

runTest("Redesigned_Pet_Ability_Progression_Targets", function()
	assertNear(PetAbilityProgressionConfig.GetParams("LauncherBoost", 1).launcherStatMultiplier, 1.10, "Yeti always grants +10% Launcher stats")
	assertNear(PetAbilityProgressionConfig.GetParams("PetBaseBoost", 1).petBaseStatsMultiplier, 2.0, "Penguin doubles Pet base stats once")
	assertNear(PetAbilityProgressionConfig.GetParams("LastStand", 1).lastStandMaxDamageBonus, 0.20, "Hydra level-1 Last Stand")
	assertNear(PetAbilityProgressionConfig.GetParams("LastStand", 50).lastStandMaxDamageBonus, 0.40, "Hydra level-50 Last Stand")
	assertNear(PetAbilityProgressionConfig.GetParams("FullForce", 1).fullForceDamageBonus, 0.10, "Dragon level-1 Full Force")
	assertNear(PetAbilityProgressionConfig.GetParams("FullForce", 50).fullForceDamageBonus, 0.25, "Dragon level-50 Full Force")
	assertNear(PetAbilityProgressionConfig.GetParams("Lifesteal", 1).playerLifestealPercent, 0.02, "Caterpillar player lifesteal")
	assertNear(PetAbilityProgressionConfig.GetParams("Lifesteal", 1).foodLifestealPercent, 0.01, "Caterpillar Food lifesteal")
	assertNear(PetAbilityProgressionConfig.GetParams("MaxHPBoost", 1).maxHPMultiplier, 1.10, "Pig level-1 final HP multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("MaxHPBoost", 50).maxHPMultiplier, 1.25, "Pig level-50 final HP multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("DamageBoost", 1).baseDamageMultiplier, 1.10, "Panda level-1 final damage multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("DamageBoost", 50).baseDamageMultiplier, 1.20, "Panda level-50 final damage multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("MoveSpeedBoost", 1).moveSpeedMultiplier, 1.05, "Bunny level-1 move speed multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("MoveSpeedBoost", 50).moveSpeedMultiplier, 1.15, "Bunny level-50 move speed multiplier")
	assertNear(PetAbilityProgressionConfig.GetParams("AbsorbShield", 1).absorbCapacity, 5000, "Unicorn AbsorbShield capacity")
	assertNear(PetAbilityProgressionConfig.GetParams("AbsorbShield", 1).refreshInterval, 10, "Unicorn AbsorbShield refresh interval")
end)

runTest("Pet_Rarity_Assignments_Match_Redesigned_Tiers", function()
	local expected = {
		ExpBonus = "Common", MoveSpeedBoost = "Common",
		LaunchBooster = "Rare", QuickReload = "Rare", Regeneration = "Rare", Lifesteal = "Rare", Burn = "Rare",
		Poison = "Rare", MaxHPBoost = "Rare", DamageBoost = "Rare",
		Titan = "Epic", LastStand = "Epic", LauncherBoost = "Epic", FullForce = "Epic", ThornArmor = "Epic", IronBody = "Rare",
		PetBaseBoost = "Legendary", AbsorbShield = "Legendary",
	}
	assertEqual(#PetsConfig.GetAllAbilityIds(), 18, "AbilityID catalog count")
	for abilityId, rarity in pairs(expected) do
		assertEqual(PetsConfig.GetByAbilityId(abilityId).rarity, rarity, abilityId .. " rarity assignment")
	end
	assertEqual(#PurchasePetConfig.GetAllAbilityIds(), 18, "Every AbilityID retains a purchase price")
end)

runTest("Pet_Stat_Source_Layers_Do_Not_Amplify_The_Wrong_Stats", function()
	local launcher = {
		maxHP = 1000, baseDamage = 100, moveSpeed = 20,
		armor = 0.20, reflectDamage = 0.10, regen = 2, launchSpeed = 100,
	}
	local function progression(abilityId: string, level: number, baseHP: number?, baseDamage: number?)
		return {
			baseStats = { maxHP = baseHP or 0, baseDamage = baseDamage or 0 },
			abilityParams = PetAbilityProgressionConfig.GetParams(abilityId, level),
			definition = PetsConfig.GetByAbilityId(abilityId),
		}
	end
	local equipped = {
		progression("LauncherBoost", 1),
		progression("PetBaseBoost", 1, 100, 10),
		progression("MaxHPBoost", 1),
		progression("DamageBoost", 1),
		progression("MoveSpeedBoost", 1),
		{ baseStats = { maxHP = 50, baseDamage = 5 }, abilityParams = {}, definition = PetsConfig.GetByAbilityId("ExpBonus") },
	}
	local launcherAfterYeti = PetStatResolver.ApplyLauncherModifiers(launcher, equipped)
	assertNear(launcherAfterYeti.maxHP, 1100, "Yeti boosts Launcher HP before Pet HP is added")
	assertNear(launcherAfterYeti.baseDamage, 110, "Yeti boosts Launcher base damage before Pet damage is added")
	assertNear(launcherAfterYeti.moveSpeed, 22, "Yeti boosts Launcher move speed")
	assertNear(launcherAfterYeti.armor, 0.22, "Yeti relatively boosts Launcher armor")
	local resolved = PetStatResolver.Apply(launcherAfterYeti, equipped)
	assertNear(resolved.maxHP, (1100 + (100 + 50) * 2) * 1.10, "Penguin doubles only Pet base HP; Pig multiplies final total")
	assertNear(resolved.baseDamage, (110 + (10 + 5) * 2) * 1.10, "Penguin doubles only Pet base damage; Panda multiplies final total")
	assertNear(resolved.moveSpeed, 22 * 1.05, "Bunny multiplies final move speed after Yeti")
	assertNear(resolved.healingReceivedMultiplier, 1, "No Fish Pet means no healing-received bonus")

	local fish = {
		baseStats = {},
		abilityParams = PetAbilityProgressionConfig.GetParams("Regeneration", 1),
		definition = PetsConfig.GetByAbilityId("Regeneration"),
	}
	local withFish = PetStatResolver.Apply(launcher, { fish })
	assertNear(withFish.healingReceivedMultiplier, 1.10, "Fish amplifies healing received at level 1")
end)

runTest("Pet_Animation_Config_Uses_The_Pet_AbilityID_Catalog", function()
	local catalog = PetsConfig.GetAllAbilityIds()
	local animationIds = PetAnimationConfig.GetAllAbilityIds()
	assertEqual(#animationIds, #catalog, "Every Pet AbilityID has exactly one animation row")
	for _, abilityId in ipairs(catalog) do
		assertEqual(PetAnimationConfig.Animations[abilityId] ~= nil, true, abilityId .. " animation row exists")
	end
	for _, abilityId in ipairs(animationIds) do
		assertEqual(PetsConfig.IsValidAbilityId(abilityId), true, abilityId .. " animation row is not orphaned")
	end
	assertEqual(PetAnimationConfig.Animations.PlasmaCannon, nil, "Retired Pet identifier is not an animation key")
	assertEqual(PetAnimationConfig.Animations.Hydra, nil, "Model name is not an animation key")
	assertEqual(PetAnimationConfig.Animations.IronBody ~= nil, true, "Elephant IronBody has an animation row")
	assertEqual(PetAnimationConfig.Animations.AbsorbShield ~= nil, true, "Unicorn AbsorbShield has an animation row")
	assertEqual(PetAnimationConfig.Animations.IdleStealth, nil, "Retired IdleStealth animation row is removed")
end)

runTest("Pet_Ability_Display_Templates_Resolve_All_Placeholders", function()
	for _, abilityId in ipairs(PetsConfig.GetAllAbilityIds()) do
		local definition = PetsConfig.GetByAbilityId(abilityId)
		local display = PetDisplayFormatter.Format(definition, 1, false, "vi")
		assertEqual(string.find(display.ScriptText, "?", 1, true), nil, abilityId .. " ability description has all values")
	end

	local ironBodyText = PetDisplayFormatter.Format(PetsConfig.GetByAbilityId("IronBody"), 1, false, "vi").ScriptText
	assertEqual(string.find(ironBodyText, "20%", 1, true) ~= nil, true, "Elephant IronBody displays its level-1 damage reduction")
	local absorbShieldText = PetDisplayFormatter.Format(PetsConfig.GetByAbilityId("AbsorbShield"), 1, false, "vi").ScriptText
	assertEqual(string.find(absorbShieldText, "LavaTrap", 1, true) ~= nil, true, "Unicorn AbsorbShield description identifies the LavaTrap bypass")
	assertEqual(string.find(absorbShieldText, "SafeZone", 1, true) ~= nil, true, "Unicorn AbsorbShield description identifies the SafeZone bypass")
end)

runTest("UpgradePet_Remote_Accepts_Levels_Through_50", function()
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 50), true, "Level 50 validation")
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, "test-pet", 51), false, "Level 51 rejection")
end)

runTest("FoodSpawn_Uses_Zone_Specific_Layouts", function()
	assertEqual(FoodConfig.SpawnRadius, 20, "Mid/Edge FoodSpawn circular radius")
	assertEqual(FoodConfig.SpawnGridDivisions, 3, "Mid/Edge FoodSpawn uses three grid divisions per axis")
	assertEqual(FoodConfig.SpawnGridDivisions ^ 2, 9, "Each Mid/Edge FoodSpawn pivot owns nine Food slots")
	assertEqual(FoodConfig.ZoneSpawnOverrides.CenterZones.Rows, 1, "CenterZones uses one grid row")
	assertEqual(FoodConfig.ZoneSpawnOverrides.CenterZones.Columns, 2, "CenterZones uses two grid columns")
	assertEqual(FoodConfig.ZoneSpawnOverrides.CenterZones.Rows * FoodConfig.ZoneSpawnOverrides.CenterZones.Columns, 2, "Each CenterZones marker owns two Food slots")
	assertEqual(FoodConfig.ZoneSpawnOverrides.CenterZones.SpawnRadius, 10, "CenterZones circular spawn radius")
	assertEqual(FoodConfig.HpFoodPivotYOffset, 1, "HP-based Food pivot is raised by one world-space stud")
	assertEqual(FoodConfig.ZoneWeights.CenterZones.Epic, 70, "Center cell Epic weight")
	assertEqual(FoodConfig.ZoneWeights.CenterZones.Legendary, 30, "Center cell Legendary weight")
	assertEqual(FoodConfig.ZoneWeights.MidZones.Common, 70, "Mid cell Common weight")
	assertEqual(FoodConfig.ZoneWeights.EdgeZones.Legendary, 5, "Edge cell Legendary weight")
	assertEqual(FoodConfig.CommonFoodsPerSpawn, nil, "Legacy Common-only marker layout removed")
	assertEqual(FoodConfig.CommonSpawnOffsetMin, nil, "Legacy Common corner minimum removed")
	assertEqual(FoodConfig.CommonSpawnOffsetMax, nil, "Legacy Common corner maximum removed")
	assertEqual(FoodConfig.SpawnOffsetRadius, nil, "Legacy HP-only offset radius removed")
	assertEqual(FoodConfig.SpawnGrid, nil, "Legacy region/grid spawn config removed")
	assertEqual(FoodConfig.ZoneSpawnSettings, nil, "Area-based marker counts removed")
	assertEqual(FoodConfig.GetSpawnCountForArea, nil, "Area-based count helper removed")
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

runTest("Round_Placement_GiftBox_Reward_Scaling", function()
	assertEqual(RankConfig.ScoreSettings.KillPlayer.DiamondReward, 40, "Kill reward remains separate from round placement reward")
	assertEqual(RoundRewardConfig.AwaitCountdownSeconds, 30, "Awaits countdown duration")
	assertEqual(RoundRewardConfig.SoloFinalPhaseSeconds, 8 * 60, "Solo round reaches FinalPhase at eight minutes")
	assertEqual(RoundRewardConfig.GetGiftBoxAmount(6, 1), 7, "Six-player winner GiftBox amount")
	assertEqual(RoundRewardConfig.GetGiftBoxAmount(6, 2), 6, "Six-player rank-2 GiftBox amount")
	assertEqual(RoundRewardConfig.GetGiftBoxAmount(6, 6), 2, "Six-player last-place GiftBox amount")
	assertEqual(RoundRewardConfig.GetGiftBoxAmount(1, 1), 2, "Solo winner GiftBox amount")
	assertEqual(RoundRewardConfig.GetGiftBoxAmount(6, 7), 0, "Invalid rank receives no GiftBoxes")
	assertEqual(ItemConfig.GetById("gift_box") ~= nil, true, "Placement reward item exists in ItemConfig")
end)

print("[ProgressionEconomyTests] all checks passed")


runTest("Shop_Catalog_Has_All_Configured_Items_And_Launchers", function()
	assertEqual(#ItemConfig.GetAllIds(), 8, "All ItemConfig definitions are included in Shop")
	for _, itemId in ipairs(ItemConfig.GetAllIds()) do
		local item = ItemConfig.GetById(itemId)
		if not item then error("Missing ItemConfig definition: " .. itemId) end
		assertEqual(type(item.script), "string", "Item script exists: " .. itemId)
		assertEqual(type(item.shopPriceX1), "number", "Item x1 price exists: " .. itemId)
		assertEqual(type(item.shopPriceX10), "number", "Item x10 price exists: " .. itemId)
	end

	assertEqual(#LauncherConfig.GetAllIds(), 5, "All LauncherConfig definitions are included in Shop")
	for _, launcherId in ipairs(LauncherConfig.GetAllIds()) do
		local launcher = LauncherConfig.GetById(launcherId)
		if not launcher then error("Missing LauncherConfig definition: " .. launcherId) end
		assertEqual(type(launcher.script), "string", "Launcher script exists: " .. launcherId)
		assertEqual(type(launcher.shopPrice), "number", "Launcher shop price exists: " .. launcherId)
	end
end)

runTest("Shop_Pet_Catalog_Has_Price_And_Ability_Description_For_Every_Pet", function()
	assertEqual(#PetsConfig.GetAllAbilityIds(), 18, "All Pet AbilityIDs are available")
	assertEqual(#PurchasePetConfig.GetAllAbilityIds(), 18, "Every AbilityID has a purchase price")
	for _, abilityId in ipairs(PetsConfig.GetAllAbilityIds()) do
		local pet = PetsConfig.GetByAbilityId(abilityId)
		if not pet then error("Missing Pet AbilityID: " .. abilityId) end
		assertEqual(pet.abilityId, abilityId, "Catalog key matches its sole AbilityID: " .. abilityId)
		local abilityParams = PetAbilityProgressionConfig.GetParams(abilityId, 1)
		assertEqual(next(abilityParams) ~= nil, true, abilityId .. " has level-1 progression parameters")
		local display = PetDisplayFormatter.Format(pet, 1, false, "vi")
		assertEqual(type(display.ScriptText), "string", "Pet ability display exists: " .. abilityId)
		assertEqual(display.ScriptText ~= "", true, "Pet ability display is non-empty: " .. abilityId)
		assertEqual(type(PurchasePetConfig.GetPrice(abilityId)), "number", "Pet purchase price exists: " .. abilityId)
	end
end)

runTest("PurchasePet_Remote_Validates_Pet_Definition_ID_Shape", function()
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.PurchasePet, "Titan"), true, "Non-empty AbilityID accepted")
	assertEqual(RemoteContracts.Validate(RemoteContracts.Names.PurchasePet, ""), false, "Empty Pet definition ID rejected")
end)
