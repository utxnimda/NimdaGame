extends Control

const COLOR_BG := Color(0.055, 0.065, 0.075)
const COLOR_PANEL := Color(0.105, 0.12, 0.13)
const COLOR_PANEL_ALT := Color(0.13, 0.145, 0.145)
const COLOR_BORDER := Color(0.28, 0.32, 0.32)
const COLOR_TEXT := Color(0.95, 0.96, 0.92)
const COLOR_MUTED := Color(0.66, 0.72, 0.76)
const COLOR_PARTY := Color(0.20, 0.55, 0.78)
const COLOR_ENEMY := Color(0.78, 0.32, 0.24)
const COLOR_ACCENT := Color(0.86, 0.70, 0.28)

var _units: Array = []
var _turn_queue: Array[int] = []
var _round := 1
var _active_index := -1
var _battle_over := false
var _selected_action: Dictionary = {}
var _log_lines: Array[String] = []

var _party_list: VBoxContainer
var _enemy_list: VBoxContainer
var _turn_label: Label
var _status_label: Label
var _action_panel: VBoxContainer
var _target_panel: VBoxContainer
var _log_label: RichTextLabel


func _ready() -> void:
	_build_ui()
	_reset_battle()


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
	page.add_theme_constant_override("separation", 14)
	root.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)

	var title := Label.new()
	title.text = "Turn RPG Demo"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_child(title)

	var restart_button := Button.new()
	restart_button.text = "Restart"
	restart_button.custom_minimum_size = Vector2(110, 40)
	restart_button.pressed.connect(_reset_battle)
	header.add_child(restart_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(90, 40)
	back_button.pressed.connect(_back_to_hub)
	header.add_child(back_button)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	page.add_child(_status_label)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	page.add_child(main)

	var battlefield := _make_panel()
	battlefield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(battlefield)

	var battlefield_margin := MarginContainer.new()
	battlefield_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	battlefield_margin.add_theme_constant_override("margin_left", 16)
	battlefield_margin.add_theme_constant_override("margin_top", 14)
	battlefield_margin.add_theme_constant_override("margin_right", 16)
	battlefield_margin.add_theme_constant_override("margin_bottom", 14)
	battlefield.add_child(battlefield_margin)

	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 24)
	battlefield_margin.add_child(sides)

	_party_list = VBoxContainer.new()
	_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_list.add_theme_constant_override("separation", 10)
	sides.add_child(_party_list)

	_enemy_list = VBoxContainer.new()
	_enemy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_list.add_theme_constant_override("separation", 10)
	sides.add_child(_enemy_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	main.add_child(right)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 18)
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT)
	right.add_child(_turn_label)

	var command_box := _make_panel()
	command_box.custom_minimum_size = Vector2(0, 220)
	right.add_child(command_box)

	var command_margin := MarginContainer.new()
	command_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	command_margin.add_theme_constant_override("margin_left", 12)
	command_margin.add_theme_constant_override("margin_top", 10)
	command_margin.add_theme_constant_override("margin_right", 12)
	command_margin.add_theme_constant_override("margin_bottom", 10)
	command_box.add_child(command_margin)

	var command_root := VBoxContainer.new()
	command_root.add_theme_constant_override("separation", 10)
	command_margin.add_child(command_root)

	_action_panel = VBoxContainer.new()
	_action_panel.add_theme_constant_override("separation", 8)
	command_root.add_child(_action_panel)

	_target_panel = VBoxContainer.new()
	_target_panel.add_theme_constant_override("separation", 8)
	command_root.add_child(_target_panel)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = false
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	_log_label.add_theme_color_override("default_color", COLOR_TEXT)
	right.add_child(_log_label)


