--!strict

-- Fill animation IDs per Pet rig in Studio.
-- Each Pet can have a different rig, so animation assets are configured per PetId.
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
	PlasmaCannon = { Idle = "", Run = "", Attack = "", Dance = "" }, -- Octopus
	Titan = { Idle = "", Run = "", Dance = "" }, -- Hydra ability
	ThunderHammer = { Idle = "", Run = "", Dance = "" }, -- Yeti
	Medusa = { Idle = "", Run = "", Dance = "" }, -- Snake
	IceCrystal = { Idle = "", Run = "70654849990565", Dance = "114087130920750" }, -- Penguin
	GhostFlame = { Idle = "", Run = "", Dance = "" }, -- Phoenix
	Poison = { Idle = "", Run = "", Dance = "" }, -- Caterpillar
	HealthCore = { Idle = "71267273020156", Run = "127885756125728", Dance = "72877466735478" }, -- Pig
	PowerCore = { Idle = "132080786710960", Run = "81491739793302", Dance = "86177773442474" }, -- Panda
	Shield = { Idle = "79761118977634", Run = "131793614901610", Dance = "76215975855168" }, -- Elephant
	BrainBoost = { Idle = "132080786710960", Run = "81491739793302", Dance = "86177773442474" }, -- Monkey
	TurboModule = { Idle = "133591929877071", Run = "131268154069931", Dance = "76215975855168" }, -- Bunny
	LaunchBooster = { Idle = "116527000708684", Run = "116927071134069", Dance = "109293602352910" }, -- Bee
	Dragon = { Idle = "", Run = "", Attack = "", Dance = "" }, -- Dragon
	QuickReload = { Idle = "79761118977634", Run = "131793614901610", Dance = "76215975855168" }, -- Dog
	ThornArmor = { Idle = "", Run = "", Dance = "" }, -- Pufferfish
	RegenBooster = { Idle = "133996742170487", Run = "92449512649739", Dance = "127823569164030" }, -- Fish
	ShadowCloak = { Idle = "", Run = "", Dance = "" }, -- Unicorn
} :: { [string]: PetAnimationSet }

local EMPTY_SET: PetAnimationSet = {
	Idle = "",
	Run = "",
	Dance = "",
}

function PetAnimationConfig.GetById(petId: string, abilityId: string?): PetAnimationSet
	return PetAnimationConfig.Animations[petId]
		or (abilityId and PetAnimationConfig.Animations[abilityId])
		or EMPTY_SET
end

function PetAnimationConfig.GetAllIds(): { string }
	local ids = {}
	for petId in pairs(PetAnimationConfig.Animations) do
		table.insert(ids, petId)
	end
	table.sort(ids)
	return ids
end

return PetAnimationConfig
