extends Control
class_name UITemplateCanvas

const FALLBACK_FONT_SIZE: int = 14

var _template: Dictionary = {}
var _skin: Dictionary = {}
var _selected_index: int = -1
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO
var _texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_template(template_data: Dictionary) -> void:
	_template = template_data.duplicate(true)
	_selected_index = -1
	queue_redraw()


func set_skin(skin_data: Dictionary) -> void:
	_skin = skin_data.duplicate(true)
	_texture_cache.clear()
	queue_redraw()


func get_template() -> Dictionary:
	return _template.duplicate(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _template.is_empty():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected_index = _find_node_at(event.position)
			if _selected_index >= 0:
				var rect: Rect2 = _node_screen_rect(_selected_index)
				_drag_offset = event.position - rect.position
				_dragging = true
				queue_redraw()
		else:
			_dragging = false

	if event is InputEventMouseMotion and _dragging and _selected_index >= 0:
		var nodes: Array = _template.get("nodes", [])
		var node: Dictionary = nodes[_selected_index]
		var canvas_position: Vector2 = (event.position - _drag_offset - _origin) / _scale
		var rect: Array = node.get("rect", [0, 0, 100, 40])
		rect[0] = int(round(max(0.0, canvas_position.x)))
		rect[1] = int(round(max(0.0, canvas_position.y)))
		node["rect"] = rect
		nodes[_selected_index] = node
		_template["nodes"] = nodes
		queue_redraw()


func _draw() -> void:
	var full_area: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(full_area, Color(0.055, 0.065, 0.075), true)

	if _template.is_empty():
		return

	var canvas_size: Vector2 = _canvas_size()
	_scale = min(size.x / canvas_size.x, size.y / canvas_size.y) * 0.94
	_origin = (size - canvas_size * _scale) * 0.5

	var canvas_rect: Rect2 = Rect2(_origin, canvas_size * _scale)
	draw_rect(canvas_rect, Color(0.08, 0.09, 0.10), true)
	draw_rect(canvas_rect, Color(0.24, 0.28, 0.30), false, 2.0)

	var nodes: Array = _template.get("nodes", [])
	for index in range(nodes.size()):
		_draw_node(index, nodes[index])


func _draw_node(index: int, node: Dictionary) -> void:
	var rect: Rect2 = _node_screen_rect(index)
	var node_type: String = String(node.get("type", "panel"))
	var slot_style: Dictionary = _node_style(node, String(node.get("state", _default_state_for_node_type(node_type))))
	var text_color: Color = _node_text_color(node)
	var border_color: Color = _color_from_hex(String(slot_style.get("border", "#4C585C")), Color(0.28, 0.32, 0.32))
	var fill_color: Color = _color_from_hex(String(slot_style.get("tint", slot_style.get("color", "#182024"))), Color(0.11, 0.13, 0.14))

	if node_type == "text":
		_draw_text_node(rect, node, text_color)
		return

	if node_type == "image":
		_draw_image_node(rect, node, text_color)
		return

	if node_type == "divider":
		_draw_divider_node(rect, node, slot_style, border_color)
		return

	_draw_slot_background(rect, slot_style, fill_color, border_color)

	match node_type:
		"bar":
			_draw_bar(rect, node, fill_color, border_color)
		"icon":
			_draw_icon_node(rect, node, text_color)
		"button":
			_draw_button_node(rect, node, text_color)
		"badge":
			_draw_icon_node(rect, node, text_color)
		_:
			_draw_panel_label(rect, node, text_color)

	if index == _selected_index:
		draw_rect(rect.grow(3), Color(0.86, 0.70, 0.28), false, 2.0)


func _draw_slot_background(rect: Rect2, slot_style: Dictionary, fill_color: Color, border_color: Color) -> void:
	var image_path: String = String(slot_style.get("image", ""))
	var texture: Texture2D = _load_texture(image_path)
	if texture != null:
		draw_texture_rect(texture, rect, false, _texture_modulate(slot_style))
	else:
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, 2.0)