func _make_panel() -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _reset_battle() -> void:
	_units = [
		_make_unit("knight", "Knight", "party", "Frontline", 128, 12, 24, 6, 8, [
			{"id": "slash", "name": "Slash", "type": "damage", "target": "enemy", "power": 18, "cost": 0, "text": "Reliable weapon hit."},
			{"id": "guard", "name": "Guard", "type": "guard", "target": "self", "cost": 0, "text": "Halve incoming damage until next turn."},
		]),
		_make_unit("mage", "Mage", "party", "Burst", 84, 20, 18, 3, 11, [
			{"id": "spark", "name": "Spark", "type": "damage", "target": "enemy", "power": 12, "cost": 0, "text": "Small magic hit."},
			{"id": "fireball", "name": "Fireball", "type": "damage_status", "target": "enemy", "power": 28, "cost": 5, "status": "Burn", "duration": 2, "potency": 7, "text": "Heavy fire damage and Burn."},
		]),
		_make_unit("cleric", "Cleric", "party", "Support", 98, 18, 15, 4, 9, [
			{"id": "smite", "name": "Smite", "type": "damage", "target": "enemy", "power": 10, "cost": 0, "text": "Light holy hit."},
			{"id": "heal", "name": "Heal", "type": "heal", "target": "ally", "power": 34, "cost": 4, "text": "Restore one ally."},
		]),
		_make_unit("slime", "Slime", "enemy", "Bruiser", 70, 0, 12, 2, 5, [
			{"id": "slam", "name": "Slam", "type": "damage", "target": "enemy", "power": 9, "cost": 0, "text": "Basic enemy attack."},
		]),
		_make_unit("goblin", "Goblin", "enemy", "Skirmisher", 82, 0, 16, 4, 10, [
			{"id": "stab", "name": "Stab", "type": "damage", "target": "enemy", "power": 13, "cost": 0, "text": "Fast enemy attack."},
		]),
		_make_unit("imp", "Imp", "enemy", "Caster", 62, 0, 18, 2, 12, [
			{"id": "ember", "name": "Ember", "type": "damage_status", "target": "enemy", "power": 12, "cost": 0, "status": "Burn", "duration": 2, "potency": 4, "text": "Small fire attack."},
		]),
	]
	_turn_queue.clear()
	_log_lines.clear()
	_round = 1
	_active_index = -1
	_battle_over = false
	_selected_action = {}
	_log("Battle started. Defeat all enemies.")
	_advance_turn()


func _make_unit(id: String, unit_name: String, side: String, role: String, hp: int, mp: int, attack: int, defense: int, speed: int, actions: Array) -> Dictionary:
	return {
		"id": id,
		"name": unit_name,
		"side": side,
		"role": role,
		"max_hp": hp,
		"hp": hp,
		"max_mp": mp,
		"mp": mp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"actions": actions,
		"guard": false,
		"statuses": [],
	}


func _advance_turn() -> void:
	_selected_action = {}
	_clear_actions()
	_render_all()

	if _check_battle_end():
		return

	while true:
		if _turn_queue.is_empty():
			_build_turn_queue()

		if _turn_queue.is_empty():
			return

		_active_index = _turn_queue.pop_front()
		if _is_alive(_active_index):
			break

	var actor: Dictionary = _units[_active_index]
	_tick_statuses(_active_index)
	if _check_battle_end():
		_render_all()
		return

	_units[_active_index]["guard"] = false
	if actor["side"] == "party":
		_units[_active_index]["mp"] = min(actor["max_mp"], actor["mp"] + 2)
		_status_label.text = "Choose an action for %s." % actor["name"]
		_show_player_actions(_active_index)
	else:
		_status_label.text = "%s is acting..." % actor["name"]
		_render_all()
		_run_enemy_turn()

	_render_all()


func _build_turn_queue() -> void:
	var alive_indices: Array[int] = []
	for index in range(_units.size()):
		if _is_alive(index):
			alive_indices.append(index)

	alive_indices.sort_custom(func(a: int, b: int) -> bool:
		return int(_units[a]["speed"]) > int(_units[b]["speed"])
	)
	_turn_queue = alive_indices
	_log("Round %d begins." % _round)
	_round += 1


func _show_player_actions(actor_index: int) -> void:
	_clear_actions()
	var actor: Dictionary = _units[actor_index]
	var prompt := Label.new()
	prompt.text = "Actions"
	prompt.add_theme_color_override("font_color", COLOR_TEXT)
	prompt.add_theme_font_size_override("font_size", 16)
	_action_panel.add_child(prompt)

	for action in actor["actions"]:
		var button := Button.new()
		var cost := int(action.get("cost", 0))
		button.text = "%s%s" % [action["name"], _cost_text(cost)]
		button.tooltip_text = action.get("text", "")
		button.disabled = cost > int(actor["mp"])
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(_select_action.bind(actor_index, action))
		_action_panel.add_child(button)


func _select_action(actor_index: int, action: Dictionary) -> void:
	_selected_action = action
	_clear_targets()

	match String(action["target"]):
		"self":
			_resolve_player_action(actor_index, actor_index)
		"enemy":
			_show_target_buttons(actor_index, "enemy")
		"ally":
			_show_target_buttons(actor_index, "party")


