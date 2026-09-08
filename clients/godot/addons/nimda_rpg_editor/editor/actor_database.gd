@tool
extends RefCounted
## Pure actor helpers. Python remains the authoritative validation boundary.

const STAT_FIELDS: Array[String] = [
	"max_hp",
	"max_mp",
	"attack",
	"defense",
	"magic_attack",
	"magic_defense",
	"agility",
	"luck",
]


static func validate(actors: Array) -> Array[String]:
	var errors: Array[String] = []
	var actor_id_pattern := RegEx.new()
	actor_id_pattern.compile("^actor_[a-z0-9_]+$")
	var class_id_pattern := RegEx.new()
	class_id_pattern.compile("^class_[a-z0-9_]+$")
	var seen_ids: Dictionary = {}

	for index in range(actors.size()):
		var actor: Dictionary = actors[index]
		var prefix := "Actor %d" % (index + 1)
		var actor_id := String(actor.get("id", ""))
		if actor_id_pattern.search(actor_id) == null:
			errors.append("%s has an invalid ID." % prefix)
		elif seen_ids.has(actor_id):
			errors.append("%s duplicates ID '%s'." % [prefix, actor_id])
		else:
			seen_ids[actor_id] = true

		if String(actor.get("name", "")).strip_edges().is_empty():
			errors.append("%s requires a name." % prefix)
		if class_id_pattern.search(String(actor.get("class_id", ""))) == null:
			errors.append("%s has an invalid class ID." % prefix)
		if int(actor.get("initial_level", 1)) > int(actor.get("max_level", 1)):
			errors.append("%s initial level exceeds max level." % prefix)

		var stats: Dictionary = actor.get("base_stats", {})
		for stat_name in STAT_FIELDS:
			var minimum := 1 if stat_name == "max_hp" else 0
			if int(stats.get(stat_name, -1)) < minimum:
				errors.append("%s has an invalid %s value." % [prefix, stat_name])

	return errors


static func normalize(source: Dictionary) -> Dictionary:
	var source_assets: Dictionary = source.get("assets", {})
	var source_stats: Dictionary = source.get("base_stats", {})
	var stats: Dictionary = {}
	for stat_name in STAT_FIELDS:
		stats[stat_name] = int(source_stats.get(stat_name, 0))

	return {
		"id": String(source.get("id", "")),
		"legacy_id": int(source.get("legacy_id", 0)),
		"name": String(source.get("name", "")),
		"nickname": String(source.get("nickname", "")),
		"profile": String(source.get("profile", "")),
		"class_id": String(source.get("class_id", "")),
		"initial_level": int(source.get("initial_level", 1)),
		"max_level": int(source.get("max_level", 99)),
		"assets": {
			"portrait": String(source_assets.get("portrait", "")),
			"map_sprite": String(source_assets.get("map_sprite", "")),
			"battle_sprite": String(source_assets.get("battle_sprite", "")),
		},
		"base_stats": stats,
	}


static func create_default() -> Dictionary:
	return {
		"id": "actor_new",
		"legacy_id": 0,
		"name": "New Actor",
		"nickname": "",
		"profile": "",
		"class_id": "class_adventurer",
		"initial_level": 1,
		"max_level": 99,
		"assets": {
			"portrait": "",
			"map_sprite": "",
			"battle_sprite": "",
		},
		"base_stats": {
			"max_hp": 100,
			"max_mp": 20,
			"attack": 10,
			"defense": 10,
			"magic_attack": 10,
			"magic_defense": 10,
			"agility": 10,
			"luck": 10,
		},
	}


static func unique_id(actors: Array, base_id: String) -> String:
	var candidate := base_id
	var suffix := 2
	while has_id(actors, candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate


static func has_id(actors: Array, actor_id: String) -> bool:
	for actor_value in actors:
		var actor: Dictionary = actor_value
		if String(actor.get("id", "")) == actor_id:
			return true
	return false


static func next_legacy_id(actors: Array) -> int:
	var highest := 0
	for actor_value in actors:
		var actor: Dictionary = actor_value
		highest = maxi(highest, int(actor.get("legacy_id", 0)))
	return highest + 1
