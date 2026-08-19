class_name DataLoader
extends RefCounted

static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Invalid JSON: %s" % path)
		return {}
	return parsed

static func move_map() -> Dictionary:
	var result: Dictionary = {}
	for item in load_json("res://data/moves.json"):
		result[str(item["id"])] = item
	return result

static func monsters() -> Array:
	return load_json("res://data/monsters.json")
