--!strict

local FoodConfig = {}

--==================================================
-- 1) GLOBAL SETTINGS
--==================================================
FoodConfig.CommonRespawnTime = 10
FoodConfig.HpFoodRespawnTime = 30

-- FoodSpawn Parts define the complete allowed X/Z rectangle.
FoodConfig.SpawnAreaPerFood = 1000
FoodConfig.MinFoodPerSpawn = 1
FoodConfig.MaxFoodPerSpawn = 20
FoodConfig.MinNoOverlapDistance = 3
FoodConfig.HpFoodMinNoOverlapDistance = 7
FoodConfig.MinPlayerSpawnClearance = 5

-- Food must land on an upward-facing tagged floor close to the FoodSpawn plane.
FoodConfig.GroundSurfaceTag = "Collision_Ground"
FoodConfig.GroundRaycastStartHeight = 50
FoodConfig.GroundRaycastDepth = 300
FoodConfig.GroundMinNormalY = 0.9
FoodConfig.GroundMaxVerticalOffset = 4
FoodConfig.GroundMaxCornerHeightDifference = 1.5

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
		Exp = 50,
		HealHP = 20,
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
		Exp = 50,
		HealHP = 15,
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
		Exp = 50,
		HealHP = 10,
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
		DiamondRate = 0.20,
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
		DiamondRate = 0.32,
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
		DiamondRate = 0.48,
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
		DiamondRate = 0.72,
		DiamondAmount = 3,
		RespawnTime = 30,
		Touch = false,
		MustHit = true,
	}
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
	}
}


FoodConfig.ZoneSpawnSettings = {
	CenterZones = { ActivePerSpawn = 1 },
	MidZones = { AreaBased = true },
	EdgeZones = { AreaBased = true },
}

function FoodConfig.GetSpawnCountForArea(area: number): number
	local safeArea = math.max(0, tonumber(area) or 0)
	local density = math.max(1, FoodConfig.SpawnAreaPerFood)
	return math.clamp(
		math.floor(safeArea / density),
		FoodConfig.MinFoodPerSpawn,
		FoodConfig.MaxFoodPerSpawn
	)
end

--==================================================
-- 4) SPAWN WEIGHTS BY ZONE
--==================================================
FoodConfig.ZoneWeights = {
	MidZones = {
		Common = 70,
		Uncommon = 15,
		Rare = 10,
		Epic = 5,
		Legendary = 0,
	},

	EdgeZones = {
		Common = 65,
		Uncommon = 15,
		Rare = 10,
		Epic = 5,
		Legendary = 5,
	},

	CenterZones = {
		Common = 0,
		Uncommon = 0,
		Rare = 0,
		Epic = 70,
		Legendary = 30,
	},
}

--==================================================
-- 5) HELPERS
--==================================================
function FoodConfig.IsCommon(foodType: string): boolean
	return foodType == "Common"
end

function FoodConfig.IsHpFood(foodType: string): boolean
	return foodType ~= "Common"
end

return FoodConfig