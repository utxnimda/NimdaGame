# Nimda RPG Editor

Nimda RPG Editor is a Godot 4.6 editor plugin that provides an RPG Maker-style
database workflow without moving deterministic gameplay rules into Godot.

The editor plugin is separate from the runtime plugin registry:

```text
clients/godot/addons/nimda_rpg_editor/    Godot editor extension
clients/godot/common/plugins/             Runtime plugin infrastructure
```

## Current Slice

The first slice implements an actor database with:

- Searchable actor list and RPG-style legacy numbers.
- Add, duplicate, delete, reload, and save actions.
- Identity, class, level, presentation, and base-stat fields.
- Unsaved-change state and destructive-action confirmation.
- YAML source data, JSON Schema validation, and generated runtime JSON.
- Duplicate ID and level-range validation.
- Atomic YAML replacement through the Python data tool.

The authored source is:

```text
data/genres/turn_rpg/actors.yaml
```

The schema is:

```text
data/schemas/actor_database.schema.json
```

Generated Godot data is written to:

```text
clients/godot/data/generated/turn_rpg/actors.json
```

Generated data is ignored by Git and must be recreated from source data.

## Setup

Install the repository tooling once:

```powershell
python -m pip install -e "tools[dev]"
```

Validate and generate data:

```powershell
python tools/mygame_tools/validate_config.py
python tools/mygame_tools/generate_godot_data.py
```

Open the Godot project:

```powershell
godot --editor --path clients/godot
```

Select `RPG Editor` in the Godot main-screen toolbar. The plugin is enabled in
`clients/godot/project.godot`.

The editor uses the repository `.venv` Python interpreter when present and falls
back to `python` on `PATH`. Set `NIMDAGAME_PYTHON` to override the interpreter.

## Save Flow

```text
RPG Editor form
  -> temporary JSON transaction
  -> Python schema and semantic validation
  -> source-hash conflict check
  -> stage YAML, runtime JSON and rollback copy
  -> replace both outputs (restore source on runtime replacement failure)
  -> Godot reads generated JSON without regenerating
```

The Godot editor never parses YAML directly. This keeps authored data portable
for future clients, servers, and C++ tools.

## Data Contract

Actor IDs use stable lower-snake-case identifiers:

```text
actor_aster
class_adventurer
```

`legacy_id` preserves the familiar numbered database workflow but is not used
as the permanent cross-reference key.

The first actor schema includes:

- Identity: ID, legacy ID, name, nickname, and profile.
- Progression: class ID, initial level, and max level.
- Presentation: portrait, map sprite, and battle sprite paths.
- Base stats: HP, MP, attack, defense, magic attack, magic defense, agility, and luck.

## Next Milestones

1. Add class, skill, item, equipment, state, enemy, and troop databases.
2. Add typed cross-reference selectors instead of free-form ID fields.
3. Integrate Godot undo/redo and multi-record batch editing.
4. Add map registry and `TileMapLayer` event markers.
5. Add event pages, ordered event commands, switches, variables, and common events.
6. Add runtime event interpretation and a turn-based combat vertical slice.
7. Add RPG theme configuration, playtest, validation, and build controls.


## Implementation boundaries

The screen, actor model, reusable form and data-tool adapter are separate modules.
See [development conventions](development.md) for extension points, save guarantees,
style rules and validation commands.
