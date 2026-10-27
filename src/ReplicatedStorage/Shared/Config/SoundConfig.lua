--!strict

-- Static sound metadata only. Fill SoundId values after the audio assets are finalized.
-- Pitch is mapped to Sound.PlaybackSpeed by SoundManager.

local SoundConfig: { [string]: { [string]: any } } = {
    -- Combat
    SFX_Death = { Folder = "Combat", SoundId = "76181657755045", Volume = 0.9, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
    SFX_Hurt = { Folder = "Combat", SoundId = "102407777253627", Volume = 0.8, Pitch = 1, Spatial = false, MaxPoolSize = 4, MaxConcurrent = 2 },
    SFX_Kill = { Folder = "Combat", SoundId = "115441354803804", Volume = 0.85, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
    SFX_PlasmaCannonFire = { Folder = "Combat", SoundId = "139756571552767", Volume = 0.75, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 160, EmitterSize = 5, MaxPoolSize = 6, MaxConcurrent = 4 },
    SFX_ProjectileHit = { Folder = "Combat", SoundId = "119634095570575", Volume = 0.8, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 120, EmitterSize = 4, MaxPoolSize = 8, MaxConcurrent = 5 },
    SFX_SlowBlasterFire = { Folder = "Combat", SoundId = "118429257593947", Volume = 0.7, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 140, EmitterSize = 4, MaxPoolSize = 6, MaxConcurrent = 4 },
    SFX_StatusBurn = { Folder = "Combat", SoundId = "118045655715268", Volume = 0.65, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 4, MaxConcurrent = 2 },
    SFX_StatusPoison = { Folder = "Combat", SoundId = "131115295617292", Volume = 0.65, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 4, MaxConcurrent = 2 },
    SFX_StatusStun = { Folder = "Combat", SoundId = "125047117747958", Volume = 0.7, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 4, MaxConcurrent = 2 },

    -- Gameplay
    SFX_ChargeLoop = { Folder = "Gameplay", SoundId = "95964131812459", Volume = 0.45, Pitch = 1, Looped = true, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 5, RollOffMaxDistance = 90, EmitterSize = 3, MaxPoolSize = 48, MaxConcurrent = 48 },
    SFX_Food_Consume = { Folder = "Gameplay", SoundId = "74818610327853", Volume = 0.7, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 5, RollOffMaxDistance = 65, EmitterSize = 3, MaxPoolSize = 6, MaxConcurrent = 4 },
    SFX_Food_Destroy = { Folder = "Gameplay", SoundId = "81665397063399", Volume = 0.8, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 6, RollOffMaxDistance = 100, EmitterSize = 4, MaxPoolSize = 8, MaxConcurrent = 5 },
    SFX_Food_Hit = { Folder = "Gameplay", SoundId = "103428820612251", Volume = 0.55, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 5, RollOffMaxDistance = 85, EmitterSize = 3, MaxPoolSize = 8, MaxConcurrent = 4 },
    SFX_ImpactLauncher = { Folder = "Gameplay", SoundId = "121182352079090", Volume = 0.9, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 8, RollOffMaxDistance = 160, EmitterSize = 5, MaxPoolSize = 8, MaxConcurrent = 5 },
    SFX_LaunchRelease = { Folder = "Gameplay", SoundId = "116279018525523", Volume = 0.75, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 7, RollOffMaxDistance = 125, EmitterSize = 4, MaxPoolSize = 8, MaxConcurrent = 5 },
    SFX_TrapHit = { Folder = "Gameplay", SoundId = "87621625479450", Volume = 0.8, Pitch = 1, Spatial = true, RollOffMode = "InverseTapered", RollOffMinDistance = 7, RollOffMaxDistance = 105, EmitterSize = 4, MaxPoolSize = 6, MaxConcurrent = 4 },

    -- Match
    SFX_LevelUp = { Folder = "Match", SoundId = "79082668079454", Volume = 0.8, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
    SFX_RoundStart = { Folder = "Match", SoundId = "95951190634430", Volume = 0.85, Pitch = 1, Spatial = false, MaxPoolSize = 3, MaxConcurrent = 1 },
    SFX_Victory = { Folder = "Match", SoundId = "98727584886142", Volume = 0.9, Pitch = 1, Spatial = false, MaxPoolSize = 2, MaxConcurrent = 1 },

    -- UI
    SFX_Success = { Folder = "UI", SoundId = "124752357882176", Volume = 0.7, Pitch = 1, Spatial = false, MaxPoolSize = 4, MaxConcurrent = 2 },
    SFX_UI_Click = { Folder = "UI", SoundId = "81234820165126", Volume = 0.45, Pitch = 1, Spatial = false, MaxPoolSize = 6, MaxConcurrent = 3 },
}

return SoundConfig
