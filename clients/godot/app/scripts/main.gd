extends Control

const GENRE_NAMES: Array[String] = [
	"turn_rpg",
	"survivor_arpg",
	"tactics",
	"tower_defense",
	"idle",
]


func _ready() -> void:
	print("NimdaGame framework shell started.")
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.075)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 32)
	root.add_theme_constant_override("margin_top", 28)
	root.add_theme_constant_override("margin_right", 32)
	root.add_theme_constant_override("margin_bottom", 28)
	add_child(root)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	root.add_child(page)

	var title := Label.new()
	title.text = "NimdaGame Framework"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.92))
	page.add_child(title)

	var summary := Label.new()
	summary.text = "Shared Godot runtime, reusable gameplay modules, genre packages, and build tooling."
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 15)
	summary.add_theme_color_override("font_color", Color(0.66, 0.72, 0.76))
	page.add_child(summary)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	page.add_child(columns)

	columns.add_child(_make_panel("Godot common", [
		"app: boot and global flow",
		"common: plugins, input, audio, debug helpers",
		"shared_assets: reusable art, audio, fonts, icons",
	]))
	columns.add_child(_make_panel("Genre packages", _genre_lines()))
	columns.add_child(_make_panel("Runtime plugins", _plugin_lines()))


func _make_panel(header_text: String, lines: Array[String]) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.12, 0.13)
	style.border_color = Color(0.28, 0.32, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.95, 0.96, 0.92))
	content.add_child(header)

	for line in lines:
		var label := Label.new()
		label.text = "- %s" % line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.80))
		content.add_child(label)

	return panel


func _genre_lines() -> Array[String]:
	var lines: Array[String] = []
	for genre_name in GENRE_NAMES:
		lines.append("genres/%s" % genre_name)
	return lines


func _plugin_lines() -> Array[String]:
	var plugin_ids := PluginRegistry.get_loaded_plugin_ids()
	var errors := PluginRegistry.get_load_errors()
	var lines: Array[String] = []
	if plugin_ids.is_empty():
		lines.append("no runtime plugins enabled")
	else:
		lines.append("enabled: %s" % ", ".join(plugin_ids))

	if errors.is_empty():
		lines.append("plugin registry ready")
	else:
		lines.append("load warnings: %d" % errors.size())
	return lines
