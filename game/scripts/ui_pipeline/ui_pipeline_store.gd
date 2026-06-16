class_name UIPipelineStore

const STYLE_INDEX_PATH: String = "res://ui_pipeline/styles/index.json"
const TEMPLATE_INDEX_PATH: String = "res://ui_pipeline/templates/index.json"
const ASSET_SLOTS_PATH: String = "res://ui_pipeline/asset_slots.json"


static func load_styles() -> Array:
	return _read_json(STYLE_INDEX_PATH).get("styles", [])


static func load_templates() -> Array:
	return _read_json(TEMPLATE_INDEX_PATH).get("templates", [])


static func load_asset_slots() -> Array:
	return _read_json(ASSET_SLOTS_PATH).get("slots", [])


static func load_style(index_entry: Dictionary) -> Dictionary:
	return _read_json(String(index_entry.get("style_path", "")))


static func load_skin(index_entry: Dictionary) -> Dictionary:
	return _read_json(String(index_entry.get("skin_path", "")))


static func load_template(index_entry: Dictionary) -> Dictionary:
	return _read_json(String(index_entry.get("path", "")))


static func build_prompt_pack(style: Dictionary, asset_slots: Array) -> Dictionary:
	var prompts: Array = []
	for slot in asset_slots:
		var slot_id: String = String(slot.get("id", ""))
		prompts.append({
			"slot_id": slot_id,
			"label": slot.get("label", slot_id),
			"prompt": "%s, %s" % [style.get("style_prompt", ""), slot.get("prompt", "")],
			"negative_prompt": style.get("negative_prompt", ""),
			"output_name": String(style.get("output_contract", {}).get("naming", "{style_id}_{slot_id}.png"))
				.replace("{style_id}", String(style.get("id", "")))
				.replace("{slot_id}", slot_id),
		})

	return {
		"schema_version": 1,
		"style_id": style.get("id", ""),
		"style_label": style.get("label", ""),
		"reference_mode": style.get("reference_mode", "text_style"),
		"output_contract": style.get("output_contract", {}),
		"prompts": prompts,
	}


static func save_user_json(path: String, payload: Dictionary) -> Error:
	var directory: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	return OK


static func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
