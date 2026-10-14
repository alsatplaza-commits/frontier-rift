class_name WorldBuild
extends RefCounted

var shelter := Vector3.ZERO
var tower := Vector3.ZERO
var spawn := Vector3.ZERO
var spawn_yaw := 0.0
var scraps: Array[Vector3] = []
var tree_count := 0
var rock_count := 0
var grass_count := 0
var terrain_mesh: MeshInstance3D
var fire_light: OmniLight3D
var scrap_nodes: Array[MeshInstance3D] = []


func plan(field: TerrainField) -> void:
	_pick_shelter(field)
	_pick_tower(field)
	_pick_scraps(field)
	var view := Vector3(-sin(spawn_yaw), 0.0, -cos(spawn_yaw))
	spawn = shelter - view * 8.0
	spawn.y = field.height_at(spawn.x, spawn.z)
	if spawn.y < field.water_level + 1.4:
		spawn = shelter + Vector3(view.z, 0.0, -view.x) * 8.0
		spawn.y = field.height_at(spawn.x, spawn.z)
	spawn.y += 2.0
	field.trail_from = Vector2(shelter.x, shelter.z)
	field.trail_to = Vector2(tower.x, tower.z)
	field.trail_on = true


func build(parent: Node3D, field: TerrainField, budget: Dictionary) -> void:
	plan(field)
	_build_terrain(parent, field)
	_build_water(parent, field)
	_build_trees(parent, field, budget)
	_build_rocks(parent, field, budget)
	_build_grass(parent, field, budget)
	_build_camp(parent, field)
	_build_tower(parent)
	_build_scraps(parent)


static func make_atmosphere(parent: Node) -> Dictionary:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.65
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.light_energy = 1.3
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	parent.add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.shadow_enabled = false
	moon.light_color = Color(0.62, 0.72, 0.95)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(moon)
	return {"env": env, "sky": sky_mat, "sun": sun, "moon": moon}


static func paint_hour(atmo: Dictionary, hour: float, budget: Dictionary, fire: OmniLight3D) -> void:
	var env: Environment = atmo.env
	var sky: ProceduralSkyMaterial = atmo.sky
	var sun: DirectionalLight3D = atmo.sun
	var moon: DirectionalLight3D = atmo.moon
	var elev := sin((hour - 6.0) / 12.0 * PI)
	var day := clampf(elev, 0.0, 1.0)
	var night := clampf(-elev, 0.0, 1.0)
	var pitch := lerpf(-0.08, -1.15, day)
	sun.rotation = Vector3(pitch, deg_to_rad(28.0 + hour * 8.0), 0.0)
	sun.light_energy = day * 1.45
	sun.light_color = Color(1.0, 0.55, 0.32).lerp(Color(1.0, 0.97, 0.90), smoothstep(0.15, 0.75, day))
	sun.shadow_enabled = bool(budget.get("shadows", false)) and day > 0.08
	sun.directional_shadow_max_distance = float(budget.get("shadow_distance", 120.0))
	moon.rotation = Vector3(-0.8, sun.rotation.y + PI, 0.0)
	moon.light_energy = lerpf(0.04, 0.38, night)
	var horizon := Color(0.10, 0.09, 0.14).lerp(Color(0.74, 0.83, 0.90), day)
	if hour > 5.2 and hour < 9.0:
		horizon = horizon.lerp(Color(0.90, 0.48, 0.28), 1.0 - (hour - 5.2) / 3.8)
	elif hour > 16.5 and hour < 20.2:
		horizon = horizon.lerp(Color(0.86, 0.38, 0.22), clampf((hour - 16.5) / 3.0, 0.0, 1.0) * (1.0 - day + 0.2))
	sky.sky_top_color = Color(0.02, 0.03, 0.08).lerp(Color(0.27, 0.48, 0.82), day)
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon.lerp(Color(0.30, 0.34, 0.26), 0.35)
	sky.ground_bottom_color = Color(0.14, 0.16, 0.12)
	sky.sky_curve = 0.10
	sky.sun_angle_max = 26.0
	env.ambient_light_energy = lerpf(0.24, 0.62, day)
	env.tonemap_exposure = lerpf(0.86, 1.06, day)
	env.fog_depth_begin = 36.0
	env.fog_depth_end = float(budget.get("fog_end", 420.0))
	env.fog_depth_curve = 1.12
	env.fog_light_color = Color(0.05, 0.06, 0.10).lerp(Color(0.66, 0.76, 0.84), day)
	if fire:
		fire.light_energy = lerpf(0.35, 2.4, clampf(night + (0.35 if hour > 17.0 else 0.0), 0.0, 1.0))


