# Plugin System

NimdaGame uses runtime gameplay plugins, not Godot editor plugins.

The goal is to let gameplay features come from different implementation technologies while still using one contract:

- GDScript plugin
- C++ GDExtension plugin
- External script adapter, mainly for editor-time tools and experiments

## Contract

Every runtime plugin must provide these methods:

```gdscript
func setup(manifest: Dictionary, config: Dictionary) -> void
func get_plugin_info() -> Dictionary
func handle_hook(hook_id: String, payload: Dictionary) -> Dictionary
```

`handle_hook()` must return a `Dictionary`. If a plugin does not need to change anything, return the original payload.

## Manifest

Each plugin has a `plugin.json` file. Enabled plugins are listed in:

```text
game/plugins/enabled_plugins.json
```

Minimal GDScript plugin:

```json
{
  "schema_version": 1,
  "id": "turn_rpg_training_rules",
  "name": "Turn RPG Training Rules",
  "version": "0.1.0",
  "implementation": {
    "type": "gdscript",
    "entry": "res://plugins/turn_rpg_training_rules/plugin.gd"
  },
  "capabilities": ["turn_rpg.rules"],
  "hooks": {
    "turn_rpg.before_damage": {
      "priority": 100
    }
  },
  "config": {}
}
```

## Implementation Types

### GDScript

Use this for fast gameplay experiments and Godot-facing logic.

```json
"implementation": {
  "type": "gdscript",
  "entry": "res://plugins/my_plugin/plugin.gd"
}
```

The script is loaded and instantiated by `PluginRegistry`.

### Native C++ GDExtension

Use this for performance-sensitive or shared runtime logic.

```json
"implementation": {
  "type": "native",
  "class_name": "NimdaNativeRulePlugin"
}
```

The C++ class must be registered with Godot through GDExtension and implement the same three methods. `PluginRegistry` creates it through `ClassDB.instantiate()`.

### External Script

Use this for editor-only tooling, local experiments, balance scripts, or build-time adapters.

```json
"implementation": {
  "type": "external_script",
  "runtime": "editor_only",
  "command": "python",
  "args": ["tools/plugins/my_plugin.py"],
  "append_context_json": true
}
```

External script plugins should normally stay `editor_only`. Runtime external processes are not portable to Web or most mobile exports.

The script receives one JSON argument when `append_context_json` is true:

```json
{
  "hook_id": "turn_rpg.before_damage",
  "payload": {},
  "config": {},
  "plugin": {}
}
```

It should print a JSON object. If the object has a `payload` field, that field becomes the returned payload.

## Hook Order

Hooks are ordered by ascending `priority`.

```text
priority 50 -> priority 100 -> priority 200
```

Plugins should avoid depending on registration order.

## Turn RPG Hooks

The playable Turn RPG demo currently exposes:

### `turn_rpg.build_roster`

Called after the base unit list is created and before battle starts.

Payload:

```json
{
  "units": [],
  "log": []
}
```

### `turn_rpg.battle_started`

Called after plugins have had a chance to adjust the roster.

Payload:

```json
{
  "log": []
}
```

### `turn_rpg.before_damage`

Called after base damage and guard reduction, before HP is changed.

Payload:

```json
{
  "actor": {},
  "target": {},
  "action": {},
  "damage": 1,
  "log": []
}
```

## Current Sample

The enabled sample is:

```text
game/plugins/turn_rpg_training_rules/
```

It demonstrates a GDScript rules plugin:

- Adds HP to all party members at battle start.
- Adds bonus damage to Mage `Fireball`.
- Writes plugin messages into the battle log.

## Plugin Tool Entries

Plugins can expose a Demo Hub entry with `tool_entry`:

```json
{
  "tool_entry": {
    "title": "UI Forge",
    "summary": "Generate AI prompt packs and apply UI skins.",
    "scene_path": "res://scenes/demos/ui_forge_demo.tscn",
    "order": 400,
    "loop": ["Choose a style", "Apply generated UI art"],
    "systems": ["AI provider config", "Template JSON"],
    "release_checks": ["UI Forge plugin loads"]
  }
}
```

The current UI pipeline is managed by:

```text
game/plugins/ui_forge_tool/plugin.json
```

## Validation

Run:

```powershell
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/release_pipeline.py check
```

The release pipeline validates enabled plugin manifests before export.