func _show_target_buttons(actor_index: int, side: String) -> void:
	var prompt := Label.new()
	prompt.text = "Targets"
	prompt.add_theme_color_override("font_color", COLOR_TEXT)
	prompt.add_theme_font_size_override("font_size", 16)
	_target_panel.add_child(prompt)

	for index in range(_units.size()):
		if _units[index]["side"] != side or not _is_alive(index):
			continue

		var button := Button.new()
		button.text = "%s  HP %d/%d" % [_units[index]["name"], _units[index]["hp"], _units[index]["max_hp"]]
		button.custom_minimum_size = Vector2(0, 36)
		button.pressed.connect(_resolve_player_action.bind(actor_index, index))
		_target_panel.add_child(button)


func _resolve_player_action(actor_index: int, target_index: int) -> void:
	if _battle_over or _selected_action.is_empty():
		return

	_set_command_enabled(false)
	_apply_action(actor_index, target_index, _selected_action)
	_render_all()
	_advance_turn()


func _run_enemy_turn() -> void:
	await get_tree().create_timer(0.45).timeout
	if _battle_over or not _is_alive(_active_index):
		_advance_turn()
		return

	var target_index := _lowest_hp_alive_index("party")
	if target_index == -1:
		_advance_turn()
		return

	var actor: Dictionary = _units[_active_index]
	var action: Dictionary = actor["actions"][0]
	_apply_action(_active_index, target_index, action)
	_render_all()
	await get_tree().create_timer(0.35).timeout
	_advance_turn()


func _apply_action(actor_index: int, target_index: int, action: Dictionary) -> void:
	var actor: Dictionary = _units[actor_index]
	var target: Dictionary = _units[target_index]
	var cost := int(action.get("cost", 0))
	_units[actor_index]["mp"] = max(0, int(actor["mp"]) - cost)

	match String(action["type"]):
		"damage":
			_deal_damage(actor_index, target_index, action)
		"damage_status":
			_deal_damage(actor_index, target_index, action)
			if _is_alive(target_index):
				_add_status(target_index, action)
		"heal":
			var amount := int(action.get("power", 0))
			var healed_hp: int = min(int(target["max_hp"]), int(target["hp"]) + amount)
			_units[target_index]["hp"] = healed_hp
			_log("%s casts %s on %s for %d HP." % [actor["name"], action["name"], target["name"], amount])
		"guard":
			_units[actor_index]["guard"] = true
			_log("%s guards and braces for impact." % actor["name"])


func _deal_damage(actor_index: int, target_index: int, action: Dictionary) -> void:
	var actor: Dictionary = _units[actor_index]
	var target: Dictionary = _units[target_index]
	var raw_damage := int(actor["attack"]) + int(action.get("power", 0)) - int(target["defense"])
	var damage: int = max(1, raw_damage)
	if bool(target["guard"]):
		damage = max(1, int(ceil(float(damage) * 0.5)))

	_units[target_index]["hp"] = max(0, int(target["hp"]) - damage)
	_log("%s uses %s on %s for %d damage." % [actor["name"], action["name"], target["name"], damage])

	if not _is_alive(target_index):
		_log("%s falls." % target["name"])


func _add_status(target_index: int, action: Dictionary) -> void:
	var statuses: Array = _units[target_index]["statuses"]
	statuses.append({
		"name": action.get("status", "Status"),
		"duration": int(action.get("duration", 1)),
		"potency": int(action.get("potency", 0)),
	})
	_units[target_index]["statuses"] = statuses
	_log("%s gains %s." % [_units[target_index]["name"], action.get("status", "Status")])


func _tick_statuses(unit_index: int) -> void:
	var statuses: Array = _units[unit_index]["statuses"]
	if statuses.is_empty() or not _is_alive(unit_index):
		return

	var remaining: Array = []
	for status in statuses:
		var name := String(status.get("name", "Status"))
		var potency := int(status.get("potency", 0))
		var duration := int(status.get("duration", 0))
		if potency > 0:
			_units[unit_index]["hp"] = max(0, int(_units[unit_index]["hp"]) - potency)
			_log("%s suffers %d %s damage." % [_units[unit_index]["name"], potency, name])

		duration -= 1
		if duration > 0 and _is_alive(unit_index):
			status["duration"] = duration
			remaining.append(status)
		else:
			_log("%s fades from %s." % [name, _units[unit_index]["name"]])

	_units[unit_index]["statuses"] = remaining

	if not _is_alive(unit_index):
		_log("%s falls." % _units[unit_index]["name"])


