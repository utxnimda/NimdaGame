# NimdaGame

Languages: English | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

NimdaGame is a reusable game framework for lightweight RPG-like projects. The current client is Godot-based, but the repository is organized so future clients do not have to use Godot:

- Turn-based RPG
- Simple real-time RPG and survivor-like action games
- Tactics games
- Tower defense games
- Incremental or idle games

The repository is organized as a monorepo for reuse rather than for one standalone game. Shared C++ gameplay code, clients, servers, protocol schemas, data tooling, and build tooling live at stable paths. Each game genre owns its own package directory.

See [docs/repository_layout.md](docs/repository_layout.md) for the directory contract.
See [docs/architecture.md](docs/architecture.md) for layer boundaries.
See [docs/client_server_architecture.md](docs/client_server_architecture.md) for the long-term client/server layout.
See [docs/plugin_system.md](docs/plugin_system.md) for the runtime plugin contract.

## Layer Model

- Clients handle presentation, input, audio, UI, local prediction, and platform integration. The current client lives under `clients/godot/`.
- A pure C++ core owns deterministic gameplay simulation, including combat rules, units, skills, buffs, grids, economy, RNG, and saves. It is shared by clients, servers, tests, and tools.
- Servers live under `servers/` and are intended to use C++ services plus an embedded script layer.
- Protocol schemas live under `protocol/` so clients and servers share one message version.
- Python tools validate source data, generate runtime JSON, and run offline simulations or balance reports.
- Runtime plugins can be implemented with GDScript, C++ GDExtension classes, or external scripts behind one hook contract.

## Repository Layout

```text
clients/godot/       Current Godot client project
clients/native/      Reserved for a future native client
clients/web/         Reserved for a future web client
servers/             Server-side C++ services and scripts
protocol/            Client/server schemas and generated bindings
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
clients/godot/app/scenes/main.tscn
```

This scene is a lightweight framework shell. Gameplay demos and UI generation experiments have been removed so the repository can settle around reusable structure first.

## Initial Workflow

1. Author shared data under `data/common/` and genre-specific data under `data/genres/<genre>/`.
2. Validate and generate runtime JSON with Python tools under `tools/`.
3. Load generated JSON from `clients/godot/data/generated/`.
4. Call C++ gameplay simulation through the Godot binding layer.
5. Present the result through Godot scenes in `clients/godot/genres/<genre>/`.

## Release Pipeline

```powershell
python tools/mygame_tools/release_pipeline.py plan
python tools/mygame_tools/release_pipeline.py check
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/release_pipeline.py notes --version 0.1.0
```

Real export requires local Godot export presets. See [docs/release_pipeline.md](docs/release_pipeline.md).

## RPG Editor

The Godot client includes an enabled `Nimda RPG Editor` plugin. The first slice provides an RPG Maker-style actor database backed by YAML source data, JSON Schema validation, and generated runtime JSON.

```powershell
python -m pip install -e "tools[dev]"
godot --editor --path clients/godot
```

See [docs/rpg_editor.md](docs/rpg_editor.md) for the editor workflow and roadmap.

## Current Status

The repository now contains the reusable project structure, runtime plugin registry, the first RPG editor database slice, working data validation and generation, a C++ core scaffold, a Godot GDExtension scaffold, and release tooling. The next editor milestone is the class and skill databases with typed cross-reference fields.
