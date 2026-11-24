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
	Titan = 1000,
	Hydra = 1100,
	ThunderHammer = 1000,
	Dragon = 1000,
	ThornArmor = 1000,

	-- Legendary
	IceCrystal = 1600,
	ShadowCloak = 1600,
}

function PurchasePetConfig.GetPrice(abilityId: string): number?
	if not PetsConfig.GetByAbilityId(abilityId) then
		return nil
	end
	local price = PurchasePetConfig.Prices[abilityId]
	if type(price) ~= "number" then
		return nil
	end
	return math.max(0, math.floor(price))
end

function PurchasePetConfig.GetAllAbilityIds(): { string }
	local result = {}
	for abilityId in pairs(PurchasePetConfig.Prices) do
		if PetsConfig.GetByAbilityId(abilityId) then
			table.insert(result, abilityId)
		end
	end
	table.sort(result)
	return result
end

return PurchasePetConfig
