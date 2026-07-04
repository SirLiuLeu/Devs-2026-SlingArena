--!strict

local SafeZoneConfig = {}

SafeZoneConfig.StartRadius = 600
SafeZoneConfig.MinRadius = 0
SafeZoneConfig.RelocationScaleThreshold = 0.7
SafeZoneConfig.RelocationDurationSeconds = 10
SafeZoneConfig.ShrinkDurationSeconds = 10 * 60
SafeZoneConfig.GradientCylinderBaseSize = Vector3.new(600, 100, 600)

SafeZoneConfig.Attributes = {
	CurrentRadius = "CurrentRadius",
	CurrentScale = "CurrentScale",
	CurrentCenter = "CurrentCenter",
	IsRelocating = "IsRelocating",
}

return SafeZoneConfig
