# Architecture

## Goal

NimdaGame is intended to be a reusable framework for several lightweight game genres:

- Turn-based RPG
- Simple real-time RPG
- Survivor-like action game
- Tactics game
- Tower defense
- Incremental or idle game

The main engineering goal is to keep gameplay logic portable and testable while still using Godot for fast iteration on UI, scenes, animation, and tools.

## Layer Boundaries

### Godot Layer

Godot owns everything related to presentation and editor workflow:

- Scene composition
- UI screens and widgets
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

The core should expose stable data structures and deterministic APIs that can be used by Godot, command-line tools, tests, or a future server.

### Binding Layer

`bindings/godot_cpp/` is the only layer that may depend on both Godot and the C++ core.

It translates between:

- Godot `String`, `Array`, `Dictionary`, `Packed*Array`
- C++ core structs, enums, IDs, and result objects

The binding layer should stay thin. It should not contain gameplay rules.

### Python Tools Layer

Python is used for development-time automation:

- YAML validation
- JSON generation
- Data migration
- Balance simulation
- Batch combat tests
- Reports for designers

Python should not be embedded in the shipped Godot client as a gameplay runtime.

## Data Flow

```text
data/raw/*.yaml
  -> tools validate schemas and references
  -> tools generate game/data/generated/*.json
  -> Godot loads generated JSON
  -> Godot adapter passes data to C++ core
  -> C++ core returns deterministic results
  -> Godot presents result through scenes and UI
```

## Determinism

Core simulation should be deterministic when given:

- Same config version
- Same initial state
- Same command list
- Same RNG seed

This is important for tests, replays, debugging, server validation, and balance tools.

## First Vertical Slice

The first milestone should implement:

1. One YAML unit config.
2. One YAML skill config.
3. Python validation and JSON generation.
4. A C++ combat function that resolves a single attack.
5. A GDExtension bridge exposing that function to Godot.
6. A Godot scene displaying the before and after combat state.