func _check_battle_end() -> bool:
	var party_alive := _has_alive_side("party")
	var enemies_alive := _has_alive_side("enemy")
	if party_alive and enemies_alive:
		return false

	_battle_over = true
	_clear_actions()
	if party_alive:
		_status_label.text = "Victory. The party cleared the encounter."
		_log("Victory. The encounter is complete.")
	else:
		_status_label.text = "Defeat. Restart and try another action order."
		_log("Defeat. The party has fallen.")
	_render_all()
	return true


func _has_alive_side(side: String) -> bool:
	for index in range(_units.size()):
		if _units[index]["side"] == side and _is_alive(index):
			return true
	return false


func _lowest_hp_alive_index(side: String) -> int:
	var best_index := -1
	var best_hp := 1000000
	for index in range(_units.size()):
		if _units[index]["side"] != side or not _is_alive(index):
			continue
		var hp := int(_units[index]["hp"])
		if hp < best_hp:
			best_hp = hp
			best_index = index
	return best_index


func _is_alive(index: int) -> bool:
	return int(_units[index]["hp"]) > 0


func _render_all() -> void:
	_render_side(_party_list, "party", "Party")
	_render_side(_enemy_list, "enemy", "Enemies")
	_render_turn_label()
	_render_log()


func _render_side(container: VBoxContainer, side: String, title: String) -> void:
	for child in container.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", COLOR_TEXT)
	container.add_child(header)

	for index in range(_units.size()):
		if _units[index]["side"] == side:
			container.add_child(_make_unit_card(index))


func _make_unit_card(index: int) -> Control:
	var unit: Dictionary = _units[index]
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 112)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_ALT if _is_alive(index) else Color(0.09, 0.09, 0.09)
	style.border_color = COLOR_ACCENT if index == _active_index and not _battle_over else COLOR_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)

	var name_row := HBoxContainer.new()
	layout.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "%s  [%s]" % [unit["name"], unit["role"]]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT if _is_alive(index) else COLOR_MUTED)
	name_row.add_child(name_label)

	var side_dot := ColorRect.new()
	side_dot.custom_minimum_size = Vector2(12, 12)
	side_dot.color = COLOR_PARTY if unit["side"] == "party" else COLOR_ENEMY
	name_row.add_child(side_dot)

	layout.add_child(_make_bar("HP", int(unit["hp"]), int(unit["max_hp"]), Color(0.72, 0.20, 0.18)))
	layout.add_child(_make_bar("MP", int(unit["mp"]), max(1, int(unit["max_mp"])), Color(0.20, 0.42, 0.76)))

	var footer := Label.new()
	footer.text = _unit_footer(unit)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", COLOR_MUTED)
	layout.add_child(footer)

	return card


func _make_bar(label_text: String, value: int, maximum: int, fill_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.custom_minimum_size = Vector2(32, 0)
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = clamp(value, 0, maximum)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.065, 0.075)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)

	var amount := Label.new()
	amount.custom_minimum_size = Vector2(64, 0)
	amount.text = "%d/%d" % [value, maximum]
	amount.add_theme_font_size_override("font_size", 12)
	amount.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(amount)

	return row


func _unit_footer(unit: Dictionary) -> String:
	var parts: Array[String] = [
		"ATK %d" % unit["attack"],
		"DEF %d" % unit["defense"],
		"SPD %d" % unit["speed"],
	]
	if bool(unit["guard"]):
		parts.append("Guard")
	var statuses: Array = unit["statuses"]
	for status in statuses:
		parts.append("%s %d" % [status["name"], status["duration"]])
	return "   ".join(parts)


func _render_turn_label() -> void:
	if _battle_over or _active_index == -1:
		_turn_label.text = "Battle Complete"
		return

	var actor: Dictionary = _units[_active_index]
	_turn_label.text = "Round %d  |  Active: %s" % [max(1, _round - 1), actor["name"]]


func _render_log() -> void:
	_log_label.clear()
	for line in _log_lines:
		_log_label.append_text("%s\n" % line)


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 12:
		_log_lines.pop_front()


func _clear_actions() -> void:
	for child in _action_panel.get_children():
		child.queue_free()
	_clear_targets()


func _clear_targets() -> void:
	for child in _target_panel.get_children():
		child.queue_free()


func _set_command_enabled(enabled: bool) -> void:
	for child in _action_panel.get_children():
		if child is Button:
			child.disabled = not enabled
	for child in _target_panel.get_children():
		if child is Button:
			child.disabled = not enabled


func _cost_text(cost: int) -> String:
	if cost <= 0:
		return ""
	return "  MP %d" % cost


func _back_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")
