# Standard equipment model structure

Each equipment asset is one Rojo folder that becomes a `Model`; do **not** add a second wrapper folder or model. For example, Power Core, Poison, and Thunder Hammer use this exact layout:

```text
src/ReplicatedStorage/Assets/Equipment/
├── PowerCore/
│   ├── init.model.json       # { "className": "Model" }
│   └── Handle.model.json     # { "className": "Part", "properties": { ... } }
├── Poison/
│   ├── init.model.json
│   └── Handle.model.json
└── ThunderHammer/
    ├── init.model.json
    └── Handle.model.json
```

Rojo maps `PowerCore/` directly to `ReplicatedStorage.Assets.Equipment.PowerCore` (a `Model`) and maps `Handle.model.json` to its `Handle` `Part`. `Handle` should be unanchored, non-collidable, non-queryable, non-touchable, and massless when used by a system that mounts it.

**Legacy attachment note:** `EquipmentSlot1`, `EquipmentSlot2`, and `EquipmentSlot3` are no longer part of the active Launcher pawn. The current pawn template removes these legacy attachments from its runtime clone. Equipped Pet models are rendered client-side by `ClientPetController` using `Hitbox.LauncherMovementAttachment` as the follow origin; do not use the retired EquipmentSlot attachments for Pet positioning.

Before play-testing, set `StarterGui.MainHUD.ResetOnSpawn` to `false` in Studio. The shop controller also rebinds safely after a respawn as a fallback for projects that keep it enabled.
