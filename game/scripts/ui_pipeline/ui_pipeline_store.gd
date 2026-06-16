class_name UIPipelineStore

const STYLE_INDEX_PATH: String = "res://ui_pipeline/styles/index.json"
const TEMPLATE_INDEX_PATH: String = "res://ui_pipeline/templates/index.json"
const ASSET_SLOTS_PATH: String = "res://ui_pipeline/asset_slots.json"
const COMPONENT_CATALOG_PATH: String = "res://ui_pipeline/component_catalog.json"


static func load_styles() -> Array:
	return _read_json(STYLE_INDEX_PATH).get("styles", [])


static func load_templates() -> Array:
	return _read_json(TEMPLATE_INDEX_PATH).get("templates", [])


static func load_asset_slots() -> Array:
	return _read_json(ASSET_SLOTS_PATH).get("slots", [])


static func load_components() -> Array:
	return _read_json(COMPONENT_CATALOG_PATH).get("components", [])


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
		"reference_image": style.get("reference_image", ""),
		"output_contract": style.get("output_contract", {}),
		"mode": "legacy_slots",
		"prompts": prompts,
	}


static func build_ui_kit_prompt_pack(style: Dictionary, components: Array) -> Dictionary:
	var output_contract: Dictionary = style.get("output_contract", {})
	var naming: String = String(output_contract.get("naming", "{style_id}_{slot_id}.png"))
	var style_bible: Dictionary = load_style_bible(style)
	var prompts: Array = []
	for component in components:
		var component_id: String = String(component.get("id", ""))
		var kind: String = String(component.get("kind", "panel"))
		for state in component.get("states", ["normal"]):
			var state_id: String = String(state)
			var asset_id: String = "%s_%s" % [component_id, state_id]
			var component_rule: String = String(style_bible.get("component_rules", {}).get(kind, ""))
			prompts.append({
				"slot_id": asset_id,
				"asset_id": asset_id,
				"component_id": component_id,
				"state": state_id,
				"kind": kind,
				"label": "%s / %s" % [component.get("label", component_id), state_id],
				"prompt": _join_nonempty([
					style.get("style_prompt", ""),
					component_rule,
					component.get("prompt", ""),
					_state_prompt_fragment(state_id),
					"transparent background, one isolated reusable UI component, generous padding",
				], ", "),
				"negative_prompt": _join_nonempty([
					style.get("negative_prompt", ""),
					"complete screen mockup, multiple UI elements, baked labels, tiny fake letters",
				], ", "),
				"output_name": naming
					.replace("{style_id}", String(style.get("id", "")))
					.replace("{slot_id}", asset_id),
				"nine_patch": component.get("nine_patch", [0, 0, 0, 0]),
			})

	return {
		"schema_version": 1,
		"style_id": style.get("id", ""),
		"style_label": style.get("label", ""),
		"reference_mode": style.get("reference_mode", "text_style"),
		"reference_image": style.get("reference_image", ""),
		"output_contract": output_contract,
		"style_bible": style_bible,
		"mode": "ui_kit",
		"prompts": prompts,
	}


static func load_style_bible(style: Dictionary) -> Dictionary:
	var style_id: String = String(style.get("id", ""))
	var style_bible: Dictionary = _read_json("res://ui_pipeline/styles/%s/style_bible.json" % style_id)
	if not style_bible.is_empty():
		return style_bible
	return {
		"schema_version": 1,
		"style_id": style_id,
		"palette": [],
		"motifs": [],
		"materials": [],
		"layout_language": [],
		"component_rules": {},
		"avoid": [],
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


static func _state_prompt_fragment(state: String) -> String:
	var fragments: Dictionary = {
		"normal": "normal default state",
		"hover": "hover state, slightly brighter highlight, same silhouette as normal",
		"pressed": "pressed state, slightly darker inset feel, same silhouette as normal",
		"disabled": "disabled state, muted low contrast, same silhouette as normal",
		"active": "active selected tab state, clear emphasis",
		"inactive": "inactive tab state, subdued but readable",
		"selected": "selected icon frame state, visible highlight",
		"featured": "featured portrait frame state, premium accent",
		"frame": "bar frame only with readable empty track",
		"fill": "bar fill strip only, horizontally tileable",
	}
	return String(fragments.get(state, "%s state" % state))


static func _join_nonempty(parts: Array, separator: String) -> String:
	var values := PackedStringArray()
	for part in parts:
		var text: String = String(part)
		if not text.is_empty():
			values.append(text)
	return separator.join(values)
