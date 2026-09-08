@tool
extends RefCounted
## Editor-only adapter for the Python database CLI.
## UI controls and record-specific rules belong to callers.

const DATA_TOOL_PATH := "tools/mygame_tools/rpg_editor_data.py"


func load_database(database_name: String, generated_path: String) -> Dictionary:
	var result := _run(["generate", "--database", database_name])
	if not result["ok"]:
		return result
	return _read_generated(database_name, generated_path)


func save_database(
	database_name: String,
	generated_path: String,
	payload: Dictionary,
	expected_source_hash: String
) -> Dictionary:
	if expected_source_hash.is_empty():
		return _failure("Load the database successfully before saving.")

	var temp_dir := OS.get_user_data_dir().path_join("rpg_editor")
	if DirAccess.make_dir_recursive_absolute(temp_dir) != OK:
		return _failure("Cannot create editor temporary directory.")

	var filename := "%s_%d_%d.json" % [
		database_name, OS.get_process_id(), Time.get_ticks_usec()
	]
	var input_path := temp_dir.path_join(filename)
	var file := FileAccess.open(input_path, FileAccess.WRITE)
	if file == null:
		return _failure("Cannot write editor temporary data.")
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(input_path)
		return _failure("Cannot finish writing editor temporary data.")

	var result := _run([
		"replace", "--database", database_name, "--input", input_path,
		"--expected-source-hash", expected_source_hash,
	])
	DirAccess.remove_absolute(input_path)
	if not result["ok"]:
		return result
	# The save command already generated JSON; do not generate it a second time.
	return _read_generated(database_name, generated_path)


func _read_generated(database_name: String, generated_path: String) -> Dictionary:
	var file := FileAccess.open(generated_path, FileAccess.READ)
	if file == null:
		return _failure("Cannot open generated data: %s" % generated_path)

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _failure("Generated data must contain an object.")
	if parsed.get("schema_version") != 1 or parsed.get("content_type") != database_name:
		return _failure("Generated data has an unsupported schema or content type.")
	if not parsed.get(database_name) is Array:
		return _failure("Generated data is missing the record array.")
	for record in parsed[database_name]:
		if not record is Dictionary:
			return _failure("Generated data contains a non-object record.")
	var source_hash: Variant = parsed.get("source_hash")
	if not source_hash is String or source_hash.length() != 64:
		return _failure("Generated data is missing its source hash.")
	return {"ok": true, "data": parsed, "error": ""}


func _run(arguments: Array[String]) -> Dictionary:
	var repository_root := _repository_root()
	var command_arguments := PackedStringArray([
		repository_root.path_join(DATA_TOOL_PATH)
	])
	command_arguments.append_array(PackedStringArray(arguments))
	var output: Array = []
	var exit_code := OS.execute(
		_python_executable(repository_root), command_arguments, output, true, false
	)
	if exit_code != 0:
		return _failure("Data tool exited with code %d.\n%s" % [
			exit_code, "".join(output).strip_edges()
		])
	return {"ok": true, "data": {}, "error": ""}


func _repository_root() -> String:
	var client_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	return client_root.path_join("../..").simplify_path()


func _python_executable(repository_root: String) -> String:
	var configured := OS.get_environment("NIMDAGAME_PYTHON")
	if not configured.is_empty():
		return configured
	for relative_path in [".venv/Scripts/python.exe", ".venv/bin/python"]:
		var candidate := repository_root.path_join(relative_path)
		if FileAccess.file_exists(candidate):
			return candidate
	return "python"


func _failure(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}
