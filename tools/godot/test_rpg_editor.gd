extends SceneTree
## Run with: godot --headless --path clients/godot --script ../../tools/godot/test_rpg_editor.gd

const ActorDatabase = preload("res://addons/nimda_rpg_editor/editor/actor_database.gd")
const MainScreen = preload("res://addons/nimda_rpg_editor/editor/rpg_editor_main.gd")

var _failures := 0


class FakeDatabaseClient extends "res://addons/nimda_rpg_editor/editor/database_client.gd":
	var fail_save := false
	var received_hash := ""

	func load_database(_name: String, _path: String) -> Dictionary:
		return {
			"ok": true, "error": "",
			"data": {
				"schema_version": 1, "content_type": "actors",
				"source_hash": "a".repeat(64),
				"actors": [ActorDatabase.create_default()],
			},
		}

	func save_database(
		_name: String, _path: String, payload: Dictionary, expected_hash: String
	) -> Dictionary:
		received_hash = expected_hash
		if fail_save:
			return {"ok": false, "data": {}, "error": "Simulated conflict"}
		var data := payload.duplicate(true)
		data["content_type"] = "actors"
		data["source_hash"] = "b".repeat(64)
		return {"ok": true, "data": data, "error": ""}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := MainScreen.new()
	var client := FakeDatabaseClient.new()
	screen._data_client = client
	root.add_child(screen)
	# Allow the screen's deferred load to complete.
	await process_frame
	await process_frame
	_expect(screen._actors.size() == 1, "Initial records load")
	_expect(not screen._dirty, "Populating the form must not mark it dirty")
	_expect(screen._selected_actor_index == 0, "Initial selection is valid")

	screen._duplicate_actor()
	_expect(screen._actors.size() == 2, "Duplicate creates a record")
	_expect(screen._actors[0]["id"] != screen._actors[1]["id"], "Duplicate receives a new ID")
	var attack: SpinBox = screen._form._fields["base_stats.attack"]
	attack.value = 42
	_expect(screen._actors[1]["base_stats"]["attack"] == 42, "Number changes reach the selected record")
	_expect(screen._actors[0]["base_stats"]["attack"] == 10, "Duplicate owns independent stats")

	client.fail_save = true
	screen._save_data()
	_expect(screen._dirty, "Failed saves keep unsaved edits")
	_expect(screen._actors[1]["base_stats"]["attack"] == 42, "Failed saves preserve records")
	_expect(client.received_hash == "a".repeat(64), "Save sends the loaded source hash")
	screen._error_dialog.hide()

	client.fail_save = false
	screen._save_data()
	_expect(not screen._dirty, "Successful saves clear dirty state")
	_expect(screen._source_hash == "b".repeat(64), "Successful saves refresh the source hash")

	screen._search_edit.text = "no_matching_actor"
	screen._on_search_changed("")
	_expect(screen._selected_actor_index == -1, "Empty search clears selection")
	_expect(screen._delete_button.disabled, "Empty search disables deletion")
	screen._add_actor()
	_expect(screen._actors.size() == 3, "Adding after empty search works")
	_expect(screen._selected_actor_index == 2, "Adding clears search and selects the new record")

	# Values accepted by the schema must not be silently clamped on load.
	screen._actors[2]["base_stats"]["attack"] = 2000000
	screen._populate_form()
	_expect(attack.value == 2000000, "Form preserves values above its suggested numeric range")

	for _index in range(screen._actors.size()):
		screen._delete_actor()
	_expect(screen._selected_actor_index == -1, "Deleting the last actor clears selection")
	_expect(screen._duplicate_button.disabled, "An empty database disables duplication")
	screen.free()
	if _failures == 0:
		print("RPG editor behavior checks passed.")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
