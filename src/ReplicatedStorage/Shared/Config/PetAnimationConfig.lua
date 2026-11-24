--!strict

-- Fill animation IDs per Pet rig in Studio.
-- Each Pet can have a different rig; animation assets are keyed by its AbilityID.
-- Values may be either "rbxassetid://123" or "123".
-- Empty strings intentionally disable an animation until its asset ID is provided.

export type PetAnimationSet = {
	Idle: string,
	Run: string,
	Attack: string?,
	Dance: string,
}

local PetAnimationConfig = {}

PetAnimationConfig.Animations = {
	Titan = { Idle = "", Run = "", Attack = "", Dance = "" }, -- Octopus Pet
	LastStand = { Idle = "", Run = "", Dance = "" }, -- Hydra
	LauncherBoost = { Idle = "", Run = "", Dance = "" }, -- Yeti
	Poison = { Idle = "", Run = "", Dance = "" }, -- Snake
	PetBaseBoost = { Idle = "95090397407808", Run = "70654849990565", Dance = "114087130920750" }, -- Penguin
	Burn = { Idle = "", Run = "", Dance = "" }, -- Phoenix
	Lifesteal = { Idle = "79761118977634", Run = "131793614901610", Dance = "76215975855168" }, -- Caterpillar
	MaxHPBoost = { Idle = "71267273020156", Run = "127885756125728", Dance = "72877466735478" }, -- Pig
	DamageBoost = { Idle = "132080786710960", Run = "81491739793302", Dance = "86177773442474" }, -- Panda
	AbsorbShield = { Idle = "79761118977634", Run = "131793614901610", Dance = "76215975855168" }, -- Elephant
	ExpBonus = { Idle = "132080786710960", Run = "81491739793302", Dance = "86177773442474" }, -- Monkey
	MoveSpeedBoost = { Idle = "133591929877071", Run = "131268154069931", Dance = "76215975855168" }, -- Bunny
	LaunchBooster = { Idle = "116527000708684", Run = "116927071134069", Dance = "109293602352910" }, -- Bee
	FullForce = { Idle = "", Run = "", Attack = "", Dance = "" }, -- Dragon
	QuickReload = { Idle = "79761118977634", Run = "131793614901610", Dance = "76215975855168" }, -- Dog
	ThornArmor = { Idle = "", Run = "", Dance = "" }, -- Pufferfish
	Regeneration = { Idle = "133996742170487", Run = "92449512649739", Dance = "127823569164030" }, -- Fish
	IdleStealth = { Idle = "", Run = "", Dance = "" }, -- Unicorn
} :: { [string]: PetAnimationSet }

local EMPTY_SET: PetAnimationSet = {
	Idle = "",
	Run = "",
	Dance = "",
}

function PetAnimationConfig.GetByAbilityId(abilityId: string): PetAnimationSet
	return PetAnimationConfig.Animations[abilityId] or EMPTY_SET
end

function PetAnimationConfig.GetAllAbilityIds(): { string }
	local ids = {}
	for abilityId in pairs(PetAnimationConfig.Animations) do
		table.insert(ids, abilityId)
	end
	table.sort(ids)
	return ids
end

return PetAnimationConfig
