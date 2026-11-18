--!strict

-- Development shop prices for purchasing Pet definitions with Diamonds.
-- Adjust these values during economy balancing; the server always reads this config.
local PetsConfig = require(game:GetService("ReplicatedStorage").Shared.Config.PetsConfig)

local PurchasePetConfig = {}

PurchasePetConfig.Prices = {
	PlasmaCannon = 850,
	Hydra = 450,
	ThunderHammer = 800,
	Medusa = 1500,
	IceCrystal = 350,
	GhostFlame = 800,
	Poison = 300,
	HealthCore = 280,
	PowerCore = 280,
	Shield = 400,
	BrainBoost = 350,
	TurboModule = 350,
	LaunchBooster = 400,
	Dragon = 850,
	QuickReload = 350,
	ThornArmor = 700,
	RegenBooster = 350,
	ShadowCloak = 850,
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
