--!strict

local PetPreviewConfig = {
	Default = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero, Scale = 1 },
}

for _, petId in ipairs({ "PlasmaCannon", "Hydra", "ThunderHammer", "IceCrystal", "GhostFlame", "Poison", "HealthCore", "PowerCore", "Shield", "BrainBoost", "TurboModule", "LaunchBooster", "Dragon", "QuickReload", "ThornArmor", "RegenBooster", "ShadowCloak" }) do
	PetPreviewConfig[petId] = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero, Scale = 1 }
end

for _, petId in ipairs({ "Medusa" }) do
	PetPreviewConfig[petId] = { Rotation = Vector3.new(0, 10, -90), Offset = Vector3.zero, Scale = 1 }
end

function PetPreviewConfig.Get(petId: string): { Rotation: Vector3, Offset: Vector3, Scale: number }
	return PetPreviewConfig[petId] or PetPreviewConfig.Default
end

return PetPreviewConfig
