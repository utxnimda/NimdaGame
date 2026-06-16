class_name DemoCatalog

static func get_categories() -> Array:
	return [
		{
			"id": "turn_rpg",
			"title": "Turn RPG",
			"summary": "Command selection, party roles, deterministic turn order, and a readable battle log.",
			"loop": [
				"Choose command",
				"Resolve skill and status effects",
				"Advance turn queue",
				"Present battle log",
			],
			"systems": [
				"Unit stats",
				"Skill effects",
				"Status lifecycle",
				"Deterministic RNG",
			],
			"release_checks": [
				"Battle screen loads",
				"Demo data is bundled",
				"One attack resolves consistently",
			],
		},
		{
			"id": "arpg",
			"title": "ARPG / Survivor",
			"summary": "Real-time movement, enemy pressure, cooldown skills, pickups, and short-session combat pacing.",
			"loop": [
				"Move and kite",
				"Auto-fire or cast skills",
				"Collect rewards",
				"Scale waves over time",
			],
			"systems": [
				"Runtime spawning",
				"Cooldown ticking",
				"Area queries",
				"Performance counters",
			],
			"release_checks": [
				"Input responds after export",
				"Frame pacing is acceptable",
				"Timed wave script runs",
			],
		},
		{
			"id": "tactics",
			"title": "Tactics",
			"summary": "Grid movement, range preview, turn ownership, terrain rules, and tactical command resolution.",
			"loop": [
				"Select unit",
				"Preview move and attack range",
				"Commit action",
				"End side turn",
			],
			"systems": [
				"Grid coordinates",
				"Pathfinding",
				"Line and area targeting",
				"Turn ownership",
			],
			"release_checks": [
				"Grid renders cleanly",
				"Selection state survives scene reload",
				"Path preview has no missing assets",
			],
		},
		{
			"id": "systems_lab",
			"title": "Systems Lab",
			"summary": "A shared bucket for tower defense, idle/incremental, cards, roguelite rewards, and meta progression.",
			"loop": [
				"Place or upgrade a system object",
				"Run economy or wave tick",
				"Collect resources",
				"Spend into long-term progression",
			],
			"systems": [
				"Tower defense lanes",
				"Incremental formulas",
				"Reward tables",
				"Save migration",
			],
			"release_checks": [
				"Save path is writable",
				"Offline reward math is deterministic",
				"Package contains config schemas",
			],
		},
	]
