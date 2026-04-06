--!strict

-- [SLING_MODEL_GUIDE]
-- 1) Create each sling as a Model under ReplicatedStorage/Slings.
-- 2) Model.Name MUST match config id exactly (case-sensitive).
-- 3) Each model should have a PrimaryPart and physics-ready parts.
-- 4) Register the same id below with stats/rarity/modelPath.
-- 5) modelPath format in this config: "ReplicatedStorage/Slings/<ModelName>".

local SlingConfig = {}

SlingConfig.Types = {
	{
		id = "SlingModel",
		name = "Default Arena Sling",
		modelPath = "ReplicatedStorage/Slings/SlingModel",
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
