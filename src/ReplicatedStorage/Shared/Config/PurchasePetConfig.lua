--!strict

-- Development shop prices for purchasing Pet definitions with Diamonds.
-- Adjust these values during economy balancing; the server always reads this config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)

local PurchasePetConfig = {}

PurchasePetConfig.Prices = {
	-- Common
	BrainBoost = 200,
	TurboModule = 250,

	-- Rare
	LaunchBooster = 450,
	QuickReload = 400,
	RegenBooster = 450,
	Poison = 450,
	Medusa = 700,
	GhostFlame = 650,
	HealthCore = 400,
	PowerCore = 400,
	Shield = 650,

	-- Epic
	PlasmaCannon = 1000,
	Hydra = 1100,
	ThunderHammer = 1000,
	Dragon = 1000,
	ThornArmor = 1000,

	-- Legendary
	IceCrystal = 1600,
	ShadowCloak = 1600,
}

function PurchasePetConfig.GetPrice(definitionId: string): number?
	if not PetsConfig.GetById(definitionId) then
		return nil
	end
	local price = PurchasePetConfig.Prices[definitionId]
	if type(price) ~= "number" then
		return nil
	end
	return math.max(0, math.floor(price))
end

function PurchasePetConfig.GetAllIds(): { string }
	local result = {}
	for definitionId in pairs(PurchasePetConfig.Prices) do
		if PetsConfig.GetById(definitionId) then
			table.insert(result, definitionId)
		end
	end
	table.sort(result)
	return result
end

return PurchasePetConfig
