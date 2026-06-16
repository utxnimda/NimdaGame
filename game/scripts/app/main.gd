extends Control

const DemoBoard = preload("res://scripts/demos/demo_board.gd")
const DemoCatalog = preload("res://scripts/demos/demo_catalog.gd")

var _catalog: Array = DemoCatalog.get_categories()
var _selected_index := 0
var _buttons: Array[Button] = []
var _title_label: Label
var _subtitle_label: Label
var _loop_label: Label
var _systems_label: Label
var _release_label: Label
var _launch_button: Button
var _board: Control

func _ready() -> void:
	print("NimdaGame Godot layer started.")
	_build_ui()
	_select_demo(0)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.075)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	root.add_child(page)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	page.add_child(header)

	var app_title := Label.new()
	app_title.text = "NimdaGame Demo Hub"
	app_title.add_theme_font_size_override("font_size", 30)
	app_title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.92))
	header.add_child(app_title)

	var app_subtitle := Label.new()
	app_subtitle.text = "A small playable catalog for validating build, package, and release flow."
	app_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app_subtitle.add_theme_font_size_override("font_size", 15)
	app_subtitle.add_theme_color_override("font_color", Color(0.66, 0.72, 0.76))
	header.add_child(app_subtitle)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	page.add_child(content)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(280, 0)
	sidebar.add_theme_constant_override("separation", 10)
	content.add_child(sidebar)

	for index in range(_catalog.size()):
		var button := Button.new()
		button.text = "%d. %s" % [index + 1, _catalog[index]["title"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_demo.bind(index))
		sidebar.add_child(button)
		_buttons.append(button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	content.add_child(right)

	var top_row := HBoxContainer.new()
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	right.add_child(top_row)

	_board = DemoBoard.new()
	_board.custom_minimum_size = Vector2(520, 340)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_child(_board)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(340, 0)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 10)
	top_row.add_child(details)

	_title_label = _make_label(24, Color(0.95, 0.96, 0.92))
	details.add_child(_title_label)

	_subtitle_label = _make_label(14, Color(0.66, 0.72, 0.76))
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_subtitle_label)

	_launch_button = Button.new()
	_launch_button.custom_minimum_size = Vector2(0, 44)
	_launch_button.pressed.connect(_launch_selected_demo)
	details.add_child(_launch_button)

	_loop_label = _make_section_label()
	details.add_child(_loop_label)

	_systems_label = _make_section_label()
	details.add_child(_systems_label)

	_release_label = _make_section_label()
	_release_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(_release_label)

	var footer := Label.new()
	footer.text = "Release smoke path: select every demo -> export -> package -> publish."
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.56, 0.62, 0.66))
	right.add_child(footer)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_section_label() -> Label:
	var label := _make_label(14, Color(0.82, 0.86, 0.84))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _select_demo(index: int) -> void:
	_selected_index = index
	var demo: Dictionary = _catalog[index]
	_title_label.text = demo["title"]
	_subtitle_label.text = demo["summary"]
	_loop_label.text = "Core Loop\n%s" % _bullet_lines(demo["loop"])
	_systems_label.text = "Reusable Systems\n%s" % _bullet_lines(demo["systems"])
	_release_label.text = "Release Smoke Checks\n%s" % _bullet_lines(demo["release_checks"])
	_board.set_demo(demo)
	_update_launch_button(demo)

	for button_index in range(_buttons.size()):
		var button := _buttons[button_index]
		button.disabled = button_index == _selected_index


func _update_launch_button(demo: Dictionary) -> void:
	if demo.has("scene_path"):
		_launch_button.text = "Play Demo"
		_launch_button.disabled = false
	else:
		_launch_button.text = "Planning Only"
		_launch_button.disabled = true


func _launch_selected_demo() -> void:
	var demo: Dictionary = _catalog[_selected_index]
	if not demo.has("scene_path"):
		return
	get_tree().change_scene_to_file(demo["scene_path"])


func _bullet_lines(values: Array) -> String:
	var lines: Array[String] = []
	for value in values:
		lines.append("- %s" % value)
	return "\n".join(lines)
