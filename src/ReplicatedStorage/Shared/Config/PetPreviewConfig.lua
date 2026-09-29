--!strict

local PetPreviewConfig = {
	Default = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero },
}

for _, petId in ipairs({ "PlasmaCannon", "Hydra", "ThunderHammer", "Medusa", "IceCrystal", "GhostFlame", "Poison", "HealthCore", "PowerCore", "Shield", "BrainBoost", "TurboModule", "LaunchBooster", "Dragon", "QuickReload", "ThornArmor", "RegenBooster", "ShadowCloak" }) do
	PetPreviewConfig[petId] = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero }
end

function PetPreviewConfig.Get(petId: string): { Rotation: Vector3, Offset: Vector3 }
	return PetPreviewConfig[petId] or PetPreviewConfig.Default
end

return PetPreviewConfig
