extends RefCounted

func run(tree: SceneTree) -> String:
	Quality.apply("low")
	AppState.profile["settings"]["quality"] = "low"
	AppState.profile["roam"] = {"fresh": true, "seed": 11011, "region": "İlk Kamp"}
	var err := tree.change_scene_to_file("res://scenes/roam.tscn")
	if err != OK:
		return "scene change failed"
	for _i in 6:
		await tree.process_frame
	var roam = tree.current_scene
	if roam == null or roam.get_script() == null:
		return "roam script failed to load"
	if roam.pawn == null or roam.world == null:
		return "roam scene missing"
	var pawn: PlayerPawn = roam.pawn
	var field: TerrainField = roam.field
	if field.height_span() < 20.0:
		return "play terrain flat"
	if roam.world.tree_count < 40:
		return "play trees %s" % roam.world.tree_count
	if roam.world.grass_count < 20 or roam.world.rock_count < 10:
		return "play cover trees=%s grass=%s rocks=%s" % [roam.world.tree_count, roam.world.grass_count, roam.world.rock_count]
	var bounds: Vector3 = roam.world.terrain_mesh.mesh.get_aabb().size
	if bounds.y < 15.0 or bounds.x < 400.0:
		return "play mesh %s" % bounds
	var grounded := false
	for _i in 120:
		await tree.physics_frame
		if pawn.is_on_floor():
			grounded = true
			break
	if not grounded:
		return "not grounded y=%s" % pawn.global_position.y
	await tree.process_frame
	if pawn.camera == null or not pawn.camera.current:
		return "camera missing"
	var behind := pawn.camera.global_position - pawn.global_position
	behind.y = 0.0
	var forward := PlayerPawn.planar_wish(Vector2(0, 1), pawn.yaw)
	if behind.length() < 1.2 or behind.normalized().dot(forward) > -0.55:
		return "camera not behind offset=%s forward=%s" % [behind, forward]
	var start := pawn.global_position
	pawn.script_driven = true
	pawn.move_input = Vector2(0, 1)
	pawn.sprinting = false
	for _i in 50:
		await tree.physics_frame
	var flat := pawn.global_position - start
	flat.y = 0.0
	if flat.length() < 1.2:
		return "did not walk %s" % flat.length()
	if flat.normalized().dot(PlayerPawn.planar_wish(Vector2(0, 1), pawn.yaw)) < 0.65:
		return "walked the wrong way %s" % flat
	var yaw_before := pawn.yaw
	pawn.add_look(140.0, -20.0)
	if absf(pawn.yaw - yaw_before) < 0.12:
		return "look did not turn"
	if not pawn.toggle_sit():
		return "sit refused"
	var seated := pawn.global_position
	for _i in 20:
		await tree.physics_frame
	if not pawn.sitting or pawn.global_position.distance_to(seated) > 0.45:
		return "moved while sitting"
	for _i in 8:
		await tree.process_frame
	if pawn.visual_sit < 0.4:
		return "sit pose %s" % pawn.visual_sit
	var look_while := pawn.yaw
	pawn.add_look(-90.0, 15.0)
	if absf(pawn.yaw - look_while) < 0.08 or not pawn.sitting:
		return "cannot look while sitting"
	pawn.toggle_sit()
	if roam.world.scraps.is_empty():
		return "no scrap spots"
	var spot: Vector3 = roam.world.scraps[0]
	var ground := field.height_at(spot.x, spot.z)
	pawn.place(Vector3(spot.x, ground + 0.4, spot.z), pawn.yaw, pawn.facing, pawn.pitch)
	pawn.sitting = false
	await tree.physics_frame
	if str(roam._interact()) != "scrap" or int(roam.state.scrap) != 1:
		return "scrap pickup failed"
	roam.state.hour = 22.4
	roam.state.exposure = 30.0
	var home: Vector3 = roam.world.shelter
	var hy := field.height_at(home.x, home.z)
	pawn.place(Vector3(home.x, hy + 0.4, home.z), 0.4, 0.4, -0.25)
	await tree.physics_frame
	if str(roam._interact()) != "rest" or roam.state.hour > 8.0 or roam.state.exposure > 0.01:
		return "shelter rest failed"
	pawn.place(Vector3(home.x + 5.0, hy + 0.4, home.z - 3.0), 0.8, 0.2, -0.3)
	pawn.sitting = true
	roam._save_roam()
	var saved := pawn.global_position
	var saved_yaw := pawn.yaw
	pawn.place(home + Vector3(0, 2, 18), 0.0, 0.0, 0.0)
	pawn.sitting = false
	roam._load_roam()
	var back := Vector2(pawn.global_position.x, pawn.global_position.z)
	if back.distance_to(Vector2(saved.x, saved.z)) > 0.5:
		return "resume position %s vs %s" % [back, saved]
	if absf(pawn.yaw - saved_yaw) > 0.05 or not pawn.sitting:
		return "resume look or sit"
	if int(roam.state.scrap) != 1 or not roam.state.collected.has(0):
		return "resume scrap"
	return ""
