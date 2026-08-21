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

Rojo maps `PowerCore/` directly to `ReplicatedStorage.Assets.Equipment.PowerCore` (a `Model`) and maps `Handle.model.json` to its `Handle` `Part`. `Handle` is the primary attachment part used by `PlayerService`; it should be unanchored, non-collidable, non-queryable, non-touchable, and massless. The server clones these models only in Launcher mode and welds `Handle` to the corresponding `Player.Hitbox.EquipmentSlot1`, `EquipmentSlot2`, or `EquipmentSlot3` attachment.

Before play-testing, set `StarterGui.MainHUD.ResetOnSpawn` to `false` in Studio. The shop controller also rebinds safely after a respawn as a fallback for projects that keep it enabled.
