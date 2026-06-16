# NimdaGame

NimdaGame is a reusable game framework for small RPG-like games, including turn-based RPGs, simple action RPGs, survivor-like games, tactics games, tower defense games, and incremental games.

The project is organized around three layers:

- Godot handles UI, scenes, input, animation, audio, debugging panels, and editor-facing workflows.
- A pure C++ core owns deterministic gameplay simulation, including combat rules, units, skills, buffs, grids, economy, RNG, and saves.
- Python tools validate YAML source data, generate runtime JSON, and run offline simulations or balance reports.
- Runtime plugins can be implemented with GDScript, C++ GDExtension classes, or external scripts behind one hook contract.
- UI Forge turns style prompts or reference-image briefs into AI prompt packs, layout templates, saved custom layouts, and slot-based skins.

See [docs/architecture.md](docs/architecture.md) for the intended boundaries.
See [docs/plugin_system.md](docs/plugin_system.md) for the runtime plugin contract.
See [docs/ui_generation_pipeline.md](docs/ui_generation_pipeline.md) for the UI generation pipeline.

## Demo Hub

The Godot project currently starts at a small Demo Hub with four categories:

1. Turn RPG
2. ARPG / Survivor
3. Tactics
4. Systems Lab / UI Forge for tower defense, idle/incremental, cards, roguelite rewards, economy, meta progression, and UI generation tools

Turn RPG has a playable battle demo. The other categories are planning entries for future playable slices.
This hub is the first build smoke test. A release build should open the hub, allow every category to be selected, and allow the Turn RPG demo to launch.

## Repository Layout

```text
game/       Godot project and presentation layer
core/       Pure C++ gameplay core, independent from Godot
bindings/   Godot GDExtension bridge and optional CLI adapters
data/       Human-authored YAML source data and schemas
tools/      Python validation, generation, and simulation tools
docs/       Architecture and design notes
game/plugins/ Runtime plugin manifests and implementations
```

## Initial Workflow

1. Edit YAML source data under `data/raw/`.
2. Validate and generate runtime JSON with Python tools under `tools/`.
3. Load generated JSON from `game/data/generated/`.
4. Call C++ gameplay simulation through `game/scripts/adapters/`.
5. Present the result through Godot scenes and UI.

## Release Pipeline

```powershell
python tools/mygame_tools/release_pipeline.py plan
python tools/mygame_tools/release_pipeline.py check
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/ui_pipeline.py validate
python tools/mygame_tools/release_pipeline.py notes --version 0.1.0
```

Real export requires local Godot export presets. See [docs/release_pipeline.md](docs/release_pipeline.md).

## Current Status

This repository currently contains the initial project structure and design documents. The first implementation milestone is a minimal vertical slice:

```text
Godot scene -> GDScript adapter -> GDExtension bridge -> C++ core combat simulation -> generated JSON config
```
