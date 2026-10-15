--!strict

local LauncherPreviewConfig = {
	Default = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero, Scale = 1 },
}

LauncherPreviewConfig.Normalduck = { Rotation = Vector3.new(0, 70, 0), Offset = Vector3.new(0, 0.1, 0), Scale = 1 }
LauncherPreviewConfig.Kingduck = { Rotation = Vector3.new(0, 125, 0), Offset = Vector3.new(0, 0.15, 0), Scale = 1 }
LauncherPreviewConfig.Witchduck = { Rotation = Vector3.new(0, 25, 0), Offset = Vector3.new(0, 0.1, 0), Scale = 1 }
LauncherPreviewConfig.Drakeduck = { Rotation = Vector3.new(0, 40, 0), Offset = Vector3.new(0, 0.1, 0), Scale = 1 }
LauncherPreviewConfig.Shielduck = { Rotation = Vector3.new(0, 30, 0), Offset = Vector3.new(0, 0.1, 0), Scale = 1 }

function LauncherPreviewConfig.Get(launcherId: string): { Rotation: Vector3, Offset: Vector3, Scale: number }
	return LauncherPreviewConfig[launcherId] or LauncherPreviewConfig.Default
end

return LauncherPreviewConfig
