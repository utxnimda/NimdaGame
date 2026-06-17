# Plugin System

NimdaGame uses runtime gameplay and tooling plugins, not Godot editor plugins.

The goal is to let features come from different implementation technologies while still using one contract:

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

## Registry

The Godot autoload is:

```text
PluginRegistry="*res://common/plugins/plugin_registry.gd"
```

Enabled plugins are listed in:

```text
game/plugins/enabled_plugins.json
```

The file may contain an empty list while no runtime plugins are active:

```json
{
  "schema_version": 1,
  "plugins": []
}
```

## Manifest

Minimal GDScript plugin:

```json
{
  "schema_version": 1,
  "id": "example_rules",
  "name": "Example Rules",
  "version": "0.1.0",
  "implementation": {
    "type": "gdscript",
    "entry": "res://plugins/example_rules/plugin.gd"
  },
  "capabilities": ["example.rules"],
  "hooks": {
    "example.before_action": {
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
  "hook_id": "example.before_action",
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

## Hook Naming

Use a stable namespace for hook IDs:

```text
<genre_or_module>.<event_name>
```

Examples:

```text
turn_rpg.before_damage
tactics.before_move
tower_defense.before_wave_start
idle.before_offline_progress
```

## Validation

Run:

```powershell
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/release_pipeline.py check
```

The release pipeline validates enabled plugin manifests before export.
