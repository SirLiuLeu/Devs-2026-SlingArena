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
	PlasmaCannon = { Idle = "", Run = "", Attack = "", Dance = "" },
	Hydra = { Idle = "", Run = "", Dance = "" },
	ThunderHammer = { Idle = "", Run = "", Dance = "" },
	Medusa = { Idle = "", Run = "", Dance = "" },
	IceCrystal = { Idle = "", Run = "", Dance = "" },
	GhostFlame = { Idle = "", Run = "", Dance = "" },
	Poison = { Idle = "", Run = "", Dance = "" },
	HealthCore = { Idle = "", Run = "", Dance = "" },
	PowerCore = { Idle = "", Run = "", Dance = "" },
	Shield = { Idle = "", Run = "", Dance = "" },
	BrainBoost = { Idle = "", Run = "", Dance = "" },
	TurboModule = { Idle = "", Run = "", Dance = "" },
	LaunchBooster = { Idle = "", Run = "", Dance = "" },
	Dragon = { Idle = "", Run = "", Attack = "", Dance = "" },
	QuickReload = { Idle = "", Run = "", Dance = "" },
	ThornArmor = { Idle = "", Run = "", Dance = "" },
	RegenBooster = { Idle = "", Run = "", Dance = "" },
	ShadowCloak = { Idle = "", Run = "", Dance = "" },
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