func _draw_bar(rect: Rect2, node: Dictionary, fill_color: Color, border_color: Color) -> void:
	var inner: Rect2 = rect.grow(-6)
	draw_rect(inner, Color(0.08, 0.09, 0.10), true)
	var fill_rect: Rect2 = inner
	fill_rect.size.x *= clamp(float(node.get("progress", 0.68)), 0.0, 1.0)
	var fill_style: Dictionary = _node_style(node, "fill")
	var fill_texture: Texture2D = _load_texture(String(fill_style.get("image", "")))
	if fill_texture != null:
		draw_texture_rect(fill_texture, fill_rect, false, _texture_modulate(fill_style))
	else:
		var bar_fill: Color = _color_from_hex(String(node.get("fill_color", fill_style.get("tint", fill_style.get("color", "")))), fill_color.lightened(0.16))
		draw_rect(fill_rect, bar_fill, true)
	draw_rect(rect, border_color, false, 2.0)
	var label: String = String(node.get("text", ""))
	if not label.is_empty():
		_draw_centered_text(rect, label, _node_text_color(node), int(node.get("font_size", 13)))


func _draw_panel_label(rect: Rect2, node: Dictionary, text_color: Color) -> void:
	var label: String = String(node.get("text", ""))
	if label.is_empty():
		return
	var font: Font = ThemeDB.get_fallback_font()
	var font_size: int = int(node.get("font_size", FALLBACK_FONT_SIZE))
	draw_string(font, rect.position + Vector2(float(node.get("padding_left", 12)), float(node.get("padding_top", 24))), label, _text_alignment(node, HORIZONTAL_ALIGNMENT_LEFT), rect.size.x - 24, font_size, text_color)


func _draw_button_node(rect: Rect2, node: Dictionary, text_color: Color) -> void:
	var image_path: String = String(node.get("image", ""))
	if not image_path.is_empty():
		var icon_rect: Rect2 = Rect2(rect.position + Vector2(12, rect.size.y * 0.5 - 10), Vector2(20, 20))
		_draw_texture_in_rect(icon_rect, image_path, _node_image_modulate(node), true)
		var text_rect: Rect2 = Rect2(rect.position + Vector2(36, 0), rect.size - Vector2(44, 0))
		_draw_centered_text(text_rect, String(node.get("text", "")), text_color, int(node.get("font_size", FALLBACK_FONT_SIZE)))
	else:
		_draw_centered_text(rect, String(node.get("text", "")), text_color, int(node.get("font_size", FALLBACK_FONT_SIZE)))


func _draw_icon_node(rect: Rect2, node: Dictionary, text_color: Color) -> void:
	var image_path: String = String(node.get("image", ""))
	if not image_path.is_empty():
		var image_padding: float = float(node.get("image_padding", 12))
		_draw_texture_in_rect(rect.grow(-image_padding), image_path, _node_image_modulate(node), bool(node.get("preserve_aspect", true)))
	var label: String = String(node.get("text", ""))
	if not label.is_empty():
		_draw_centered_text(rect, label, text_color, int(node.get("font_size", FALLBACK_FONT_SIZE)))


func _draw_text_node(rect: Rect2, node: Dictionary, text_color: Color) -> void:
	var font: Font = ThemeDB.get_fallback_font()
	var label: String = String(node.get("text", ""))
	if label.is_empty():
		return
	var font_size: int = int(node.get("font_size", FALLBACK_FONT_SIZE))
	var line_height: float = float(font_size) * 1.25
	var lines: Array = _text_lines(font, label, font_size, rect.size.x, bool(node.get("wrap", false)))
	for index in range(lines.size()):
		var baseline: Vector2 = rect.position + Vector2(0, float(font_size) + float(index) * line_height)
		if baseline.y > rect.end.y:
			break
		draw_string(font, baseline, String(lines[index]), _text_alignment(node, HORIZONTAL_ALIGNMENT_LEFT), rect.size.x, font_size, text_color)


func _draw_image_node(rect: Rect2, node: Dictionary, _text_color: Color) -> void:
	_draw_texture_in_rect(rect, String(node.get("image", "")), _node_image_modulate(node), bool(node.get("preserve_aspect", true)))


func _draw_divider_node(rect: Rect2, node: Dictionary, slot_style: Dictionary, border_color: Color) -> void:
	var image_path: String = String(node.get("image", ""))
	if image_path.is_empty() and (node.has("slot") or node.has("component")):
		image_path = String(slot_style.get("image", ""))
	if not image_path.is_empty():
		var texture: Texture2D = _load_texture(image_path)
		if texture != null:
			draw_texture_rect(texture, rect, false, _texture_modulate(slot_style))
			return
	var line_color: Color = _color_from_hex(String(node.get("color", "")), border_color)
	draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), line_color, max(1.0, rect.size.y))


