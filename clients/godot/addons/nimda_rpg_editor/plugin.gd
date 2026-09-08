@tool
extends EditorPlugin

const MainScreen = preload("res://addons/nimda_rpg_editor/editor/rpg_editor_main.gd")

var _main_screen: Control


func _enter_tree() -> void:
	_main_screen = MainScreen.new()
	_main_screen.name = "NimdaRpgEditor"
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(_main_screen):
		_main_screen.queue_free()
	_main_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_main_screen):
		_main_screen.visible = visible


func _get_plugin_name() -> String:
	return "RPG Editor"


func _get_plugin_icon() -> Texture2D:
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme.has_icon("Database", "EditorIcons"):
		return editor_theme.get_icon("Database", "EditorIcons")
	return editor_theme.get_icon("Script", "EditorIcons")
