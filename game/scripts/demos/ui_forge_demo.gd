extends Control

const Store = preload("res://scripts/ui_pipeline/ui_pipeline_store.gd")
const Canvas = preload("res://scripts/ui_pipeline/ui_template_canvas.gd")

const COLOR_BG: Color = Color(0.055, 0.065, 0.075)
const COLOR_TEXT: Color = Color(0.95, 0.96, 0.92)
const COLOR_MUTED: Color = Color(0.66, 0.72, 0.76)
const COLOR_ACCENT: Color = Color(0.86, 0.70, 0.28)

var _styles: Array = []
var _templates: Array = []
var _asset_slots: Array = []
var _components: Array = []
var _style_option: OptionButton
var _template_option: OptionButton
var _status_label: Label
var _component_list: ItemList
var _canvas
var _current_style: Dictionary = {}
var _current_skin: Dictionary = {}
var _current_template: Dictionary = {}


func _ready() -> void:
	_styles = Store.load_styles()
	_templates = Store.load_templates()
	_asset_slots = Store.load_asset_slots()
	_components = Store.load_components()
	_build_ui()
	_load_current_selection()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	root.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)

	var title := Label.new()
	title.text = "UI Forge"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_child(title)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(90, 40)
	back_button.pressed.connect(_back_to_hub)
	header.add_child(back_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	page.add_child(_status_label)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	page.add_child(main)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 10)
	main.add_child(left)

	_style_option = OptionButton.new()
	for index in range(_styles.size()):
		_style_option.add_item(String(_styles[index].get("label", _styles[index].get("id", ""))), index)
	_style_option.item_selected.connect(_on_selection_changed)
	left.add_child(_labeled_control("Style", _style_option))

	_template_option = OptionButton.new()
	for index in range(_templates.size()):
		_template_option.add_item(String(_templates[index].get("label", _templates[index].get("id", ""))), index)
	_template_option.item_selected.connect(_on_selection_changed)
	left.add_child(_labeled_control("Template", _template_option))

	var prompt_button := Button.new()
	prompt_button.text = "Generate Prompt Pack"
	prompt_button.custom_minimum_size = Vector2(0, 40)
	prompt_button.pressed.connect(_save_prompt_pack)
	left.add_child(prompt_button)

	var apply_button := Button.new()
	apply_button.text = "Apply Skin"
	apply_button.custom_minimum_size = Vector2(0, 40)
	apply_button.pressed.connect(_apply_skin)
	left.add_child(apply_button)

	var save_button := Button.new()
	save_button.text = "Save Template"
	save_button.custom_minimum_size = Vector2(0, 40)
	save_button.pressed.connect(_save_custom_template)
	left.add_child(save_button)

	var component_title := Label.new()
	component_title.text = "UI Kit Components"
	component_title.add_theme_font_size_override("font_size", 16)
	component_title.add_theme_color_override("font_color", COLOR_TEXT)
	left.add_child(component_title)

	_component_list = ItemList.new()
	_component_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_component_list)

	_canvas = Canvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(720, 480)
	main.add_child(_canvas)


func _labeled_control(label_text: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 13)
	box.add_child(label)
	box.add_child(control)
	return box


func _load_current_selection() -> void:
	if _styles.is_empty() or _templates.is_empty():
		_status_label.text = "UI pipeline data missing."
		return

	var style_index: int = _style_option.selected
	var template_index: int = _template_option.selected
	if style_index < 0:
		style_index = 0
	if template_index < 0:
		template_index = 0

	_current_style = Store.load_style(_styles[style_index])
	_current_skin = Store.load_skin(_styles[style_index])
	_current_template = Store.load_template(_templates[template_index])
	_canvas.set_template(_current_template)
	_canvas.set_skin(_current_skin)
	_refresh_component_list()
	_set_status("Loaded %s with %s." % [_current_template.get("label", ""), _current_skin.get("label", "")])


func _refresh_component_list() -> void:
	_component_list.clear()
	var skin_components: Dictionary = _current_skin.get("components", {})
	var skin_slots: Dictionary = _current_skin.get("slots", {})
	if _components.is_empty():
		for slot in _asset_slots:
			var slot_id: String = String(slot.get("id", ""))
			var has_image: bool = String(skin_slots.get(slot_id, {}).get("image", "")) != ""
			_component_list.add_item("%s  %s" % [slot.get("label", slot_id), "img" if has_image else "color"])
		return

	for component in _components:
		var component_id: String = String(component.get("id", ""))
		var states: Array = component.get("states", ["normal"])
		var skin_states: Dictionary = skin_components.get(component_id, {}).get("states", {})
		var ready_count: int = 0
		for state in states:
			if String(skin_states.get(String(state), {}).get("image", "")).is_empty():
				continue
			ready_count += 1
		_component_list.add_item("%s  %s/%s" % [component.get("label", component_id), ready_count, states.size()])


func _on_selection_changed(_index: int) -> void:
	_load_current_selection()


func _save_prompt_pack() -> void:
	var prompt_pack: Dictionary = Store.build_prompt_pack(_current_style, _asset_slots)
	if not _components.is_empty():
		prompt_pack = Store.build_ui_kit_prompt_pack(_current_style, _components)
	var style_id: String = String(_current_style.get("id", "style"))
	var path: String = "user://ui_pipeline/%s_prompt_pack.json" % style_id
	var error: Error = Store.save_user_json(path, prompt_pack)
	if error == OK:
		_set_status("Prompt pack saved: %s" % ProjectSettings.globalize_path(path))
	else:
		_set_status("Prompt pack save failed: %s" % error_string(error))


func _apply_skin() -> void:
	_canvas.set_skin(_current_skin)
	_set_status("Applied skin: %s." % _current_skin.get("label", ""))


func _save_custom_template() -> void:
	var template: Dictionary = _canvas.get_template()
	var template_id: String = String(template.get("id", "template"))
	template["id"] = "%s_custom" % template_id
	template["label"] = "%s Custom" % template.get("label", template_id)
	var path: String = "user://ui_templates/%s_custom.json" % template_id
	var error: Error = Store.save_user_json(path, template)
	if error == OK:
		_set_status("Template saved: %s" % ProjectSettings.globalize_path(path))
	else:
		_set_status("Template save failed: %s" % error_string(error))


func _set_status(value: String) -> void:
	_status_label.text = value
	_status_label.add_theme_color_override("font_color", COLOR_ACCENT)


func _back_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")
