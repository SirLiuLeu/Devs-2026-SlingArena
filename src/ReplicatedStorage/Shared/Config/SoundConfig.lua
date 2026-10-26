--!strict

-- Static sound metadata only. Fill SoundId values after the audio assets are finalized.
-- Pitch is mapped to Sound.PlaybackSpeed by SoundManager.
local SoundConfig = {
	-- Combat
	SFX_Death = { Folder = "Combat", SoundId = "", Volume = 0.9, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
	SFX_Hurt = { Folder = "Combat", SoundId = "", Volume = 0.8, Pitch = 1, Spatial = false, MaxPoolSize = 4, MaxConcurrent = 2 },
	SFX_Kill = { Folder = "Combat", SoundId = "", Volume = 0.85, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
	SFX_PlasmaCannonFire = { Folder = "Combat", SoundId = "", Volume = 0.75, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 160, EmitterSize = 5, MaxPoolSize = 6, MaxConcurrent = 4 },
	SFX_ProjectileHit = { Folder = "Combat", SoundId = "", Volume = 0.8, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 120, EmitterSize = 4, MaxPoolSize = 8, MaxConcurrent = 5 },
	SFX_SlowBlasterFire = { Folder = "Combat", SoundId = "", Volume = 0.7, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 140, EmitterSize = 4, MaxPoolSize = 6, MaxConcurrent = 4 },
	SFX_StatusBurn = { Folder = "Combat", SoundId = "", Volume = 0.65, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 4, MaxConcurrent = 2 },
	SFX_StatusPoison = { Folder = "Combat", SoundId = "", Volume = 0.65, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 4, MaxConcurrent = 2 },
	SFX_StatusStun = { Folder = "Combat", SoundId = "", Volume = 0.7, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 4, MaxConcurrent = 2 },

	-- Gameplay
	SFX_ChargeLoop = { Folder = "Gameplay", SoundId = "", Volume = 0.45, Pitch = 1, Looped = true, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 5, RollOffMaxDistance = 90, EmitterSize = 3, MaxPoolSize = 24, MaxConcurrent = 24 },
	SFX_Food_Consume = { Folder = "Gameplay", SoundId = "", Volume = 0.7, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 5, RollOffMaxDistance = 65, EmitterSize = 3, MaxPoolSize = 6, MaxConcurrent = 4 },
	SFX_Food_Destroy = { Folder = "Gameplay", SoundId = "", Volume = 0.8, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 100, EmitterSize = 4, MaxPoolSize = 8, MaxConcurrent = 5 },
	SFX_Food_Hit = { Folder = "Gameplay", SoundId = "", Volume = 0.55, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 5, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 8, MaxConcurrent = 4 },
	SFX_ImpactLauncher = { Folder = "Gameplay", SoundId = "", Volume = 0.9, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 160, EmitterSize = 5, MaxPoolSize = 8, MaxConcurrent = 5 },
	SFX_LaunchRelease = { Folder = "Gameplay", SoundId = "", Volume = 0.75, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 7, RollOffMaxDistance = 125, EmitterSize = 4, MaxPoolSize = 8, MaxConcurrent = 5 },
	SFX_TrapHit = { Folder = "Gameplay", SoundId = "", Volume = 0.8, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 7, RollOffMaxDistance = 105, EmitterSize = 4, MaxPoolSize = 6, MaxConcurrent = 4 },

	-- Match
	SFX_LevelUp = { Folder = "Match", SoundId = "", Volume = 0.8, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
	SFX_RoundStart = { Folder = "Match", SoundId = "", Volume = 0.85, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
	SFX_Victory = { Folder = "Match", SoundId = "", Volume = 0.9, Pitch = 1, Spatial = false, MaxPoolSize = 2, MaxConcurrent = 1 },

	-- UI
	SFX_Success = { Folder = "UI", SoundId = "", Volume = 0.7, Pitch = 1, Spatial = false, MaxPoolSize = 4, MaxConcurrent = 2 },
	SFX_UI_Click = { Folder = "UI", SoundId = "", Volume = 0.45, Pitch = 1, Spatial = false, MaxPoolSize = 6, MaxConcurrent = 3 },
}

return SoundConfig
