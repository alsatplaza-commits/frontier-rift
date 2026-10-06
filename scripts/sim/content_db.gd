class_name ContentDB
extends RefCounted

static func load_levels() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return data.get("levels", [])


static func load_trivia() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/trivia.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func level_by_id(levels: Array, id: int) -> Dictionary:
	for level in levels:
		if int(level.get("id", -1)) == id:
			return level
	return {}