func minimap_image(field: TerrainField) -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var wx := (float(x) / float(n - 1) - 0.5) * field.size
			var wz := (float(y) / float(n - 1) - 0.5) * field.size
			img.set_pixel(x, y, field.color_at(wx, wz))
	_stamp(img, field, shelter, Color(0.95, 0.82, 0.30))
	_stamp(img, field, tower, Color(0.90, 0.35, 0.25))
	for spot in scraps:
		_stamp(img, field, spot, Color(0.95, 0.55, 0.15))
	return img


func _stamp(img: Image, field: TerrainField, pos: Vector3, color: Color) -> void:
	var n := img.get_width()
	var u := int((pos.x / field.size + 0.5) * float(n - 1))
	var v := int((pos.z / field.size + 0.5) * float(n - 1))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := clampi(u + dx, 0, n - 1)
			var y := clampi(v + dy, 0, n - 1)
			img.set_pixel(x, y, color)


func _pick_shelter(field: TerrainField) -> void:
	var best := -1e20
	var found := Vector3(0, field.height_at(0, 40), 40)
	for iz in range(12, field.grid - 12, 3):
		for ix in range(12, field.grid - 12, 3):
			var p := field.cell_pos(ix, iz)
			var slope := field.slope_at(p.x, p.z)
			if p.y < field.water_level + 2.0 or p.y > 18.0 or slope > 0.36:
				continue
			var score := -slope * 50.0 - absf(p.y - 8.5) - Vector2(p.x, p.z - 40.0).length() * 0.01
			if score > best:
				best = score
				found = p
	shelter = found


func _pick_tower(field: TerrainField) -> void:
	var best := -1e20
	var found := shelter + Vector3(0, 0, -120)
	found.y = field.height_at(found.x, found.z)
	for iz in range(10, field.grid - 10, 3):
		for ix in range(10, field.grid - 10, 3):
			var p := field.cell_pos(ix, iz)
			if p.distance_to(shelter) < 90.0:
				continue
			var slope := field.slope_at(p.x, p.z)
			if slope > 0.4 or p.y < field.water_level + 6.0:
				continue
			var score := p.y - slope * 10.0
			if score > best:
				best = score
				found = p
	tower = found
	var dir := tower - shelter
	spawn_yaw = atan2(-dir.x, -dir.z)


func _pick_scraps(field: TerrainField) -> void:
	var cands: Array = []
	for iz in range(8, field.grid - 8, 4):
		for ix in range(8, field.grid - 8, 4):
			var p := field.cell_pos(ix, iz)
			var slope := field.slope_at(p.x, p.z)
			if p.y < field.water_level + 1.3 or p.y > 28.0 or slope > 0.38:
				continue
			if p.distance_to(shelter) < 24.0:
				continue
			cands.append({"h": field._hash(ix * 3 + 11, iz * 5 + 2), "p": p})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.h) < float(b.h)
	)
	var picked: Array[Vector3] = []
	for cand in cands:
		var spot: Vector3 = cand.p
		var clear := true
		for prev in picked:
			if spot.distance_to(prev) < 70.0:
				clear = false
				break
		if clear:
			picked.append(spot)
		if picked.size() >= 8:
			break
	if picked.size() < 4:
		for cand in cands:
			var spot: Vector3 = cand.p
			if picked.has(spot):
				continue
			picked.append(spot)
			if picked.size() >= 4:
				break
	scraps = picked


