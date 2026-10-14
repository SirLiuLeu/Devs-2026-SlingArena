--!strict

local LauncherPreviewConfig = {
	Default = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.zero },
}

LauncherPreviewConfig.Normalduck = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.new(0, 0, 0) }
LauncherPreviewConfig.Kingduck = { Rotation = Vector3.new(0, 35, 0), Offset = Vector3.new(0, 0.15, 0) }
LauncherPreviewConfig.Witchduck = { Rotation = Vector3.new(0, 25, 0), Offset = Vector3.new(0, 0.1, 0) }
LauncherPreviewConfig.Drakeduck = { Rotation = Vector3.new(0, 40, 0), Offset = Vector3.new(0, 0.1, 0) }
LauncherPreviewConfig.Shielduck = { Rotation = Vector3.new(0, 30, 0), Offset = Vector3.new(0, 0.1, 0) }

function LauncherPreviewConfig.Get(launcherId: string): { Rotation: Vector3, Offset: Vector3 }
	return LauncherPreviewConfig[launcherId] or LauncherPreviewConfig.Default
end

return LauncherPreviewConfig
