--!strict

local SafeZoneConfig = {}

SafeZoneConfig.StartRadius = 300
SafeZoneConfig.MinRadius = 0
SafeZoneConfig.RelocationScaleThreshold = 0.7
SafeZoneConfig.RelocationDurationSeconds = 10
SafeZoneConfig.ShrinkDurationSeconds = 10 * 60
SafeZoneConfig.GradientCylinderBaseSize = Vector3.new(SafeZoneConfig.StartRadius * 2, 100, SafeZoneConfig.StartRadius * 2)

SafeZoneConfig.Attributes = {
	CurrentRadius = "CurrentRadius",
	CurrentScale = "CurrentScale",
	CurrentCenter = "CurrentCenter",
	IsRelocating = "IsRelocating",
}

return SafeZoneConfig
