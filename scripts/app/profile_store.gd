class_name ProfileStore
extends RefCounted

const PATH := "user://frontier_rift_save.json"
const PACK_DIR := "user://packs"


static func default_profile() -> Dictionary:
	return {
		"v": 1,
		"xp": 0,
		"cleared": 0,
		"selected_faction": "demir_pence",
		"settings": {
			"quality": Quality.pick_auto(),
			"quality_auto": true,
			"volume": 0.8,
		},
		"match": null,
	}


static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		var created := default_profile()
		save_profile(created)
		return created
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != 1:
		var created := default_profile()
		save_profile(created)
		return created
	return data


static func save_profile(profile: Dictionary) -> bool:
	if not PATH.begins_with("user://"):
		return false
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(profile))
	f.close()
	return true


static func xp_steps() -> Array:
	return [0, 40, 120, 240]


static func bar_values(xp: int) -> Dictionary:
	var steps := xp_steps()
	var prev := 0
	var nxt := int(steps[steps.size() - 1])
	for i in range(1, steps.size()):
		if xp < int(steps[i]):
			prev = int(steps[i - 1])
			nxt = int(steps[i])
			return {"prev": prev, "next": nxt, "value": xp}
	return {"prev": int(steps[steps.size() - 2]), "next": nxt, "value": nxt}
