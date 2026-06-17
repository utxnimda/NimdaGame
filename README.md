# NimdaGame

NimdaGame is a reusable Godot-based game framework for lightweight RPG-like projects:

- Turn-based RPG
- Simple real-time RPG and survivor-like action games
- Tactics games
- Tower defense games
- Incremental or idle games

The repository is organized for reuse rather than for one standalone game. Shared runtime code, shared assets, data tooling, and build tooling live at stable paths. Each game genre owns its own package directory.

See [docs/repository_layout.md](docs/repository_layout.md) for the directory contract.
See [docs/architecture.md](docs/architecture.md) for layer boundaries.
See [docs/plugin_system.md](docs/plugin_system.md) for the runtime plugin contract.

## Layer Model

- Godot handles app flow, scenes, UI presentation, input, animation, audio, debug panels, and editor-facing workflows.
- A pure C++ core owns deterministic gameplay simulation, including combat rules, units, skills, buffs, grids, economy, RNG, and saves.
- Python tools validate source data, generate runtime JSON, and run offline simulations or balance reports.
- Runtime plugins can be implemented with GDScript, C++ GDExtension classes, or external scripts behind one hook contract.

## Repository Layout

```text
game/app/            Godot boot scene and global app flow
game/common/         Shared Godot runtime code used by multiple genres
game/shared_assets/  Shared art, audio, fonts, icons, and other reusable assets
game/genres/         Per-genre Godot packages
game/plugins/        Runtime plugin manifests and implementations
core/common/         Shared C++ gameplay infrastructure
core/modules/        Reusable gameplay modules
core/genres/         Per-genre C++ gameplay orchestration
bindings/            Godot GDExtension bridge and optional CLI adapters
data/common/         Shared source data
data/genres/         Per-genre source data
data/schemas/        JSON schemas for authored data and manifests
tools/               Python validation, generation, simulation, and release tools
docs/                Architecture and workflow notes
release/             Release target config, checklists, and note templates
```

## Current Godot Entry

The Godot project starts at:

```text
game/app/scenes/main.tscn
```

This scene is a lightweight framework shell. Gameplay demos and UI generation experiments have been removed so the repository can settle around reusable structure first.

## Initial Workflow

1. Author shared data under `data/common/` and genre-specific data under `data/genres/<genre>/`.
2. Validate and generate runtime JSON with Python tools under `tools/`.
3. Load generated JSON from `game/data/generated/`.
4. Call C++ gameplay simulation through the Godot binding layer.
5. Present the result through Godot scenes in `game/genres/<genre>/`.

## Release Pipeline

```powershell
python tools/mygame_tools/release_pipeline.py plan
python tools/mygame_tools/release_pipeline.py check
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/release_pipeline.py notes --version 0.1.0
```

Real export requires local Godot export presets. See [docs/release_pipeline.md](docs/release_pipeline.md).

## Current Status

This repository currently contains the reusable project structure, plugin registry, data tooling stubs, C++ core scaffold, Godot GDExtension scaffold, and release tooling. The next implementation milestone should add one vertical slice inside a genre package instead of placing gameplay under generic demo directories.
