class_name Quality
extends RefCounted

static func pick_auto() -> String:
	var cores := OS.get_processor_count()
	var mobile := OS.has_feature("android") or OS.has_feature("mobile")
	var mem := 0
	if OS.has_method("get_memory_info"):
		mem = int(OS.get_memory_info().get("physical", 0))
	if mobile:
		if cores <= 4 or (mem > 0 and mem < 3000000000):
			return "low"
		return "medium"
	if cores <= 2 or (mem > 0 and mem < 4000000000):
		return "low"
	if cores <= 6 or (mem > 0 and mem < 8000000000):
		return "medium"
	return "high"


static func budget(q: String) -> Dictionary:
	if q == "low":
		return {
			"trees": 150,
			"grass": 160,
			"rocks": 50,
			"shadows": false,
			"shadow_size": 1024,
			"shadow_bits": true,
			"shadow_distance": 90.0,
			"fog_end": 280.0,
			"msaa": Viewport.MSAA_DISABLED,
			"scale": 0.75,
		}
	if q == "high":
		return {
			"trees": 460,
			"grass": 720,
			"rocks": 130,
			"shadows": true,
			"shadow_size": 4096,
			"shadow_bits": false,
			"shadow_distance": 240.0,
			"fog_end": 720.0,
			"msaa": Viewport.MSAA_4X,
			"scale": 1.0,
		}
	return {
		"trees": 280,
		"grass": 420,
		"rocks": 90,
		"shadows": true,
		"shadow_size": 2048,
		"shadow_bits": true,
		"shadow_distance": 150.0,
		"fog_end": 460.0,
		"msaa": Viewport.MSAA_2X,
		"scale": 1.0,
	}


static func apply(q: String) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var vp := (loop as SceneTree).root
	var b := budget(q)
	if q == "low":
		vp.msaa_2d = Viewport.MSAA_DISABLED
	elif q == "high":
		vp.msaa_2d = Viewport.MSAA_4X
	else:
		vp.msaa_2d = Viewport.MSAA_2X
	vp.msaa_3d = int(b.msaa) as Viewport.MSAA
	vp.scaling_3d_scale = float(b.scale)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.directional_shadow_atlas_set_size(int(b.shadow_size), bool(b.shadow_bits))
	vp.set_meta("rift_quality", q)


static func current() -> String:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root.has_meta("rift_quality"):
		return str((loop as SceneTree).root.get_meta("rift_quality"))
	return "medium"


static func apply_volume(linear: float) -> void:
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(v) if v > 0.001 else -80.0)
