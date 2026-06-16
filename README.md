# NimdaGame

NimdaGame is a reusable game framework for small RPG-like games, including turn-based RPGs, simple action RPGs, survivor-like games, tactics games, tower defense games, and incremental games.

The project is organized around three layers:

- Godot handles UI, scenes, input, animation, audio, debugging panels, and editor-facing workflows.
- A pure C++ core owns deterministic gameplay simulation, including combat rules, units, skills, buffs, grids, economy, RNG, and saves.
- Python tools validate YAML source data, generate runtime JSON, and run offline simulations or balance reports.

See [docs/architecture.md](docs/architecture.md) for the intended boundaries.

## Repository Layout

```text
game/       Godot project and presentation layer
core/       Pure C++ gameplay core, independent from Godot
bindings/   Godot GDExtension bridge and optional CLI adapters
data/       Human-authored YAML source data and schemas
tools/      Python validation, generation, and simulation tools
docs/       Architecture and design notes
```

## Initial Workflow

1. Edit YAML source data under `data/raw/`.
2. Validate and generate runtime JSON with Python tools under `tools/`.
3. Load generated JSON from `game/data/generated/`.
4. Call C++ gameplay simulation through `game/scripts/adapters/`.
5. Present the result through Godot scenes and UI.

## Current Status

This repository currently contains the initial project structure and design documents. The first implementation milestone is a minimal vertical slice:

```text
Godot scene -> GDScript adapter -> GDExtension bridge -> C++ core combat simulation -> generated JSON config
```
