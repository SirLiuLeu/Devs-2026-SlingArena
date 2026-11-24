--!strict

-- Development shop prices for purchasing Pet definitions with Diamonds.
-- Adjust these values during economy balancing; the server always reads this config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)

local PurchasePetConfig = {}

PurchasePetConfig.Prices = {
	-- Common
	ExpBonus = 200,
	MoveSpeedBoost = 250,

	-- Rare
	LaunchBooster = 450,
	QuickReload = 400,
	Regeneration = 450,
	Lifesteal = 450,
	Poison = 700,
	Burn = 650,
	MaxHPBoost = 400,
	DamageBoost = 400,
	AbsorbShield = 650,

	-- Epic
	Titan = 1000,
	LastStand = 1100,
	LauncherBoost = 1000,
	FullForce = 1000,
	ThornArmor = 1000,

	-- Legendary
	PetBaseBoost = 1600,
	IdleStealth = 1600,
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
