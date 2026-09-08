@tool
extends VBoxContainer
## Reusable text/number form. Loading a record never emits user-change signals.

signal value_changed(key: String, value: Variant)

var _fields: Dictionary = {}
var _updating := false


func add_section(title: String) -> GridContainer:
	if get_child_count() > 0:
		add_child(HSeparator.new())
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	return grid


func add_line_field(grid: GridContainer, label_text: String, key: String) -> void:
	grid.add_child(_field_label(label_text))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_value_changed.bind(key))
	grid.add_child(edit)
	_fields[key] = edit


func add_multiline_field(grid: GridContainer, label_text: String, key: String) -> void:
	grid.add_child(_field_label(label_text))
	var edit := TextEdit.new()
	edit.custom_minimum_size.y = 96
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_multiline_changed.bind(key))
	grid.add_child(edit)
	_fields[key] = edit


func add_spin_field(
	grid: GridContainer,
	label_text: String,
	key: String,
	minimum: int,
	maximum: int
) -> void:
	grid.add_child(_field_label(label_text))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.allow_greater = true
	spin.allow_lesser = false
	spin.update_on_text_changed = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_number_changed.bind(key))
	grid.add_child(spin)
	_fields[key] = spin


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 130
	return label


func set_record(record: Dictionary) -> void:
	_updating = true
	for key in _fields:
		var control: Control = _fields[key]
		var value: Variant = _get_value(record, key)
		if control is LineEdit or control is TextEdit:
			control.text = "" if value == null else String(value)
		elif control is SpinBox:
			control.value = control.min_value if value == null else float(value)
	_updating = false


func clear() -> void:
	set_record({})
	set_editable(false)


func set_editable(enabled: bool) -> void:
	for control in _fields.values():
		control.editable = enabled


func _get_value(record: Dictionary, key: String) -> Variant:
	var value: Variant = record
	for part in key.split("."):
		if not value is Dictionary:
			return null
		value = value.get(part)
	return value


func _on_value_changed(value: Variant, key: String) -> void:
	if not _updating:
		value_changed.emit(key, value)


func _on_multiline_changed(key: String) -> void:
	_on_value_changed(_fields[key].text, key)


func _on_number_changed(value: float, key: String) -> void:
	_on_value_changed(int(value), key)
