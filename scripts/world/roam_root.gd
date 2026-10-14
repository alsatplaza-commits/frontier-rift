extends Node3D

var field: TerrainField
var world: WorldBuild
var pawn: PlayerPawn
var state: RoamState
var budget: Dictionary = {}

var _paused := false
var _resume := false
var _handheld := false
var _atmo: Dictionary = {}
var _save_wait := 0.0
var _toast_left := 0.0
var _toast_label: Label
var _hud: CanvasLayer
var _pause_layer: CanvasLayer
var _clock: Label
var _scrap: Label
var _compass: Label
var _region: Label
var _prompt: Label
var _exposure: ProgressBar
var _night: Label
var _map: MapView


func _ready() -> void:
	_handheld = OS.has_feature("android") or OS.has_feature("mobile")
	budget = Quality.budget(Quality.current())
	_read_request()
	field = TerrainField.new()
	field.configure(state.seed)
	world = WorldBuild.new()
	world.build(self, field, budget)
	_atmo = WorldBuild.make_atmosphere(self)
	var shirt := Color(0.77, 0.36, 0.15)
	if AppState.factions.has(AppState.faction_id()):
		shirt = FactionDB.color_of(AppState.factions[AppState.faction_id()])
	pawn = PlayerPawn.new()
	pawn.setup(shirt)
	pawn.configure_world(field.size * 0.5, field.water_level)
	add_child(pawn)
	_place_from_state()
	_apply_scrap_visibility()
	_build_hud()
	_build_pause()
	_capture_mouse()
	WorldBuild.paint_hour(_atmo, state.hour, budget, world.fire_light)


func _process(delta: float) -> void:
	if pawn == null or state == null:
		return
	_bob_scraps()
	if not _paused:
		state.advance(delta, _near_shelter())
		_save_wait += delta
		if _save_wait > 12.0:
			_save_wait = 0.0
			_save_roam()
	WorldBuild.paint_hour(_atmo, state.hour, budget, world.fire_light)
	_refresh_hud()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast_label.modulate.a = clampf(_toast_left, 0.0, 1.0)
	if _map:
		_map.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
			return
		if _paused:
			return
		if event.keycode == KEY_C:
			pawn.toggle_sit()
		elif event.keycode == KEY_E:
			_interact()
		return
	if _paused:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_X:
			_interact()
		elif event.button_index == JOY_BUTTON_B:
			pawn.toggle_sit()
		elif event.button_index == JOY_BUTTON_START:
			_toggle_pause()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pawn.add_look(event.relative.x, event.relative.y)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _handheld:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_roam()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()


func _read_request() -> void:
	state = RoamState.new()
	var data = AppState.profile.get("roam")
	if typeof(data) == TYPE_DICTIONARY and data.has("x") and not bool(data.get("fresh", false)):
		state = RoamState.from_dict(data)
		_resume = true
	elif typeof(data) == TYPE_DICTIONARY:
		state.seed = int(data.get("seed", 11011))
		state.region = str(data.get("region", "İlk Kamp"))


func _place_from_state() -> void:
	if _resume and _inside(state.position):
		var ground := field.height_at(state.position.x, state.position.z)
		var feet := state.position.y
		if absf(feet - ground) > 3.5:
			feet = ground + 2.0
		else:
			feet = maxf(feet, ground + 0.15)
		pawn.place(Vector3(state.position.x, feet, state.position.z), state.yaw, state.facing, state.pitch)
		pawn.pending_sit = state.sitting
	else:
		_resume = false
		pawn.place(world.spawn, world.spawn_yaw, world.spawn_yaw, -0.22)
		state.position = world.spawn
		state.yaw = world.spawn_yaw
		state.facing = world.spawn_yaw
	_save_roam()


func _inside(pos: Vector3) -> bool:
	var limit := field.size * 0.5 - 20.0
	return absf(pos.x) < limit and absf(pos.z) < limit


func _near_shelter() -> bool:
	return Vector2(pawn.global_position.x, pawn.global_position.z).distance_to(Vector2(world.shelter.x, world.shelter.z)) <= RoamState.SHELTER_RADIUS


func _nearest_scrap() -> int:
	var best := -1
	var best_d := RoamState.COLLECT_RADIUS
	for i in world.scraps.size():
		if state.collected.has(i):
			continue
		var spot: Vector3 = world.scraps[i]
		var dist := Vector2(pawn.global_position.x, pawn.global_position.z).distance_to(Vector2(spot.x, spot.z))
		if dist < best_d:
			best_d = dist
			best = i
	return best


