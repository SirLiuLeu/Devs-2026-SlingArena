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
	PlasmaCannon = { Idle = "", Run = "", Attack = "", Dance = "" } -- Octopus,
	Hydra = { Idle = "", Run = "", Dance = "" } -- Hydra,
	ThunderHammer = { Idle = "", Run = "", Dance = "" } -- Yeti,
	Medusa = { Idle = "", Run = "", Dance = "" } -- Snake,
	IceCrystal = { Idle = "", Run = "", Dance = "" } -- Penguin,
	GhostFlame = { Idle = "", Run = "", Dance = "" } -- Phoenix,
	Poison = { Idle = "", Run = "", Dance = "" } -- Caterpillar,
	HealthCore = { Idle = "", Run = "", Dance = "" } -- Cow,
	PowerCore = { Idle = "", Run = "", Dance = "" } -- Elephant,
	Shield = { Idle = "", Run = "", Dance = "" } -- Panda,
	BrainBoost = { Idle = "", Run = "", Dance = "" } -- Monkey,
	TurboModule = { Idle = "", Run = "", Dance = "" } -- Bunny,
	LaunchBooster = { Idle = "", Run = "", Dance = "" } -- Bee,
	Dragon = { Idle = "", Run = "", Attack = "", Dance = "" } -- Dragon,
	QuickReload = { Idle = "", Run = "", Dance = "" } -- Dog,
	ThornArmor = { Idle = "", Run = "", Dance = "" } -- Pufferfish,
	RegenBooster = { Idle = "", Run = "", Dance = "" } -- Fish,
	ShadowCloak = { Idle = "", Run = "", Dance = "" } -- Unicorn,
} :: { [string]: PetAnimationSet }

local EMPTY_SET: PetAnimationSet = {
	Idle = "",
	Run = "",
	Dance = "",
}

function PetAnimationConfig.GetById(petId: string): PetAnimationSet
	return PetAnimationConfig.Animations[petId] or EMPTY_SET
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
