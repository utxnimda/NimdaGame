extends RefCounted

var _manifest: Dictionary = {}
var _config: Dictionary = {}
var _implementation: Dictionary = {}


func setup(manifest: Dictionary, config: Dictionary) -> void:
	_manifest = manifest
	_config = config
	_implementation = manifest.get("implementation", {})


func get_plugin_info() -> Dictionary:
	return {
		"id": _manifest.get("id", ""),
		"name": _manifest.get("name", ""),
		"version": _manifest.get("version", ""),
		"implementation_type": "external_script",
	}


func handle_hook(hook_id: String, payload: Dictionary) -> Dictionary:
	var runtime := String(_implementation.get("runtime", "editor_only"))
	if runtime == "editor_only" and not OS.has_feature("editor"):
		return payload

	var command := String(_implementation.get("command", ""))
	if command.is_empty():
		return payload

	var args := PackedStringArray()
	var configured_args: Array = _implementation.get("args", [])
	for arg_value in configured_args:
		var arg := String(arg_value)
		arg = arg.replace("{hook_id}", hook_id)
		arg = arg.replace("{payload_json}", JSON.stringify(payload))
		args.append(arg)

	if bool(_implementation.get("append_context_json", true)):
		args.append(JSON.stringify({
			"hook_id": hook_id,
			"payload": payload,
			"config": _config,
			"plugin": get_plugin_info(),
		}))

	var output: Array = []
	var exit_code := OS.execute(command, args, output, true, false)
	if exit_code != 0 or output.is_empty():
		return payload

	var response_text := "\n".join(output)
	var parsed: Variant = JSON.parse_string(response_text)
	if parsed is Dictionary:
		return parsed.get("payload", parsed)
	return payload
