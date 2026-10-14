extends RefCounted

static func run() -> String:
	var field := TerrainField.new()
	field.configure(11011)
	if field.height_span() < 20.0:
		return "terrain too flat: %s" % field.height_span()
	var again := TerrainField.new()
	again.configure(11011)
	if absf(field.height_at(12.0, -40.0) - again.height_at(12.0, -40.0)) > 0.0001:
		return "height not deterministic"
	var other := TerrainField.new()
	other.configure(22022)
	if absf(field.height_at(12.0, -40.0) - other.height_at(12.0, -40.0)) < 0.05:
		return "seeds did not change the land"
	var counts: Dictionary = field.biome_counts(4)
	if int(counts.grass) < 8 or int(counts.rock) < 4 or int(counts.sand) < 4:
		return "biome mix %s" % str(counts)
	if int(counts.below_water) < 2:
		return "river missing"
	var world := WorldBuild.new()
	world.plan(field)
	if world.scraps.size() < 4:
		return "not enough scrap"
	if world.shelter.y < field.water_level + 1.0:
		return "shelter in the water"
	if world.shelter.distance_to(world.tower) < 60.0:
		return "landmarks too close"
	var forward := PlayerPawn.planar_wish(Vector2(0, 1), 0.0)
	if forward.distance_to(Vector3(0, 0, -1)) > 0.001:
		return "forward wish %s" % forward
	var east := PlayerPawn.planar_wish(Vector2(0, 1), -PI * 0.5)
	if east.distance_to(Vector3(1, 0, 0)) > 0.001:
		return "east wish %s" % east
	for tier in ["low", "medium", "high"]:
		var b: Dictionary = Quality.budget(tier)
		if int(b.trees) < 40 or float(b.fog_end) < 100.0:
			return "quality budget " + tier
	if bool(Quality.budget("low").shadows):
		return "low still shadows"
	if not bool(Quality.budget("high").shadows):
		return "high missing shadows"
	var state := RoamState.new()
	state.hour = 22.0
	state.advance(2.0, false)
	if not state.is_night() or state.exposure < 4.0:
		return "night exposure"
	state.advance(1.0, true)
	if state.exposure > 4.0:
		return "shelter did not calm exposure"
	var scraps: Array = [Vector3(3, 0, 0), Vector3(80, 0, 0)]
	if not state.try_collect(0, Vector3(3.2, 1, 0.2), scraps):
		return "collect failed"
	if state.try_collect(0, Vector3(3.2, 1, 0.2), scraps):
		return "collected twice"
	if state.scrap != 1:
		return "scrap count"
	if not state.try_rest(Vector3(1, 0, 1), Vector3.ZERO):
		return "rest failed"
	if state.hour > 8.0 or state.exposure > 0.01:
		return "rest state"
	var profile := ProfileStore.default_profile()
	profile["roam"] = state.to_dict()
	if not ProfileStore.save_profile(profile):
		return "roam save failed"
	var loaded: Dictionary = ProfileStore.load_profile()
	var back := RoamState.from_dict(loaded.roam)
	if back.scrap != 1 or not back.collected.has(0):
		return "roam load scrap"
	if absf(back.hour - state.hour) > 0.001:
		return "roam load hour"
	var menu := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	var regions := FileAccess.get_file_as_string("res://scripts/ui/level_select.gd")
	if not menu.contains("res://scenes/roam.tscn") or menu.contains("res://scenes/match.tscn"):
		return "menu still points at the flat match"
	if regions.contains("res://scenes/match.tscn"):
		return "region select still points at the flat match"
	return ""