func _draw_centered_text(rect: Rect2, label: String, text_color: Color, font_size: int = FALLBACK_FONT_SIZE) -> void:
	if label.is_empty():
		return
	var font: Font = ThemeDB.get_fallback_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos: Vector2 = rect.position + (rect.size - text_size) * 0.5 + Vector2(0, font_size)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_texture_in_rect(rect: Rect2, image_path: String, modulate: Color, preserve_aspect: bool) -> void:
	var texture: Texture2D = _load_texture(image_path)
	if texture == null:
		return
	var draw_rect_target: Rect2 = rect
	if preserve_aspect:
		var texture_size: Vector2 = texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var scale_factor: float = min(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
			var fitted_size: Vector2 = texture_size * scale_factor
			draw_rect_target = Rect2(rect.position + (rect.size - fitted_size) * 0.5, fitted_size)
	draw_texture_rect(texture, draw_rect_target, false, modulate)


func _text_lines(font: Font, label: String, font_size: int, width: float, wrap: bool) -> Array:
	var output: Array = []
	for raw_line in label.split("\n"):
		var line: String = String(raw_line)
		if not wrap:
			output.append(line)
			continue
		var words: PackedStringArray = line.split(" ")
		var current: String = ""
		for word_value in words:
			var word: String = String(word_value)
			var candidate: String = word if current.is_empty() else "%s %s" % [current, word]
			var candidate_width: float = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if candidate_width <= width or current.is_empty():
				current = candidate
			else:
				output.append(current)
				current = word
		if not current.is_empty():
			output.append(current)
	return output


func _find_node_at(position: Vector2) -> int:
	var nodes: Array = _template.get("nodes", [])
	for offset in range(nodes.size()):
		var index: int = nodes.size() - 1 - offset
		if _node_screen_rect(index).has_point(position):
			return index
	return -1


func _node_screen_rect(index: int) -> Rect2:
	var nodes: Array = _template.get("nodes", [])
	var node: Dictionary = nodes[index]
	var rect: Array = node.get("rect", [0, 0, 100, 40])
	return Rect2(
		_origin + Vector2(float(rect[0]), float(rect[1])) * _scale,
		Vector2(float(rect[2]), float(rect[3])) * _scale
	)


func _canvas_size() -> Vector2:
	var canvas_size: Array = _template.get("canvas_size", [960, 540])
	return Vector2(float(canvas_size[0]), float(canvas_size[1]))


func _slot_style(slot: String) -> Dictionary:
	var slots: Dictionary = _skin.get("slots", {})
	return slots.get(slot, {})


func _node_style(node: Dictionary, state: String) -> Dictionary:
	var slot_id: String = String(node.get("slot", "panel_secondary"))
	var component_id: String = String(node.get("component", slot_id))
	var merged: Dictionary = _slot_style(slot_id).duplicate(true)
	var component_style: Dictionary = _component_state_style(component_id, state)
	for key in component_style.keys():
		merged[key] = component_style[key]
	return merged


func _component_state_style(component_id: String, state: String) -> Dictionary:
	var components: Dictionary = _skin.get("components", {})
	var component: Dictionary = components.get(component_id, {})
	if component.is_empty():
		return {}

	var states: Dictionary = component.get("states", {})
	var state_style: Dictionary = states.get(state, {})
	if state_style.is_empty() and state != "normal":
		state_style = states.get("normal", {})
	if state_style.is_empty() and state == "frame":
		state_style = states.get("normal", {})
	return state_style


func _default_state_for_node_type(node_type: String) -> String:
	match node_type:
		"bar":
			return "frame"
		_:
			return "normal"


func _texture_modulate(style: Dictionary) -> Color:
	var tint: String = String(style.get("tint", ""))
	if tint.is_empty():
		return Color.WHITE
	return _color_from_hex(tint, Color.WHITE)


func _node_text_color(node: Dictionary) -> Color:
	var default_color: Color = _color_from_hex(String(_skin.get("font_color", "#EEF4F2")), Color(0.95, 0.96, 0.92))
	return _color_from_hex(String(node.get("text_color", "")), default_color)


func _node_image_modulate(node: Dictionary) -> Color:
	return _color_from_hex(String(node.get("image_tint", "")), Color.WHITE)


func _text_alignment(node: Dictionary, fallback: int) -> int:
	match String(node.get("text_align", "")).to_lower():
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		_:
			return fallback


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		_texture_cache[path] = null
		return null
	var resource: Resource = load(path)
	if resource is Texture2D:
		_texture_cache[path] = resource
		return resource
	_texture_cache[path] = null
	return null


func _color_from_hex(value: String, fallback: Color) -> Color:
	if value.begins_with("#") and (value.length() == 7 or value.length() == 9):
		return Color.html(value)
	return fallback
