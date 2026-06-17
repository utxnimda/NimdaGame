# Repository Layout

This repository is organized as one Godot project plus reusable framework packages. Do not create one Godot project per genre unless platform settings or export requirements diverge sharply.

## Current Snapshot

```text
NimdaGame/
  README.md
  game/
    project.godot
    app/
      scenes/main.tscn
      scripts/main.gd
    common/
      autoload/
      plugins/
        plugin_registry.gd
        external_script_plugin.gd
      ui/
      input/
      audio/
      debug/
      resources/
    shared_assets/
      ui/
      icons/
      audio/
      fonts/
    genres/
      turn_rpg/
      survivor_arpg/
      tactics/
      tower_defense/
      idle/
    plugins/
      enabled_plugins.json
    addons/
      core_bridge/
        README.md
        core_bridge.gdextension.example
        bin/
    data/generated/
  core/
    CMakeLists.txt
    common/
      include/
      src/
    modules/
      battle/
        include/
        src/
    genres/
      turn_rpg/
      survivor_arpg/
      tactics/
      tower_defense/
      idle/
  bindings/
    godot_cpp/
  data/
    common/
    genres/
      turn_rpg/
      survivor_arpg/
      tactics/
      tower_defense/
      idle/
    schemas/
  tools/
    mygame_tools/
  docs/
  release/
  scripts/
  dist/
  third_party/
```

## Godot Project

```text
game/
  app/
    scenes/              Boot scenes and global app flow
    scripts/
  common/
    autoload/            Shared autoload services
    plugins/             Plugin registry and adapters
    ui/                  Shared UI base controls and helpers
    input/               Input mapping and command adapters
    audio/               Shared audio helpers
    debug/               Debug panels and diagnostics
    resources/           Shared Godot resources
  shared_assets/
    ui/
    icons/
    audio/
    fonts/
  genres/
    turn_rpg/
    survivor_arpg/
    tactics/
    tower_defense/
    idle/
  plugins/
  addons/
  data/generated/
```

`game/common/` is for code that multiple genres can use without importing a specific genre package.

`game/shared_assets/` is for production assets that multiple genres can use. Generated experiments and temporary imports should not live here until they are accepted as shared resources.

`game/genres/<genre>/` owns genre-specific scenes, scripts, data adapters, plugins, and assets.

## C++ Core

```text
core/
  common/                IDs, RNG, events, save model, math helpers
  modules/               Reusable systems: battle, unit, skill, status, grid, economy
  genres/
    turn_rpg/
    survivor_arpg/
    tactics/
    tower_defense/
    idle/
```

Reusable gameplay primitives should go under `core/modules/`. Genre orchestration and rule sequencing should go under `core/genres/<genre>/`.

## Data

```text
data/
  common/                Shared YAML source data
  genres/
    turn_rpg/
    survivor_arpg/
    tactics/
    tower_defense/
    idle/
  schemas/
```

Shared data should be small and intentional. If a config carries genre assumptions, keep it under that genre.

## Tools

```text
tools/
  mygame_tools/
    validate_config.py
    generate_godot_data.py
    simulate_battle.py
    balance_report.py
    validate_plugins.py
    release_pipeline.py
```

Tools should read source data from `data/` and write runtime output to `game/data/generated/`.

## Migration Rule

When adding a new feature, choose the narrowest owner:

1. Put it under a genre package if only one genre needs it.
2. Move it to `game/common/`, `core/modules/`, or `data/common/` only after a second genre needs it or the abstraction is already clear.
3. Put assets in `game/shared_assets/` only after they are accepted as reusable, not while they are still generated experiments.
