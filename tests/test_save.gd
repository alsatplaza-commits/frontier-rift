extends RefCounted

static func run() -> String:
	if not ProfileStore.PATH.begins_with("user://"):
		return "save path is not user://"
	if not ProfileStore.PACK_DIR.begins_with("user://"):
		return "pack path is not user://"
	var profile := ProfileStore.default_profile()
	profile["xp"] = 77
	profile["cleared"] = 2
	profile["selected_faction"] = "ruzgar"
	profile["settings"] = {"quality": "low", "quality_auto": false, "volume": 0.3}
	profile["match"] = {"level_id": 2, "note": "roundtrip"}
	if not ProfileStore.save_profile(profile):
		return "save failed"
	var loaded := ProfileStore.load_profile()
	if int(loaded.get("xp", -1)) != 77:
		return "xp mismatch"
	if int(loaded.get("cleared", -1)) != 2:
		return "cleared mismatch"
	if str(loaded.get("selected_faction", "")) != "ruzgar":
		return "faction mismatch"
	if str(loaded.get("settings", {}).get("quality", "")) != "low":
		return "quality mismatch"
	if str(loaded.get("match", {}).get("note", "")) != "roundtrip":
		return "match mismatch"
	var db := FactionDB.load_all()
	var level: Dictionary = ContentDB.level_by_id(ContentDB.load_levels(), 1)
	var sim := SimWorld.new()
	sim.setup(level, db, "demir_pence")
	sim.step()
	var again := SimWorld.new()
	again.restore(sim.snapshot(), db, level)
	if again.hash_state() != sim.hash_state():
		return "sim save roundtrip"
	return ""
