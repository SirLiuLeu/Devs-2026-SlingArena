--!strict

-- [SLING_MODEL_GUIDE]
-- 1) Create each sling as a Model under ReplicatedStorage/Slings or ReplicatedStorage/Assets/Slings.
-- 2) Model.Name MUST match config id exactly (case-sensitive).
-- 3) Each model should have a PrimaryPart and physics-ready parts.
-- 4) Register the same id below with stats/rarity/modelPath.
-- 5) modelPath format in this config: "ReplicatedStorage/<Folder>/<ModelName>".

local SlingConfig = {}

SlingConfig.Types = {
	{
		id = "Sling_01",
		name = "Test Sling 01",
		modelPath = "ReplicatedStorage/Assets/Slings/Sling_01",
		rarity = "Common",
		stats = { speed = 15.8, weight = 1.0, launchPower = 1.0, control = 1.0 },
	},
	{
		id = "Sling_02",
		name = "Test Sling 02",
		modelPath = "ReplicatedStorage/Assets/Slings/Sling_02",
		rarity = "Common",
		stats = { speed = 16.4, weight = 0.96, launchPower = 1.04, control = 0.98 },
	},
	{
		id = "Sling_03",
		name = "Test Sling 03",
		modelPath = "ReplicatedStorage/Assets/Slings/Sling_03",
		rarity = "Uncommon",
		stats = { speed = 15.2, weight = 1.06, launchPower = 1.08, control = 1.02 },
	},
	{
		id = "Sling_04",
		name = "Test Sling 04",
		modelPath = "ReplicatedStorage/Assets/Slings/Sling_04",
		rarity = "Rare",
		stats = { speed = 17.0, weight = 0.92, launchPower = 1.1, control = 1.05 },
	},
	{
		id = "Sling_05",
		name = "Test Sling 05",
		modelPath = "ReplicatedStorage/Assets/Slings/Sling_05",
		rarity = "Rare",
		stats = { speed = 14.8, weight = 1.1, launchPower = 1.15, control = 0.95 },
	},
	{
		id = "Sling_Template",
		name = "Default Arena Sling",
		modelPath = "ReplicatedStorage/Assets/Slings/Sling_Template",
		rarity = "Common",
		stats = { speed = 16, weight = 1.0, launchPower = 1.0, control = 1.0 },
	},
	{
		id = "FireSling",
		name = "Fire Sling",
		modelPath = "ReplicatedStorage/Slings/FireSling",
		rarity = "Rare",
		stats = { speed = 17, weight = 0.95, launchPower = 1.1, control = 0.95 },
	},
	{
		id = "IceSling",
		name = "Ice Sling",
		modelPath = "ReplicatedStorage/Slings/IceSling",
		rarity = "Rare",
		stats = { speed = 15.5, weight = 1.05, launchPower = 1.0, control = 1.1 },
	},
	{
		id = "StoneSling",
		name = "Stone Sling",
		modelPath = "ReplicatedStorage/Slings/StoneSling",
		rarity = "Common",
		stats = { speed = 14, weight = 1.2, launchPower = 1.25, control = 0.9 },
	},
	{
		id = "WindSling",
		name = "Wind Sling",
		modelPath = "ReplicatedStorage/Slings/WindSling",
		rarity = "Epic",
		stats = { speed = 19, weight = 0.85, launchPower = 1.05, control = 1.15 },
	},
	{
		id = "ThunderSling",
		name = "Thunder Sling",
		modelPath = "ReplicatedStorage/Slings/ThunderSling",
		rarity = "Epic",
		stats = { speed = 18, weight = 0.9, launchPower = 1.2, control = 1.0 },
	},
	{
		id = "ShadowSling",
		name = "Shadow Sling",
		modelPath = "ReplicatedStorage/Slings/ShadowSling",
		rarity = "Legendary",
		stats = { speed = 20, weight = 0.8, launchPower = 1.15, control = 1.2 },
	},
	{
		id = "LightSling",
		name = "Light Sling",
		modelPath = "ReplicatedStorage/Slings/LightSling",
		rarity = "Legendary",
		stats = { speed = 18.5, weight = 0.88, launchPower = 1.1, control = 1.25 },
	},
	{
		id = "NatureSling",
		name = "Nature Sling",
		modelPath = "ReplicatedStorage/Slings/NatureSling",
		rarity = "Uncommon",
		stats = { speed = 16.2, weight = 1.0, launchPower = 1.02, control = 1.08 },
	},
	{
		id = "VoidSling",
		name = "Void Sling",
		modelPath = "ReplicatedStorage/Slings/VoidSling",
		rarity = "Mythic",
		stats = { speed = 21, weight = 0.75, launchPower = 1.3, control = 1.18 },
	},
}

local byId = {}
for _, sling in ipairs(SlingConfig.Types) do
	byId[sling.id] = sling
end

function SlingConfig.GetById(id: string)
	return byId[id]
end

function SlingConfig.GetAllIds(): { string }
	local result = {}
	for _, sling in ipairs(SlingConfig.Types) do
		table.insert(result, sling.id)
	end
	return result
end

return SlingConfig