func _interact() -> String:
	var index := _nearest_scrap()
	if index >= 0 and state.try_collect(index, pawn.global_position, world.scraps):
		_apply_scrap_visibility()
		_show_toast("Hurda alındı.")
		_save_roam()
		return "scrap"
	if state.try_rest(pawn.global_position, world.shelter):
		_show_toast("Sabah oldu. Konum kaydedildi.")
		_save_roam()
		return "rest"
	return ""


func _apply_scrap_visibility() -> void:
	for i in world.scrap_nodes.size():
		world.scrap_nodes[i].visible = not state.collected.has(i)


func _bob_scraps() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in world.scrap_nodes.size():
		var node := world.scrap_nodes[i]
		if not node.visible:
			continue
		node.position.y = float(node.get_meta("base_y")) + sin(t * 2.2 + float(i)) * 0.1


func _capture_pose() -> void:
	state.position = pawn.global_position
	state.yaw = pawn.yaw
	state.facing = pawn.facing
	state.pitch = pawn.pitch
	state.sitting = pawn.sitting


func _save_roam() -> void:
	if pawn == null or state == null:
		return
	_capture_pose()
	AppState.profile["roam"] = state.to_dict()
	AppState.save()


func _load_roam() -> void:
	AppState.profile = ProfileStore.load_profile()
	var data = AppState.profile.get("roam")
	if typeof(data) != TYPE_DICTIONARY or not data.has("x"):
		_show_toast("Kayıt yok.")
		return
	var loaded := RoamState.from_dict(data)
	if loaded.seed != field.seed:
		_show_toast("Kayıt başka bölgede. Ana menüden devam et.")
		return
	state = loaded
	var ground := field.height_at(state.position.x, state.position.z)
	var feet := state.position.y if absf(state.position.y - ground) <= 3.5 else ground + 2.0
	pawn.place(Vector3(state.position.x, feet, state.position.z), state.yaw, state.facing, state.pitch)
	pawn.sitting = state.sitting
	pawn.pending_sit = false
	_apply_scrap_visibility()
	_paused = false
	_pause_layer.visible = false
	pawn.set_frozen(false)
	_capture_mouse()
	_show_toast("Konum yüklendi.")


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_layer.visible = _paused
	pawn.set_frozen(_paused)
	if _paused:
		_save_roam()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture_mouse()


func _capture_mouse() -> void:
	if _handheld or _paused or DisplayServer.get_name() == "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_left = 3.2
	_toast_label.modulate.a = 1.0


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 176
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.55)
	top.add_theme_stylebox_override("panel", style)
	_hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	var left := VBoxContainer.new()
	left.offset_left = 8
	row.add_child(left)
	_region = UiKit.label(state.region, 20)
	_clock = UiKit.label("09:24", 18)
	_compass = UiKit.label("Kuzey", 16)
	left.add_child(_region)
	left.add_child(_clock)
	left.add_child(_compass)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	_scrap = UiKit.label("Hurda 0", 20)
	_night = UiKit.label("", 16)
	_night.add_theme_color_override("font_color", Color("F2C14E"))
	mid.add_child(_scrap)
	mid.add_child(_night)
	_exposure = ProgressBar.new()
	_exposure.min_value = 0
	_exposure.max_value = 100
	_exposure.show_percentage = false
	_exposure.custom_minimum_size = Vector2(220, 14)
	mid.add_child(_exposure)
	_map = MapView.new()
	_map.texture = ImageTexture.create_from_image(world.minimap_image(field))
	_map.pawn = pawn
	_map.map_size = field.size
	_map.custom_minimum_size = Vector2(150, 150)
	_map.size = Vector2(150, 150)
	row.add_child(_map)
	_prompt = UiKit.label("", 20)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150
	_prompt.offset_bottom = -110
	_prompt.offset_left = -220
	_prompt.offset_right = 220
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_prompt)
	_toast_label = UiKit.label("", 22)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_top = 100
	_toast_label.offset_bottom = 140
	_toast_label.offset_left = -260
	_toast_label.offset_right = 260
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_toast_label)
	var hint := UiKit.label("WASD yürü · Fare bak · Shift koş · C otur · E al · Esc menü", 16)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -48
	hint.offset_bottom = -16
	hint.offset_left = -360
	hint.offset_right = 360
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	if not _handheld:
		_hud.add_child(hint)
	else:
		_build_touch()


