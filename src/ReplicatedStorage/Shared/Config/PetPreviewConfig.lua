--!strict

-- Keep per-AbilityID camera overrides here; all other Pets use Default.
local PetPreviewConfig: { [string]: { Rotation: Vector3, Offset: Vector3, Scale: number } } = {
	Default = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero, Scale = 1 },
	Poison = { Rotation = Vector3.new(0, 10, -90), Offset = Vector3.zero, Scale = 1 },
}

function PetPreviewConfig.Get(abilityId: string): { Rotation: Vector3, Offset: Vector3, Scale: number }
	return PetPreviewConfig[abilityId] or PetPreviewConfig.Default
end

return PetPreviewConfig