func _build_terrain(parent: Node3D, field: TerrainField) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := field.grid
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = field.cell_pos(ix, iz).y
	for iz in n - 1:
		for ix in n - 1:
			var p00 := _grid_vertex(field, heights, ix, iz)
			var p10 := _grid_vertex(field, heights, ix + 1, iz)
			var p01 := _grid_vertex(field, heights, ix, iz + 1)
			var p11 := _grid_vertex(field, heights, ix + 1, iz + 1)
			_tri_cached(st, field, heights, p00, p10, p11)
			_tri_cached(st, field, heights, p00, p11, p01)
	st.index()
	var mesh := st.commit()
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = mesh
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain_mesh.material_override = mat
	parent.add_child(terrain_mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	col.shape = shape
	col.scale = Vector3(field.cell, 1.0, field.cell)
	body.add_child(col)
	parent.add_child(body)


func _grid_vertex(field: TerrainField, heights: PackedFloat32Array, ix: int, iz: int) -> Vector3:
	var x := (float(ix) - float(field.grid - 1) * 0.5) * field.cell
	var z := (float(iz) - float(field.grid - 1) * 0.5) * field.cell
	return Vector3(x, heights[iz * field.grid + ix], z)


func _grid_slope_normal(field: TerrainField, heights: PackedFloat32Array, ix: int, iz: int) -> Dictionary:
	var n := field.grid
	var hl: float = heights[iz * n + maxi(ix - 1, 0)]
	var hr: float = heights[iz * n + mini(ix + 1, n - 1)]
	var hd: float = heights[maxi(iz - 1, 0) * n + ix]
	var hu: float = heights[mini(iz + 1, n - 1) * n + ix]
	var dx := (hr - hl) / (2.0 * field.cell)
	var dz := (hu - hd) / (2.0 * field.cell)
	return {
		"slope": sqrt(dx * dx + dz * dz),
		"normal": Vector3(-dx, 1.0, -dz).normalized(),
	}


func _tri_cached(st: SurfaceTool, field: TerrainField, heights: PackedFloat32Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		var gx := int(round((p.x / field.cell) + float(field.grid - 1) * 0.5))
		var gz := int(round((p.z / field.cell) + float(field.grid - 1) * 0.5))
		var info := _grid_slope_normal(field, heights, gx, gz)
		st.set_color(field.color_of(p.x, p.z, p.y, float(info.slope)))
		st.set_normal(info.normal)
		st.add_vertex(p)


func _build_water(parent: Node3D, field: TerrainField) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(field.size * 1.08, field.size * 1.08)
	water.mesh = plane
	water.position.y = field.water_level
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.36, 0.46, 0.78)
	mat.roughness = 0.08
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = mat
	parent.add_child(water)


func _build_trees(parent: Node3D, field: TerrainField, budget: Dictionary) -> void:
	var want := int(budget.get("trees", 200))
	var records: Array = []
	for iz in range(4, field.grid - 4, 2):
		for ix in range(4, field.grid - 4, 2):
			var roll := field._hash(ix + 17, iz + 29)
			if roll > 0.42:
				continue
			var p := field.cell_pos(ix, iz)
			var slope := field.slope_at(p.x, p.z)
			if p.y < field.water_level + 1.1 or slope > 0.5 or p.y > 42.0:
				continue
			if Vector2(p.x, p.z).distance_to(Vector2(shelter.x, shelter.z)) < 16.0:
				continue
			var pine := roll > 0.2 or p.y > 22.0
			if pine and p.y < 6.0:
				pine = false
			var s := lerpf(0.75, 1.45, field._hash(ix + 3, iz + 9))
			var rot := field._hash(ix, iz + 4) * TAU
			var basis := Basis(Vector3.UP, rot).scaled(Vector3(s, s, s))
			var ground := p + Vector3(0, 0.05, 0)
			var tint := Color(0.12, 0.32, 0.16).lerp(Color(0.22, 0.40, 0.18), roll) if pine else Color(0.16, 0.40, 0.14).lerp(Color(0.34, 0.52, 0.18), roll)
			records.append({
				"pine": pine,
				"trunk": Transform3D(basis, ground + Vector3(0, 1.05 * s, 0)),
				"canopy": Transform3D(basis, ground + Vector3(0, (2.7 if pine else 2.35) * s, 0)),
				"tint": tint,
			})
	while records.size() > want:
		records.remove_at(records.size() - 1)
	var rounds: Array[Transform3D] = []
	var round_colors: Array[Color] = []
	var pines: Array[Transform3D] = []
	var pine_colors: Array[Color] = []
	var trunks: Array[Transform3D] = []
	for rec in records:
		trunks.append(rec.trunk)
		if bool(rec.pine):
			pines.append(rec.canopy)
			pine_colors.append(rec.tint)
		else:
			rounds.append(rec.canopy)
			round_colors.append(rec.tint)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 2.1
	trunk_mesh.radial_segments = 6
	var round_mesh := SphereMesh.new()
	round_mesh.radius = 1.35
	round_mesh.height = 2.1
	round_mesh.radial_segments = 7
	round_mesh.rings = 4
	var pine_mesh := CylinderMesh.new()
	pine_mesh.top_radius = 0.05
	pine_mesh.bottom_radius = 1.25
	pine_mesh.height = 3.1
	pine_mesh.radial_segments = 7
	_instances(parent, trunk_mesh, _solid(Color(0.36, 0.24, 0.14), 0.9), trunks, _fill(Color(0.40, 0.27, 0.16), trunks.size()))
	_instances(parent, round_mesh, _solid(Color(0.2, 0.45, 0.16), 0.86), rounds, round_colors)
	_instances(parent, pine_mesh, _solid(Color(0.14, 0.34, 0.16), 0.86), pines, pine_colors)
	tree_count = rounds.size() + pines.size()


func _build_rocks(parent: Node3D, field: TerrainField, budget: Dictionary) -> void:
	var want := int(budget.get("rocks", 60))
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for iz in range(3, field.grid - 3, 3):
		for ix in range(3, field.grid - 3, 3):
			var roll := field._hash(ix + 41, iz + 13)
			if roll > 0.28:
				continue
			var p := field.cell_pos(ix, iz)
			var slope := field.slope_at(p.x, p.z)
			if p.y < field.water_level + 0.4:
				continue
			if slope < 0.18 and roll > 0.12:
				continue
			var s := lerpf(0.35, 2.1, roll)
			var basis := Basis(Vector3.UP, roll * TAU).scaled(Vector3(s * 1.4, s * 0.7, s))
			xforms.append(Transform3D(basis, p + Vector3(0, s * 0.25, 0)))
			colors.append(Color(0.42, 0.40, 0.38).lerp(Color(0.28, 0.30, 0.32), field._hash(ix, iz + 8)))
			if xforms.size() >= want * 3:
				break
		if xforms.size() >= want * 3:
			break
	_trim_pairs(xforms, want)
	while colors.size() > xforms.size():
		colors.remove_at(colors.size() - 1)
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.3
	mesh.radial_segments = 6
	mesh.rings = 3
	_instances(parent, mesh, _solid(Color(0.45, 0.44, 0.42), 0.95), xforms, colors)
	rock_count = xforms.size()


func _build_grass(parent: Node3D, field: TerrainField, budget: Dictionary) -> void:
	var want := int(budget.get("grass", 0))
	if want <= 0:
		grass_count = 0
		return
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var mesh := _grass_mesh()
	for iz in range(2, field.grid - 2, 2):
		for ix in range(2, field.grid - 2, 2):
			var roll := field._hash(ix + 5, iz + 71)
			if roll > 0.55:
				continue
			var p := field.cell_pos(ix, iz)
			if field.biome_at(p.x, p.z) != "grass":
				continue
			if Vector2(p.x, p.z).distance_to(Vector2(shelter.x, shelter.z)) < 7.0:
				continue
			var s := lerpf(0.7, 1.3, roll)
			var basis := Basis(Vector3.UP, roll * TAU).scaled(Vector3(s, s, s))
			xforms.append(Transform3D(basis, p))
			colors.append(Color(0.28, 0.50, 0.18).lerp(Color(0.46, 0.58, 0.20), roll))
			if xforms.size() >= want:
				break
		if xforms.size() >= want:
			break
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_instances(parent, mesh, mat, xforms, colors)
	grass_count = xforms.size()


func _build_camp(parent: Node3D, field: TerrainField) -> void:
	var camp := Node3D.new()
	camp.position = shelter
	camp.rotation.y = spawn_yaw
	parent.add_child(camp)
	var wood := Color(0.40, 0.28, 0.16)
	var wall := Color(0.52, 0.48, 0.40)
	var roof := Color(0.38, 0.22, 0.16)
	_box(camp, Vector3(4.6, 0.22, 5.4), Vector3(0, 0.11, 0), wood)
	_box(camp, Vector3(0.18, 2.15, 5.4), Vector3(-2.2, 1.2, 0), wall)
	_box(camp, Vector3(0.18, 2.15, 5.4), Vector3(2.2, 1.2, 0), wall)
	_box(camp, Vector3(4.4, 2.15, 0.18), Vector3(0, 1.2, -2.6), wall)
	_box(camp, Vector3(1.5, 2.15, 0.18), Vector3(-1.45, 1.2, 2.6), wall)
	_box(camp, Vector3(1.5, 2.15, 0.18), Vector3(1.45, 1.2, 2.6), wall)
	var prism := PrismMesh.new()
	prism.size = Vector3(4.9, 1.15, 5.8)
	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = prism
	roof_inst.position = Vector3(0, 2.7, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof
	roof_mat.roughness = 0.85
	roof_inst.material_override = roof_mat
	camp.add_child(roof_inst)
	_box(camp, Vector3(1.4, 0.12, 0.42), Vector3(0, 0.45, 4.3), wood)
	_box(camp, Vector3(0.12, 0.42, 0.42), Vector3(-0.55, 0.22, 4.3), wood.darkened(0.2))
	_box(camp, Vector3(0.12, 0.42, 0.42), Vector3(0.55, 0.22, 4.3), wood.darkened(0.2))
	var log := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.18
	cyl.height = 2.2
	cyl.radial_segments = 7
	log.mesh = cyl
	log.rotation.z = PI * 0.5
	log.position = Vector3(1.8, 0.2, 3.6)
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = wood.darkened(0.25)
	log.material_override = log_mat
	camp.add_child(log)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(-1.5, 0.8, 3.4)
	fire_light.light_color = Color(1.0, 0.55, 0.22)
	fire_light.omni_range = 14.0
	fire_light.shadow_enabled = false
	camp.add_child(fire_light)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.18
	flame_mesh.height = 0.45
	flame.mesh = flame_mesh
	flame.position = Vector3(-1.5, 0.35, 3.4)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.45, 0.1)
	flame_mat.emission_energy_multiplier = 1.4
	flame.material_override = flame_mat
	camp.add_child(flame)


func _build_tower(parent: Node3D) -> void:
	var root := Node3D.new()
	root.position = tower
	parent.add_child(root)
	var timber := Color(0.34, 0.30, 0.26)
	for side in [Vector3(-0.7, 3.2, -0.7), Vector3(0.7, 3.2, -0.7), Vector3(-0.7, 3.2, 0.7), Vector3(0.7, 3.2, 0.7)]:
		_box(root, Vector3(0.16, 6.4, 0.16), side, timber)
	_box(root, Vector3(2.2, 0.16, 2.2), Vector3(0, 6.3, 0), Color(0.45, 0.40, 0.32))
	_box(root, Vector3(0.12, 3.2, 0.12), Vector3(0, 8.0, 0), Color(0.25, 0.27, 0.30))
	var flag := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.7, 0.4, 0.05)
	flag.mesh = cloth
	flag.position = Vector3(0.4, 8.8, 0)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.75, 0.28, 0.18)
	flag.material_override = flag_mat
	root.add_child(flag)