func _build_touch() -> void:
	var stick := TouchStick.new()
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 24
	stick.offset_top = -210
	stick.offset_right = 174
	stick.offset_bottom = -60
	stick.moved.connect(func(dir: Vector2, active: bool) -> void:
		pawn.stick_active = active
		if active:
			pawn.move_input = dir
			pawn.sprinting = dir.length() > 0.82
		elif pawn.script_driven == false:
			pawn.move_input = Vector2.ZERO
	)
	_hud.add_child(stick)
	var look := TouchPad.new()
	look.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	look.offset_left = -240
	look.offset_top = -280
	look.offset_right = -24
	look.offset_bottom = -36
	look.dragged.connect(func(delta: Vector2) -> void:
		pawn.add_look(delta.x, delta.y)
	)
	_hud.add_child(look)
	var sit := UiKit.button("Otur", 140)
	sit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sit.offset_left = 36
	sit.offset_top = -300
	sit.offset_right = 180
	sit.offset_bottom = -230
	sit.pressed.connect(func() -> void:
		pawn.toggle_sit()
		sit.text = "Kalk" if pawn.sitting else "Otur"
	)
	_hud.add_child(sit)
	var use := UiKit.button("Al", 140)
	use.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	use.offset_left = -190
	use.offset_top = -360
	use.offset_right = -36
	use.offset_bottom = -290
	use.pressed.connect(_interact)
	_hud.add_child(use)


func _refresh_hud() -> void:
	var hour := int(state.hour) % 24
	var minute := int(fposmod(state.hour, 1.0) * 60.0)
	_clock.text = "%02d:%02d" % [hour, minute]
	_scrap.text = "Hurda %d" % state.scrap
	_region.text = state.region
	_compass.text = _heading_name(pawn.yaw)
	_exposure.value = state.exposure
	if state.is_night():
		_night.text = "Gece. Sığınağa dön." if not _near_shelter() else "Sığınaktasın."
	elif state.exposure > 1.0:
		_night.text = "Gece riski düşüyor."
	else:
		_night.text = "Açık arazi"
	if pawn.sitting:
		_prompt.text = "Oturuyorsun · bakınmaya devam et"
	elif _nearest_scrap() >= 0:
		_prompt.text = "E  Hurda al"
	elif _near_shelter():
		_prompt.text = "E  Sığınakta dinlen"
	else:
		_prompt.text = ""


func _heading_name(cam_yaw: float) -> String:
	var heading := fposmod(rad_to_deg(-cam_yaw), 360.0)
	var names := ["Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu", "Güney", "Güneybatı", "Batı", "Kuzeybatı"]
	return names[int(round(heading / 45.0)) % 8]


func _build_pause() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.visible = false
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var box := UiKit.column(dim)
	box.add_child(UiKit.label("Duraklatıldı", 36))
	var resume := UiKit.button("Devam")
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var save := UiKit.button("Kaydet")
	save.pressed.connect(func() -> void:
		_save_roam()
		_show_toast("Kaydedildi.")
	)
	box.add_child(save)
	var load := UiKit.button("Yükle")
	load.pressed.connect(_load_roam)
	box.add_child(load)
	var menu := UiKit.button("Ana menü")
	menu.pressed.connect(func() -> void:
		_save_roam()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	box.add_child(menu)


class MapView extends Control:
	var texture: Texture2D
	var pawn: PlayerPawn
	var map_size := 960.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.08, 0.85), true)
		if texture:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		if pawn == null or map_size <= 1.0:
			return
		var u := (pawn.global_position.x / map_size + 0.5) * size.x
		var v := (pawn.global_position.z / map_size + 0.5) * size.y
		var tip := Vector2(u, v) + Vector2(-sin(pawn.yaw), -cos(pawn.yaw)) * 12.0
		draw_line(Vector2(u, v), tip, Color(1, 1, 1, 0.9), 2.0)
		draw_circle(Vector2(u, v), 4.0, Color(0.95, 0.95, 0.9))


class TouchStick extends Control:
	signal moved(dir: Vector2, active: bool)

	var _pressed := false

	func _ready() -> void:
		custom_minimum_size = Vector2(150, 150)
		size = Vector2(150, 150)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_pressed = event.pressed
			if not event.pressed:
				moved.emit(Vector2.ZERO, false)
				queue_redraw()
		elif event is InputEventScreenDrag and _pressed:
			var drag := event as InputEventScreenDrag
			var delta := (drag.position - size * 0.5) / (size.x * 0.42)
			if delta.length() > 1.0:
				delta = delta.normalized()
			moved.emit(delta, true)
		elif event is InputEventMouseButton:
			_pressed = event.pressed
			if not event.pressed:
				moved.emit(Vector2.ZERO, false)
		elif event is InputEventMouseMotion and _pressed:
			var motion := event as InputEventMouseMotion
			var delta := (motion.position - size * 0.5) / (size.x * 0.42)
			if delta.length() > 1.0:
				delta = delta.normalized()
			moved.emit(delta, true)

	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.48, Color(1, 1, 1, 0.16))
		draw_circle(size * 0.5, 18, Color(1, 1, 1, 0.45))


class TouchPad extends Control:
	signal dragged(delta: Vector2)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenDrag:
			dragged.emit(event.relative)
		elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			dragged.emit(event.relative)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08), true)
