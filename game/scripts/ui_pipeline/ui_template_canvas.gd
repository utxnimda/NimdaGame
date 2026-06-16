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
	var slot_style: Dictionary = _node_style(node, _default_state_for_node_type(node_type))
	var text_color: Color = _color_from_hex(String(_skin.get("font_color", "#EEF4F2")), Color(0.95, 0.96, 0.92))
	var border_color: Color = _color_from_hex(String(slot_style.get("border", "#4C585C")), Color(0.28, 0.32, 0.32))
	var fill_color: Color = _color_from_hex(String(slot_style.get("tint", slot_style.get("color", "#182024"))), Color(0.11, 0.13, 0.14))

	_draw_slot_background(rect, slot_style, fill_color, border_color)

	match node_type:
		"bar":
			_draw_bar(rect, node, fill_color, border_color)
		"icon":
			_draw_centered_text(rect, String(node.get("text", "")), text_color)
		"button":
			_draw_centered_text(rect, String(node.get("text", "")), text_color)
		_:
			_draw_panel_label(rect, String(node.get("text", "")), text_color)

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
	fill_rect.size.x *= 0.68
	var fill_style: Dictionary = _node_style(node, "fill")
	var fill_texture: Texture2D = _load_texture(String(fill_style.get("image", "")))
	if fill_texture != null:
		draw_texture_rect(fill_texture, fill_rect, false, _texture_modulate(fill_style))
	else:
		var bar_fill: Color = _color_from_hex(String(fill_style.get("tint", fill_style.get("color", ""))), fill_color.lightened(0.16))
		draw_rect(fill_rect, bar_fill, true)
	draw_rect(rect, border_color, false, 2.0)


func _draw_panel_label(rect: Rect2, label: String, text_color: Color) -> void:
	var font: Font = ThemeDB.get_fallback_font()
	draw_string(font, rect.position + Vector2(12, 24), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24, FALLBACK_FONT_SIZE, text_color)


func _draw_centered_text(rect: Rect2, label: String, text_color: Color) -> void:
	var font: Font = ThemeDB.get_fallback_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FALLBACK_FONT_SIZE)
	var pos: Vector2 = rect.position + (rect.size - text_size) * 0.5 + Vector2(0, FALLBACK_FONT_SIZE)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FALLBACK_FONT_SIZE, text_color)


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
