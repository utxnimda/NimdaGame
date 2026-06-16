extends Node

const ExternalScriptPlugin = preload("res://scripts/plugins/external_script_plugin.gd")

const ENABLED_PLUGINS_PATH := "res://plugins/enabled_plugins.json"
const IMPLEMENTATION_GDSCRIPT := "gdscript"
const IMPLEMENTATION_NATIVE := "native"
const IMPLEMENTATION_EXTERNAL_SCRIPT := "external_script"

var _plugins_by_id: Dictionary = {}
var _hook_entries: Dictionary = {}
var _load_errors: Array[String] = []


func _ready() -> void:
	reload_plugins()


func reload_plugins(path: String = ENABLED_PLUGINS_PATH) -> void:
	_plugins_by_id.clear()
	_hook_entries.clear()
	_load_errors.clear()

	var enabled_config: Dictionary = _read_json_dictionary(path)
	var plugin_paths: Array = enabled_config.get("plugins", [])
	for manifest_path_value in plugin_paths:
		var manifest_path := String(manifest_path_value)
		_load_manifest(manifest_path)

	for hook_id in _hook_entries.keys():
		var entries: Array = _hook_entries[hook_id]
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["priority"]) < int(b["priority"])
		)
		_hook_entries[hook_id] = entries


func run_hook(hook_id: String, payload: Dictionary = {}) -> Dictionary:
	var current_payload: Dictionary = payload.duplicate(true)
	var entries: Array = _hook_entries.get(hook_id, [])
	for entry in entries:
		var plugin: Object = entry["plugin"]
		var plugin_id := String(entry["plugin_id"])
		if not plugin.has_method("handle_hook"):
			_load_errors.append("Plugin %s does not implement handle_hook." % plugin_id)
			continue

		var result: Variant = plugin.call("handle_hook", hook_id, current_payload.duplicate(true))
		if result is Dictionary:
			current_payload = result
		else:
			_load_errors.append("Plugin %s returned a non-Dictionary payload for hook %s." % [plugin_id, hook_id])

	return current_payload


func get_loaded_plugins() -> Array:
	var result: Array = []
	for plugin_id in _plugins_by_id.keys():
		var record: Dictionary = _plugins_by_id[plugin_id]
		result.append(record["manifest"])
	return result


func get_loaded_plugin_ids() -> Array[String]:
	var ids: Array[String] = []
	for plugin_id in _plugins_by_id.keys():
		ids.append(String(plugin_id))
	ids.sort()
	return ids


func get_load_errors() -> Array[String]:
	return _load_errors.duplicate()


func _load_manifest(manifest_path: String) -> void:
	var manifest: Dictionary = _read_json_dictionary(manifest_path)
	if manifest.is_empty():
		_load_errors.append("Plugin manifest is empty or missing: %s" % manifest_path)
		return

	var plugin_id := String(manifest.get("id", ""))
	if plugin_id.is_empty():
		_load_errors.append("Plugin manifest missing id: %s" % manifest_path)
		return
	if _plugins_by_id.has(plugin_id):
		_load_errors.append("Duplicate plugin id: %s" % plugin_id)
		return

	var implementation: Dictionary = manifest.get("implementation", {})
	var instance: Object = _create_plugin_instance(plugin_id, implementation)
	if instance == null:
		return

	if instance.has_method("setup"):
		instance.call("setup", manifest.duplicate(true), manifest.get("config", {}).duplicate(true))

	if not instance.has_method("handle_hook"):
		_load_errors.append("Plugin %s must implement handle_hook(hook_id, payload)." % plugin_id)
		return

	_plugins_by_id[plugin_id] = {
		"manifest": manifest,
		"instance": instance,
	}
	_register_hooks(plugin_id, manifest, instance)


func _create_plugin_instance(plugin_id: String, implementation: Dictionary) -> Object:
	var implementation_type := String(implementation.get("type", ""))
	match implementation_type:
		IMPLEMENTATION_GDSCRIPT:
			return _create_gdscript_plugin(plugin_id, implementation)
		IMPLEMENTATION_NATIVE:
			return _create_native_plugin(plugin_id, implementation)
		IMPLEMENTATION_EXTERNAL_SCRIPT:
			var adapter: Object = ExternalScriptPlugin.new()
			return adapter
		_:
			_load_errors.append("Plugin %s has unsupported implementation type: %s" % [plugin_id, implementation_type])
			return null


func _create_gdscript_plugin(plugin_id: String, implementation: Dictionary) -> Object:
	var entry_path := String(implementation.get("entry", ""))
	if entry_path.is_empty():
		_load_errors.append("GDScript plugin %s missing implementation.entry." % plugin_id)
		return null

	var resource: Resource = load(entry_path)
	if resource == null or not resource is Script:
		_load_errors.append("GDScript plugin %s entry is not a script: %s" % [plugin_id, entry_path])
		return null

	var script: Script = resource
	var instance: Object = script.new()
	return instance


func _create_native_plugin(plugin_id: String, implementation: Dictionary) -> Object:
	var class_name_value := String(implementation.get("class_name", ""))
	if class_name_value.is_empty():
		_load_errors.append("Native plugin %s missing implementation.class_name." % plugin_id)
		return null
	if not ClassDB.class_exists(class_name_value):
		_load_errors.append("Native plugin %s class is not registered: %s" % [plugin_id, class_name_value])
		return null

	var instance: Object = ClassDB.instantiate(class_name_value)
	return instance


func _register_hooks(plugin_id: String, manifest: Dictionary, plugin: Object) -> void:
	var hooks: Dictionary = manifest.get("hooks", {})
	for hook_id_value in hooks.keys():
		var hook_id := String(hook_id_value)
		var hook_config: Dictionary = hooks[hook_id_value]
		var priority := int(hook_config.get("priority", 100))
		var entries: Array = _hook_entries.get(hook_id, [])
		entries.append({
			"plugin_id": plugin_id,
			"priority": priority,
			"plugin": plugin,
		})
		_hook_entries[hook_id] = entries


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_load_errors.append("JSON file does not exist: %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_load_errors.append("Cannot open JSON file: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_load_errors.append("JSON file must contain an object: %s" % path)
		return {}

	return parsed
