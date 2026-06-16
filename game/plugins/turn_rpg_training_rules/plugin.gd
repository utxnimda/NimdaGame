extends RefCounted

var _manifest: Dictionary = {}
var _config: Dictionary = {}


func setup(manifest: Dictionary, config: Dictionary) -> void:
	_manifest = manifest
	_config = config


func get_plugin_info() -> Dictionary:
	return {
		"id": _manifest.get("id", ""),
		"name": _manifest.get("name", ""),
		"version": _manifest.get("version", ""),
		"implementation_type": "gdscript",
	}


func handle_hook(hook_id: String, payload: Dictionary) -> Dictionary:
	match hook_id:
		"turn_rpg.build_roster":
			return _handle_build_roster(payload)
		"turn_rpg.battle_started":
			return _handle_battle_started(payload)
		"turn_rpg.before_damage":
			return _handle_before_damage(payload)
		_:
			return payload


func _handle_build_roster(payload: Dictionary) -> Dictionary:
	var hp_bonus := int(_config.get("party_hp_bonus", 0))
	if hp_bonus <= 0:
		return payload

	var units: Array = payload.get("units", [])
	for index in range(units.size()):
		var unit: Dictionary = units[index]
		if String(unit.get("side", "")) != "party":
			continue

		unit["max_hp"] = int(unit.get("max_hp", 0)) + hp_bonus
		unit["hp"] = int(unit.get("hp", 0)) + hp_bonus
		units[index] = unit

	payload["units"] = units
	var log: Array = payload.get("log", [])
	log.append("Plugin Training Rules: party max HP +%d." % hp_bonus)
	payload["log"] = log
	return payload


func _handle_battle_started(payload: Dictionary) -> Dictionary:
	var log: Array = payload.get("log", [])
	log.append("Plugin Training Rules loaded from GDScript.")
	payload["log"] = log
	return payload


func _handle_before_damage(payload: Dictionary) -> Dictionary:
	var actor: Dictionary = payload.get("actor", {})
	var action: Dictionary = payload.get("action", {})
	if String(actor.get("side", "")) != "party":
		return payload
	if String(action.get("id", "")) != "fireball":
		return payload

	var bonus := int(_config.get("fireball_bonus_damage", 0))
	if bonus <= 0:
		return payload

	payload["damage"] = int(payload.get("damage", 0)) + bonus
	var log: Array = payload.get("log", [])
	log.append("Plugin Training Rules: Fireball damage +%d." % bonus)
	payload["log"] = log
	return payload
