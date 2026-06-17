# Architecture

## Goal

NimdaGame is a reusable framework for several lightweight game genres:

- Turn-based RPG
- Simple real-time RPG
- Survivor-like action game
- Tactics game
- Tower defense
- Incremental or idle game

The main engineering goal is to keep gameplay logic portable and testable while still using Godot for fast iteration on presentation, tooling, and game flow.

## Layer Boundaries

### Godot Layer

Godot owns presentation and editor workflow:

- App boot and global flow under `game/app/`
- Shared runtime helpers under `game/common/`
- Per-genre scenes and scripts under `game/genres/<genre>/`
- Shared assets under `game/shared_assets/`
- Input
- Animation, VFX, SFX, and music
- Camera behavior
- Debug panels and developer tools
- Loading generated runtime config
- Calling the C++ core through adapters

Godot scripts should avoid owning final gameplay rules. They may orchestrate flow, display state, and translate user intent into core requests.

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

### Binding Layer

`bindings/godot_cpp/` is the only layer that may depend on both Godot and the C++ core.

It translates between:

- Godot `String`, `Array`, `Dictionary`, `Packed*Array`
- C++ core structs, enums, IDs, and result objects

The binding layer should stay thin. It should not contain gameplay rules.

### Plugin Layer

Runtime plugins live under `game/plugins/` and are loaded by the Godot autoload `PluginRegistry`.

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
  -> tools generate game/data/generated/*.json
  -> Godot loads generated JSON
  -> Godot adapter passes data to C++ core
  -> C++ core returns deterministic results
  -> Godot presents result through game/genres/<genre> scenes
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
5. A Godot scene under `game/genres/<genre>/scenes/` displaying before and after state.
