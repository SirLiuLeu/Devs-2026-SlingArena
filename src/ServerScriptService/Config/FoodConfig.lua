--!strict

local FoodConfig = {}

--==================================================
-- 1) GLOBAL SETTINGS
--==================================================
FoodConfig.CommonRespawnTime = 10
FoodConfig.HpFoodRespawnTime = 30
FoodConfig.UniqueRespawnTime = 90 -- 1m30s

FoodConfig.SpawnRadius = 10
FoodConfig.ActivePerSpawn = 10
FoodConfig.CommonActivePerSpawn = 10
FoodConfig.HpActivePerSpawn = 10
FoodConfig.MinNoOverlapDistance = 3
FoodConfig.PlacementMaxAttempts = 80

--==================================================
-- 2) FOOD DEFINITIONS (BY MODEL NAME)
--    Name must match the model name in ReplicatedStorage / ServerStorage
--==================================================
FoodConfig.Foods = {
	-- COMMON: same stats, different visuals
	CommonRed = {
		Name = "CommonRed",
		Type = "Common",
		HP = 0,
		Exp = 5,
		HealHP = 3,
		DiamondRate = 0,
		DiamondAmount = 0,
		RespawnTime = 10,
		Touch = true,
		MustHit = false,
	},
	CommonGreen = {
		Name = "CommonGreen",
		Type = "Common",
		HP = 0,
		Exp = 5,
		HealHP = 3,
		DiamondRate = 0,
		DiamondAmount = 0,
		RespawnTime = 10,
		Touch = true,
		MustHit = false,
	},
	CommonBlue = {
		Name = "CommonBlue",
		Type = "Common",
		HP = 0,
		Exp = 5,
		HealHP = 3,
		DiamondRate = 0,
		DiamondAmount = 0,
		RespawnTime = 10,
		Touch = true,
		MustHit = false,
	},

	-- UNCOMMON
	UncommonIce = {
		Name = "UncommonIce",
		Type = "Uncommon",
		HP = 3000,
		Exp = 25,
		HealHP = 0,
		DiamondRate = 0.05,
		DiamondAmount = 1,
		RespawnTime = 30,
		Touch = false,
		MustHit = true,
	},

	-- RARE
	RareAmber = {
		Name = "RareAmber",
		Type = "Rare",
		HP = 5000,
		Exp = 45,
		HealHP = 0,
		DiamondRate = 0.08,
		DiamondAmount = 1,
		RespawnTime = 30,
		Touch = false,
		MustHit = true,
	},

	-- EPIC
	EpicViolet = {
		Name = "EpicViolet",
		Type = "Epic",
		HP = 8000,
		Exp = 70,
		HealHP = 0,
		DiamondRate = 0.12,
		DiamondAmount = 2,
		RespawnTime = 30,
		Touch = false,
		MustHit = true,
	},

	-- LEGENDARY
	LegendaryGold = {
		Name = "LegendaryGold",
		Type = "Legendary",
		HP = 12000,
		Exp = 120,
		HealHP = 0,
		DiamondRate = 0.18,
		DiamondAmount = 3,
		RespawnTime = 30,
		Touch = false,
		MustHit = true,
	},

	-- MYTHIC
	MythicCrystal = {
		Name = "MythicCrystal",
		Type = "Mythic",
		HP = 15000,
		Exp = 180,
		HealHP = 0,
		DiamondRate = 0.25,
		DiamondAmount = 4,
		RespawnTime = 30,
		Touch = false,
		MustHit = true,
	},

	-- UNIQUE: same stats
	UniqueCrown = {
		Name = "UniqueCrown",
		Type = "Unique",
		HP = 35000,
		Exp = 250,
		HealHP = 0,
		DiamondRate = 0.35,
		DiamondAmount = 5,
		RespawnTime = 90,
		Touch = false,
		MustHit = true,
	},
	UniqueCore = {
		Name = "UniqueCore",
		Type = "Unique",
		HP = 35000,
		Exp = 250,
		HealHP = 0,
		DiamondRate = 0.35,
		DiamondAmount = 5,
		RespawnTime = 90,
		Touch = false,
		MustHit = true,
	},
}

--==================================================
-- 3) TYPE / RARITY POOLS
--==================================================
FoodConfig.TypePools = {
	Common = {
		"CommonRed",
		"CommonGreen",
		"CommonBlue",
	},
	Uncommon = {
		"UncommonIce",
	},
	Rare = {
		"RareAmber",
	},
	Epic = {
		"EpicViolet",
	},
	Legendary = {
		"LegendaryGold",
	},
	Mythic = {
		"MythicCrystal",
	},
	Unique = {
		"UniqueCrown",
		"UniqueCore",
	},
}

--==================================================
-- 4) SPAWN WEIGHTS BY ZONE
--==================================================
FoodConfig.ZoneWeights = {
	MidZones = {
		Common = 20,
		Uncommon = 20,
		Rare = 20,
		Epic = 20,
		Legendary = 10,
		Mythic = 10,
		Unique = 0,
	},

	EdgeZones = {
		Common = 40,
		Uncommon = 30,
		Rare = 30,
		Epic = 0,
		Legendary = 0,
		Mythic = 0,
		Unique = 0,
	},

	CenterZones = {
		Common = 0,
		Uncommon = 0,
		Rare = 0,
		Epic = 0,
		Legendary = 0,
		Mythic = 80,
		Unique = 20,
	},
}

--==================================================
-- 5) ZONE-SPECIFIC RULES
--==================================================
FoodConfig.ZoneRules = {
	MidZones = {
		AllowCommon = true,
		AllowHpFood = true,
		AllowUnique = false,
	},
	EdgeZones = {
		AllowCommon = true,
		AllowHpFood = true,
		AllowUnique = false,
	},
	CenterZones = {
		AllowCommon = false,
		AllowHpFood = true,
		AllowUnique = true,
		UniqueRespawnTime = 90,
	},
}

--==================================================
-- 6) HELPERS
--==================================================
function FoodConfig.IsCommon(foodName: string): boolean
	local rule = FoodConfig.Foods[foodName]
	return rule ~= nil and rule.Type == "Common"
end

function FoodConfig.IsHpFood(foodName: string): boolean
	return not FoodConfig.IsCommon(foodName)
end

function FoodConfig.IsUnique(foodName: string): boolean
	local rule = FoodConfig.Foods[foodName]
	return rule ~= nil and rule.Type == "Unique"
end

return FoodConfig