func _build_scraps(parent: Node3D) -> void:
	for spot in scraps:
		var crate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.45, 0.55)
		crate.mesh = box
		crate.position = spot + Vector3(0, 0.32, 0)
		crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.32, 0.18)
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.42, 0.12)
		mat.emission_energy_multiplier = 0.35
		mat.roughness = 0.55
		crate.material_override = mat
		crate.set_meta("base_y", crate.position.y)
		parent.add_child(crate)
		scrap_nodes.append(crate)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.position = at
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	inst.material_override = mat
	parent.add_child(inst)


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.vertex_color_use_as_albedo = true
	return mat


func _fill(color: Color, count: int) -> Array[Color]:
	var colors: Array[Color] = []
	colors.resize(count)
	for i in count:
		colors[i] = color
	return colors


func _instances(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(inst)


func _trim_pairs(items: Array[Transform3D], want: int) -> void:
	if want < 1:
		items.clear()
		return
	while items.size() > want:
		items.remove_at(items.size() - 1)


func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rot in [0.0, PI * 0.5]:
		var basis := Basis(Vector3.UP, rot)
		var normal := (basis * Vector3(0, 0, 1)).normalized()
		var pts := PackedVector3Array([
			basis * Vector3(-0.28, 0.0, 0.0),
			basis * Vector3(0.28, 0.0, 0.0),
			basis * Vector3(0.22, 0.72, 0.0),
			basis * Vector3(-0.22, 0.72, 0.0),
		])
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normal)
			st.set_color(Color(0.4, 0.62, 0.24))
			st.add_vertex(pts[idx])
	return st.commit()
