extends RefCounted

var _manifest: Dictionary = {}
var _config: Dictionary = {}


func setup(manifest: Dictionary, config: Dictionary) -> void:
	_manifest = manifest
	_config = config


func get_plugin_info() -> Dictionary:
	return {
		"id": _manifest.get("id", ""),
		"name": _manifest.get("name", ""),
		"version": _manifest.get("version", ""),
		"implementation_type": "gdscript",
		"config": _config,
	}


func handle_hook(_hook_id: String, payload: Dictionary) -> Dictionary:
	return payload
