class_name FactionDB
extends RefCounted

static func load_all() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://data/factions")
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for name in files:
		if not str(name).ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://data/factions/%s" % name)
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		out[str(data["id"])] = data
	return out


static func color_of(faction: Dictionary) -> Color:
	return Color.html(str(faction.get("color", "#FFFFFF")))
