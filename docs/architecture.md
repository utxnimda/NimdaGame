# Architecture

## Goal

NimdaGame is a reusable framework for several lightweight game genres:

- Turn-based RPG
- Simple real-time RPG
- Survivor-like action game
- Tactics game
- Tower defense
- Incremental or idle game

The main engineering goal is to keep gameplay logic portable and testable while allowing multiple clients and C++ server services to share the same deterministic core.

## Layer Boundaries

### Client Layer

Clients own presentation and platform workflow. The current Godot client lives under `clients/godot/`.

- App boot and global flow under `clients/godot/app/`
- Shared Godot runtime helpers under `clients/godot/common/`
- Per-genre Godot scenes and scripts under `clients/godot/genres/<genre>/`
- Shared Godot assets under `clients/godot/shared_assets/`
- Input
- Animation, VFX, SFX, and music
- Camera behavior
- Debug panels and developer tools
- Loading generated runtime config
- Calling the C++ core through adapters

Client scripts should avoid owning final gameplay rules. They may orchestrate flow, display state, run prediction, and translate user intent into core requests.

### Server Layer

Servers live under `servers/` and are intended to use C++ plus an embedded script layer.

They own:

- Network entry points
- Authoritative rooms and sessions
- Tick/update scheduling
- State synchronization
- Persistence and service integration
- Server-only script orchestration

Server code should call shared deterministic logic from `core/` instead of duplicating gameplay rules.

### C++ Core Layer

The C++ core is a pure gameplay library. It should not include Godot headers and should not depend on Godot types.

It owns:

- Combat simulation
- Unit stats and derived attributes
- Skills and effects
- Buffs, debuffs, status effects
- Grid and pathfinding logic
- Economy and incremental formulas
- Deterministic RNG
- Save-state model
- Replay-friendly command processing

Shared infrastructure belongs in `core/common/`. Reusable gameplay systems belong in `core/modules/`. Per-genre orchestration belongs in `core/genres/<genre>/`.

### Protocol Layer

`protocol/` owns client/server message schemas and generated bindings.

Protocol definitions should not live inside a single client or server implementation. This keeps all packages aligned on one message version.

### Binding Layer

`bindings/godot_cpp/` is the only layer that may depend on both Godot and the C++ core.

It translates between:

- Godot `String`, `Array`, `Dictionary`, `Packed*Array`
- C++ core structs, enums, IDs, and result objects

The binding layer should stay thin. It should not contain gameplay rules.

### Plugin Layer

Godot runtime plugins live under `clients/godot/plugins/` and are loaded by the Godot autoload `PluginRegistry`.

Plugins can be implemented as:

- GDScript objects
- C++ GDExtension classes registered with Godot
- External script adapters for editor-time tooling

All implementations must expose the same hook contract:

```text
setup(manifest, config)
get_plugin_info()
handle_hook(hook_id, payload)
```

The plugin layer may modify payloads only through explicit hooks. Core rules that must be deterministic and portable should eventually move into `core/`, with GDScript plugins serving as prototype or adapter code.

### Python Tools Layer

Python is used for development-time automation:

- YAML validation
- JSON generation
- Data migration
- Balance simulation
- Batch combat tests
- Reports for designers
- Release checks and packaging helpers

Python should not be embedded in the shipped Godot client as a gameplay runtime.

## Data Flow

```text
data/common/*.yaml
data/genres/<genre>/*.yaml
  -> tools validate schemas and references
  -> tools generate package-owned runtime data
  -> clients and servers load generated data
  -> adapters pass data to C++ core
  -> C++ core returns deterministic results
  -> clients present results and servers synchronize authoritative state
```

## Determinism

Core simulation should be deterministic when given:

- Same config version
- Same initial state
- Same command list
- Same RNG seed

This is important for tests, replays, debugging, server validation, and balance tools.

## First Vertical Slice

The next milestone should implement one vertical slice inside a genre package:

1. One shared or genre-specific YAML config.
2. Python validation and JSON generation.
3. A C++ gameplay function that resolves one deterministic action.
4. A GDExtension bridge exposing that function to Godot.
5. A Godot scene under `clients/godot/genres/<genre>/scenes/` displaying before and after state.

## Implementation Conventions

See [development conventions](development.md) for the implemented editor/data-tool
boundaries, database extension steps, coding style and automated checks.
