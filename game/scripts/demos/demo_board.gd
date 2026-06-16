extends Control

var _demo: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_demo(demo: Dictionary) -> void:
	_demo = demo
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color(0.09, 0.105, 0.12), true)
	draw_rect(area, Color(0.22, 0.25, 0.27), false, 2.0)

	if _demo.is_empty():
		return

	match String(_demo["id"]):
		"turn_rpg":
			_draw_turn_rpg(area)
		"arpg":
			_draw_arpg(area)
		"tactics":
			_draw_tactics(area)
		"systems_lab":
			_draw_systems_lab(area)


func _draw_turn_rpg(area: Rect2) -> void:
	var party_x := area.position.x + area.size.x * 0.24
	var enemy_x := area.position.x + area.size.x * 0.74
	var base_y := area.position.y + area.size.y * 0.44

	for index in range(3):
		var y := base_y + (index - 1) * 58
		_draw_unit(Vector2(party_x, y), Color(0.20, 0.55, 0.78), "H%d" % [index + 1])
		_draw_unit(Vector2(enemy_x, y), Color(0.78, 0.32, 0.24), "E%d" % [index + 1])

	var queue_rect := Rect2(area.position + Vector2(34, area.size.y - 82), Vector2(area.size.x - 68, 38))
	draw_rect(queue_rect, Color(0.14, 0.16, 0.18), true)
	draw_rect(queue_rect, Color(0.33, 0.38, 0.40), false, 1.5)
	for index in range(6):
		var x := queue_rect.position.x + 28 + index * 56
		draw_circle(Vector2(x, queue_rect.position.y + 19), 13, Color(0.86, 0.70, 0.28))

	_draw_arrow(Vector2(party_x + 42, base_y), Vector2(enemy_x - 42, base_y), Color(0.91, 0.82, 0.42))


func _draw_arpg(area: Rect2) -> void:
	var center := area.position + area.size * 0.5
	draw_circle(center, 26, Color(0.25, 0.68, 0.72))
	draw_arc(center, 56, 0.0, TAU, 48, Color(0.20, 0.44, 0.47), 2.0)
	draw_arc(center, 98, -0.4, 1.3, 24, Color(0.86, 0.70, 0.28), 5.0)

	for index in range(14):
		var angle := index * TAU / 14.0
		var radius := 115.0 + float(index % 3) * 26.0
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(pos, 13, Color(0.78, 0.32, 0.24))

	for index in range(5):
		var angle := -0.6 + index * 0.28
		var start := center + Vector2(cos(angle), sin(angle)) * 42.0
		var end := center + Vector2(cos(angle), sin(angle)) * 150.0
		draw_line(start, end, Color(0.91, 0.82, 0.42), 3.0)


func _draw_tactics(area: Rect2) -> void:
	var cell := min(area.size.x / 10.0, area.size.y / 7.0)
	var origin := area.position + Vector2((area.size.x - cell * 8.0) * 0.5, (area.size.y - cell * 6.0) * 0.5)

	for y in range(6):
		for x in range(8):
			var rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell - 2, cell - 2))
			var color := Color(0.13, 0.16, 0.17)
			if abs(x - 2) + abs(y - 3) <= 3:
				color = Color(0.14, 0.32, 0.34)
			if abs(x - 5) + abs(y - 2) <= 2:
				color = Color(0.34, 0.23, 0.16)
			draw_rect(rect, color, true)
			draw_rect(rect, Color(0.26, 0.31, 0.32), false, 1.0)

	_draw_unit(origin + Vector2(2.5, 3.5) * cell, Color(0.20, 0.55, 0.78), "A")
	_draw_unit(origin + Vector2(5.5, 2.5) * cell, Color(0.78, 0.32, 0.24), "B")


func _draw_systems_lab(area: Rect2) -> void:
	var lane_y := area.position.y + area.size.y * 0.33
	draw_line(Vector2(area.position.x + 42, lane_y), Vector2(area.end.x - 42, lane_y), Color(0.39, 0.36, 0.30), 14.0)
	for index in range(4):
		var tower_pos := Vector2(area.position.x + 120 + index * 100, lane_y + 72)
		draw_rect(Rect2(tower_pos - Vector2(18, 18), Vector2(36, 36)), Color(0.25, 0.68, 0.43), true)
		draw_arc(tower_pos, 52, 0.0, TAU, 32, Color(0.16, 0.36, 0.24), 2.0)

	for index in range(5):
		draw_circle(Vector2(area.position.x + 80 + index * 84, lane_y), 12, Color(0.78, 0.32, 0.24))

	var graph_origin := Vector2(area.position.x + 72, area.position.y + area.size.y * 0.72)
	var last := graph_origin
	for index in range(1, 8):
		var next := graph_origin + Vector2(index * 58, -pow(index, 1.45) * 7.0)
		draw_line(last, next, Color(0.86, 0.70, 0.28), 3.0)
		draw_circle(next, 4, Color(0.91, 0.82, 0.42))
		last = next


func _draw_unit(pos: Vector2, color: Color, label: String) -> void:
	draw_circle(pos, 24, color)
	draw_circle(pos, 26, Color(0.93, 0.95, 0.90), false, 2.0)
	var font := ThemeDB.get_fallback_font()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, pos - text_size * 0.5 + Vector2(0, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.96, 0.97, 0.93))


func _draw_arrow(start_pos: Vector2, end_pos: Vector2, color: Color) -> void:
	draw_line(start_pos, end_pos, color, 4.0)
	var direction := (end_pos - start_pos).normalized()
	var left := direction.rotated(2.55)
	var right := direction.rotated(-2.55)
	draw_line(end_pos, end_pos + left * 20.0, color, 4.0)
	draw_line(end_pos, end_pos + right * 20.0, color, 4.0)
