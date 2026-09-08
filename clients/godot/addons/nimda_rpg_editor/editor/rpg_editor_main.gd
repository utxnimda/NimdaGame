@tool
extends Control

const GENERATED_ACTORS_PATH := "res://data/generated/turn_rpg/actors.json"
const ActorDatabase = preload("res://addons/nimda_rpg_editor/editor/actor_database.gd")
const DatabaseForm = preload("res://addons/nimda_rpg_editor/editor/database_form.gd")
const DatabaseClient = preload("res://addons/nimda_rpg_editor/editor/database_client.gd")

var _data_client := DatabaseClient.new()
var _source_hash := ""
var _actors: Array = []
var _selected_actor_index := -1
var _dirty := false

var _title_label: Label
var _status_label: Label
var _search_edit: LineEdit
var _actor_list: ItemList
var _save_button: Button
var _duplicate_button: Button
var _delete_button: Button
var _form: DatabaseForm
var _error_dialog: AcceptDialog
var _reload_confirm: ConfirmationDialog
var _delete_confirm: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	call_deferred("_reload_data")


func _build_ui() -> void:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 42
	toolbar.add_theme_constant_override("separation", 6)
	page.add_child(toolbar)

	_title_label = Label.new()
	_title_label.text = "Actors"
	_title_label.add_theme_font_size_override("font_size", 18)
	toolbar.add_child(_title_label)

	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	_status_label = Label.new()
	_status_label.text = "Loading..."
	toolbar.add_child(_status_label)

	var reload_button := _create_icon_button("Reload", "Reload actor data", "R")
	reload_button.pressed.connect(_on_reload_pressed)
	toolbar.add_child(reload_button)

	_save_button = _create_icon_button("Save", "Save actor database", "S")
	_save_button.disabled = true
	_save_button.pressed.connect(_save_data)
	toolbar.add_child(_save_button)

	page.add_child(HSeparator.new())

	var content_split := HSplitContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.split_offset = 280
	page.add_child(content_split)

	var list_panel := VBoxContainer.new()
	list_panel.custom_minimum_size.x = 260
	list_panel.add_theme_constant_override("separation", 6)
	content_split.add_child(list_panel)

	var list_toolbar := HBoxContainer.new()
	list_toolbar.add_theme_constant_override("separation", 4)
	list_panel.add_child(list_toolbar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search actors"
	_search_edit.clear_button_enabled = true
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	list_toolbar.add_child(_search_edit)

	var add_button := _create_icon_button("Add", "Add actor", "+")
	add_button.pressed.connect(_add_actor)
	list_toolbar.add_child(add_button)

	_duplicate_button = _create_icon_button("Duplicate", "Duplicate selected actor", "D")
	_duplicate_button.pressed.connect(_duplicate_actor)
	list_toolbar.add_child(_duplicate_button)

	_delete_button = _create_icon_button("Remove", "Delete selected actor", "-")
	_delete_button.pressed.connect(_request_delete_actor)
	list_toolbar.add_child(_delete_button)

	_actor_list = ItemList.new()
	_actor_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_actor_list.select_mode = ItemList.SELECT_SINGLE
	_actor_list.item_selected.connect(_on_actor_selected)
	list_panel.add_child(_actor_list)

	var form_scroll := ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.add_child(form_scroll)

	var form_margin := MarginContainer.new()
	form_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_margin.add_theme_constant_override("margin_left", 18)
	form_margin.add_theme_constant_override("margin_top", 12)
	form_margin.add_theme_constant_override("margin_right", 18)
	form_margin.add_theme_constant_override("margin_bottom", 24)
	form_scroll.add_child(form_margin)

	_form = DatabaseForm.new()
	_form.value_changed.connect(_set_selected_value)
	var form := _form
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	form_margin.add_child(form)

	var identity_grid := form.add_section("Identity")
	form.add_line_field(identity_grid, "ID", "id")
	form.add_spin_field(identity_grid, "Legacy ID", "legacy_id", 0, 999999)
	form.add_line_field(identity_grid, "Name", "name")
	form.add_line_field(identity_grid, "Nickname", "nickname")
	form.add_line_field(identity_grid, "Class ID", "class_id")
	form.add_spin_field(identity_grid, "Initial level", "initial_level", 1, 999)
	form.add_spin_field(identity_grid, "Max level", "max_level", 1, 999)
	form.add_multiline_field(identity_grid, "Profile", "profile")

	var assets_grid := form.add_section("Presentation")
	form.add_line_field(assets_grid, "Portrait", "assets.portrait")
	form.add_line_field(assets_grid, "Map sprite", "assets.map_sprite")
	form.add_line_field(assets_grid, "Battle sprite", "assets.battle_sprite")

	var stats_grid := form.add_section("Base stats")
	for stat_name in ActorDatabase.STAT_FIELDS:
		var minimum := 1 if stat_name == "max_hp" else 0
		form.add_spin_field(
			stats_grid, _display_name(stat_name), "base_stats.%s" % stat_name, minimum, 999999
		)

	var form_spacer := Control.new()
	form_spacer.custom_minimum_size.y = 20
	form.add_child(form_spacer)

	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "RPG Editor"
	add_child(_error_dialog)

	_reload_confirm = ConfirmationDialog.new()
	_reload_confirm.title = "Discard changes"
	_reload_confirm.dialog_text = "Reload actor data and discard unsaved changes?"
	_reload_confirm.confirmed.connect(_reload_data)
	add_child(_reload_confirm)

	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.title = "Delete actor"
	_delete_confirm.confirmed.connect(_delete_actor)
	add_child(_delete_confirm)

	_set_form_enabled(false)


func _create_icon_button(icon_name: String, tooltip: String, fallback_text: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(34, 34)
	if has_theme_icon(icon_name, "EditorIcons"):
		button.icon = get_theme_icon(icon_name, "EditorIcons")
	else:
		button.text = fallback_text
	return button


func _reload_data() -> void:
	_set_status("Loading actor data...")
	var result := _data_client.load_database("actors", GENERATED_ACTORS_PATH)
	if not result["ok"]:
		_show_error(String(result["error"]))
		_set_status("Load failed", true)
		return
	_apply_database(result["data"])
	_set_status("Loaded %d actor(s)" % _actors.size())


func _save_data() -> void:
	var validation_errors := ActorDatabase.validate(_actors)
	if not validation_errors.is_empty():
		_show_error("Actor database is invalid.\n\n%s" % "\n".join(validation_errors))
		_set_status("Validation failed", true)
		return

	_set_status("Saving actor data...")
	var result := _data_client.save_database(
		"actors", GENERATED_ACTORS_PATH,
		{"schema_version": 1, "actors": _actors}, _source_hash
	)
	if not result["ok"]:
		_show_error(String(result["error"]))
		_set_status("Save failed", true)
		return
	_apply_database(result["data"])
	_set_status("Saved %d actor(s)" % _actors.size())


func _apply_database(payload: Dictionary) -> void:
	_actors.clear()
	for record in payload["actors"]:
		_actors.append(ActorDatabase.normalize(record))
	_source_hash = String(payload["source_hash"])
	_dirty = false
	_selected_actor_index = mini(_selected_actor_index, _actors.size() - 1)
	_refresh_actor_list(_selected_actor_index)
	_update_dirty_state()


func _on_reload_pressed() -> void:
	if _dirty:
		_reload_confirm.popup_centered()
	else:
		_reload_data()


func _on_search_changed(_value: String) -> void:
	_refresh_actor_list(_selected_actor_index)


func _on_actor_selected(item_index: int) -> void:
	_selected_actor_index = int(_actor_list.get_item_metadata(item_index))
	_populate_form()


func _refresh_actor_list(preferred_actor_index: int) -> void:
	_actor_list.clear()
	var query := _search_edit.text.strip_edges().to_lower()
	var preferred_item_index := -1

	for actor_index in range(_actors.size()):
		var actor: Dictionary = _actors[actor_index]
		var searchable := "%s %s %s" % [
			String(actor.get("id", "")),
			String(actor.get("name", "")),
			String(actor.get("nickname", "")),
		]
		if not query.is_empty() and not searchable.to_lower().contains(query):
			continue

		var item_index := _actor_list.add_item(_actor_label(actor))
		_actor_list.set_item_metadata(item_index, actor_index)
		if actor_index == preferred_actor_index:
			preferred_item_index = item_index

	if preferred_item_index < 0 and _actor_list.item_count > 0:
		preferred_item_index = 0

	if preferred_item_index >= 0:
		_actor_list.select(preferred_item_index)
		_on_actor_selected(preferred_item_index)
	else:
		_selected_actor_index = -1
		_clear_form()


func _populate_form() -> void:
	if _selected_actor_index < 0 or _selected_actor_index >= _actors.size():
		_clear_form()
		return
	_form.set_record(_actors[_selected_actor_index])
	_set_form_enabled(true)


func _clear_form() -> void:
	_form.clear()
	_set_form_enabled(false)


func _set_form_enabled(enabled: bool) -> void:
	_form.set_editable(enabled)
	_duplicate_button.disabled = not enabled
	_delete_button.disabled = not enabled


func _set_selected_value(key: String, value: Variant) -> void:
	if _selected_actor_index < 0 or _selected_actor_index >= _actors.size():
		return

	var actor: Dictionary = _actors[_selected_actor_index]
	var parts := key.split(".")
	if parts.size() == 1:
		actor[key] = value
	else:
		var section_name := String(parts[0])
		var section: Dictionary = actor.get(section_name, {}).duplicate(true)
		section[String(parts[1])] = value
		actor[section_name] = section
	_actors[_selected_actor_index] = actor

	_dirty = true
	_update_dirty_state()
	if key == "name" or key == "id" or key == "legacy_id":
		_update_selected_list_label()


func _update_selected_list_label() -> void:
	for item_index in range(_actor_list.item_count):
		if int(_actor_list.get_item_metadata(item_index)) == _selected_actor_index:
			_actor_list.set_item_text(item_index, _actor_label(_actors[_selected_actor_index]))
			return


func _add_actor() -> void:
	var actor := ActorDatabase.create_default()
	actor["id"] = ActorDatabase.unique_id(_actors, "actor_new")
	actor["legacy_id"] = ActorDatabase.next_legacy_id(_actors)
	_actors.append(actor)
	_selected_actor_index = _actors.size() - 1
	_search_edit.text = ""
	_dirty = true
	_refresh_actor_list(_selected_actor_index)
	_update_dirty_state()


func _duplicate_actor() -> void:
	if _selected_actor_index < 0:
		return
	var actor: Dictionary = _actors[_selected_actor_index].duplicate(true)
	actor["id"] = ActorDatabase.unique_id(_actors, "%s_copy" % String(actor["id"]))
	actor["legacy_id"] = ActorDatabase.next_legacy_id(_actors)
	actor["name"] = "%s Copy" % String(actor["name"])
	_actors.append(actor)
	_selected_actor_index = _actors.size() - 1
	_search_edit.text = ""
	_dirty = true
	_refresh_actor_list(_selected_actor_index)
	_update_dirty_state()


func _request_delete_actor() -> void:
	if _selected_actor_index < 0:
		return
	var actor: Dictionary = _actors[_selected_actor_index]
	_delete_confirm.dialog_text = "Delete actor '%s'?" % String(actor.get("name", actor.get("id", "")))
	_delete_confirm.popup_centered()


func _delete_actor() -> void:
	if _selected_actor_index < 0 or _selected_actor_index >= _actors.size():
		return
	_actors.remove_at(_selected_actor_index)
	_selected_actor_index = mini(_selected_actor_index, _actors.size() - 1)
	_dirty = true
	_refresh_actor_list(_selected_actor_index)
	_update_dirty_state()


func _actor_label(actor: Dictionary) -> String:
	var display_name := String(actor.get("name", "")).strip_edges()
	if display_name.is_empty():
		display_name = String(actor.get("id", ""))
	return "%03d  %s" % [int(actor.get("legacy_id", 0)), display_name]


func _display_name(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _update_dirty_state() -> void:
	_title_label.text = "Actors *" if _dirty else "Actors"
	_save_button.disabled = not _dirty or _source_hash.is_empty()


func _set_status(message: String, is_error := false) -> void:
	_status_label.text = message
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.38, 0.32))
	else:
		_status_label.remove_theme_color_override("font_color")


func _show_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered_ratio(0.5)
