extends Node2D

const EDGE := 22.0
const PAN := 900.0
const PPM := 4.0

var sim := SimWorld.new()
var view: Node2D
var selection: Array = []
var mode := ""
var build_type := ""
var paused := false
var _acc := 0.0
var _ended := false
var _level_id := 1
var _box_active := false
var _box_moved := false
var _box_start := Vector2.ZERO
var _box_end := Vector2.ZERO
var _middle := false
var _touches := {}
var _pinch := -1.0
var _pinch_zoom := 0.42
var _hud: CanvasLayer
var _res_label: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _obj_label: Label
var _reward_label: Label
var _sel_label: Label
var _bar: HBoxContainer
var _minimap: Control
var _pause_layer: CanvasLayer
var _strip: ColorRect
var _box_ui: Control


func _ready() -> void:
	view = preload("res://scripts/match/world_view.gd").new()
	add_child(view)
	var match_data = AppState.profile.get("match")
	if typeof(match_data) == TYPE_DICTIONARY and match_data.get("sim") != null:
		_level_id = int(match_data.get("level_id", 1))
		var lvl := AppState.level_def(_level_id)
		sim.restore(match_data["sim"], AppState.factions, lvl)
		selection = match_data.get("selection", [])
		view.bind_sim(sim)
	else:
		_level_id = int(match_data.get("level_id", AppState.next_level_id())) if typeof(match_data) == TYPE_DICTIONARY else AppState.next_level_id()
		var faction := str(match_data.get("faction", AppState.faction_id())) if typeof(match_data) == TYPE_DICTIONARY else AppState.faction_id()
		sim.setup(AppState.level_def(_level_id), AppState.factions, faction)
		view.bind_sim(sim)
	_build_hud()
	_build_pause()


func _process(delta: float) -> void:
	if not paused and not _ended:
		_acc += delta
		var guard := 0
		while _acc >= SimWorld.DT and guard < 5:
			_acc -= SimWorld.DT
			sim.step()
			guard += 1
		if sim.winner >= 0 and not _ended:
			_ended = true
			_save_match(true)
			AppState.on_match_end(sim.winner == 0, _level_id)
			get_tree().change_scene_to_file("res://scenes/level_end.tscn")
			return
	_edge_pan(delta)
	_refresh_hud()
	if _minimap:
		_minimap.queue_redraw()
	if _box_ui and _box_active:
		_box_ui.queue_redraw()


func _edge_pan(delta: float) -> void:
	if OS.has_feature("android") or OS.has_feature("mobile") or paused:
		return
	var mp := get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var dir := Vector2.ZERO
	if mp.x <= EDGE:
		dir.x -= 1
	elif mp.x >= size.x - EDGE:
		dir.x += 1
	if mp.y <= EDGE:
		dir.y -= 1
	elif mp.y >= size.y - EDGE:
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		view.camera.position += dir.normalized() * PAN * delta / view.camera.zoom.x
		_clamp_camera()


func _unhandled_input(event: InputEvent) -> void:
	if paused:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		return
	if OS.has_feature("android") or OS.has_feature("mobile"):
		_touch(event)
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion and _middle:
		view.camera.position -= event.relative / view.camera.zoom
		_clamp_camera()
	elif event is InputEventMouseMotion and _box_active:
		_box_end = event.position
		if _box_start.distance_to(_box_end) > 8.0:
			_box_moved = true
		queue_redraw()


func _mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 0.9)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.1)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle = event.pressed
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_box_active = true
			_box_moved = false
			_box_start = event.position
			_box_end = event.position
		else:
			if mode == "build":
				_confirm_build(event.position)
			elif mode == "move":
				_issue_move(event.position)
			elif mode == "attack":
				_issue_attack(event.position)
			elif _box_moved:
				_select_box(_box_start, event.position)
			else:
				_select_at(event.position)
			_box_active = false
			queue_redraw()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		mode = ""
		build_type = ""
		view.show_ghost = false
		_issue_smart(event.position)
		_rebuild_bar()


func _touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = {"start": event.position, "last": event.position, "moved": false}
			if _touches.size() == 1:
				_box_active = true
				_box_moved = false
				_box_start = event.position
				_box_end = event.position
			else:
				_box_active = false
				_pinch = _touch_dist()
				_pinch_zoom = view.camera.zoom.x
		else:
			var info: Dictionary = _touches.get(event.index, {})
			var was_only := _touches.size() == 1
			_touches.erase(event.index)
			if was_only and not bool(info.get("moved", true)):
				if mode == "build":
					_confirm_build(event.position)
				elif mode == "move":
					_issue_move(event.position)
				elif mode == "attack":
					_issue_attack(event.position)
				else:
					_select_at(event.position)
			elif was_only and _box_moved:
				_select_box(_box_start, event.position)
			if _touches.size() < 2:
				_pinch = -1.0
			_box_active = false
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			if event.position.distance_to(_touches[event.index].start) > 14.0:
				_touches[event.index].moved = true
			_touches[event.index].last = event.position
		if _touches.size() >= 2:
			_pan_pinch()
		elif _box_active:
			_box_end = event.position
			if _box_start.distance_to(_box_end) > 14.0:
				_box_moved = true
			queue_redraw()


func _pan_pinch() -> void:
	var pts: Array = []
	for key in _touches.keys():
		pts.append(_touches[key].last)
	if pts.size() < 2:
		return
	var dist := (pts[0] as Vector2).distance_to(pts[1])
	if _pinch > 1.0:
		view.camera.zoom = Vector2.ONE * clampf(_pinch_zoom * (_pinch / maxf(dist, 1.0)), 0.18, 1.35)
	var centroid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	var starts: Array = []
	for key in _touches.keys():
		starts.append(_touches[key].start)
	if starts.size() >= 2:
		var start_c := ((starts[0] as Vector2) + (starts[1] as Vector2)) * 0.5
		# Rebase so the gesture does not accumulate error across events.
		view.camera.position += (start_c - centroid) / view.camera.zoom * 0.15
	_clamp_camera()


func _touch_dist() -> float:
	var pts: Array = []
	for key in _touches.keys():
		pts.append(_touches[key].last)
	if pts.size() < 2:
		return -1.0
	return (pts[0] as Vector2).distance_to(pts[1])


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := view.screen_to_meters(screen)
	view.camera.zoom = Vector2.ONE * clampf(view.camera.zoom.x * factor, 0.18, 1.35)
	var after := view.screen_to_meters(screen)
	view.camera.position += (before - after) * PPM
	_clamp_camera()


func _clamp_camera() -> void:
	var limit := SimWorld.MAP_METERS * PPM
	view.camera.position.x = clampf(view.camera.position.x, 0.0, limit)
	view.camera.position.y = clampf(view.camera.position.y, 0.0, limit)


func _meters(screen: Vector2) -> Vector2:
	return view.screen_to_meters(screen)


func _select_at(screen: Vector2) -> void:
	var m := _meters(screen)
	var id := sim.pick(0, m.x, m.y, 18.0)
	selection = [id] if id >= 0 else []
	view.selection = selection
	_rebuild_bar()


func _select_box(a: Vector2, b: Vector2) -> void:
	var m1 := _meters(a)
	var m2 := _meters(b)
	var rect := Rect2(Vector2(minf(m1.x, m2.x), minf(m1.y, m2.y)), Vector2(absf(m2.x - m1.x), absf(m2.y - m1.y)))
	selection = sim.enemies_in_rect(0, rect)
	view.selection = selection
	_rebuild_bar()


func _issue_move(screen: Vector2) -> void:
	if selection.is_empty():
		return
	var m := _meters(screen)
	sim.enqueue({"op": "move", "team": 0, "ids": selection.duplicate(), "x": m.x, "y": m.y})
	mode = ""
	_rebuild_bar()


func _issue_attack(screen: Vector2) -> void:
	if selection.is_empty():
		return
	var m := _meters(screen)
	var enemy := sim.pick(1, m.x, m.y, 22.0)
	if enemy >= 0:
		sim.enqueue({"op": "attack", "team": 0, "ids": selection.duplicate(), "target": enemy})
	else:
		sim.enqueue({"op": "attack_move", "team": 0, "ids": selection.duplicate(), "x": m.x, "y": m.y})
	mode = ""
	_rebuild_bar()


func _issue_smart(screen: Vector2) -> void:
	if selection.is_empty():
		return
	var m := _meters(screen)
	var enemy := sim.pick(1, m.x, m.y, 22.0)
	if enemy >= 0:
		sim.enqueue({"op": "attack", "team": 0, "ids": selection.duplicate(), "target": enemy})
	else:
		sim.enqueue({"op": "move", "team": 0, "ids": selection.duplicate(), "x": m.x, "y": m.y})


func _confirm_build(screen: Vector2) -> void:
	var m := _meters(screen)
	sim.enqueue({"op": "build", "team": 0, "type": build_type, "x": m.x, "y": m.y})
	mode = ""
	build_type = ""
	view.show_ghost = false
	_rebuild_bar()


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_strip = ColorRect.new()
	_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_strip.offset_bottom = 8
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.color = FactionDB.color_of(sim.factions[0])
	_hud.add_child(_strip)
	var left := VBoxContainer.new()
	left.position = Vector2(16, 20)
	left.add_theme_constant_override("separation", 4)
	_hud.add_child(left)
	_res_label = UiKit.label("Cevher 0", 22)
	_xp_label = UiKit.label("Deneyim", 16)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(220, 18)
	_xp_bar.show_percentage = false
	left.add_child(_res_label)
	left.add_child(_xp_label)
	left.add_child(_xp_bar)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.offset_left = -220
	center.offset_top = 18
	center.offset_right = 220
	center.offset_bottom = 90
	_hud.add_child(center)
	var lvl := AppState.level_def(_level_id)
	_obj_label = UiKit.label(str(lvl.get("objective", "")), 20)
	_obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label = UiKit.label("Ödül: " + str(lvl.get("reward", "")), 16)
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_obj_label)
	center.add_child(_reward_label)
	_minimap = Control.new()
	_minimap.custom_minimum_size = Vector2(168, 168)
	_minimap.size = Vector2(168, 168)
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -184
	_minimap.offset_top = 18
	_minimap.offset_right = -16
	_minimap.offset_bottom = 186
	_minimap.gui_input.connect(_on_minimap)
	_minimap.draw.connect(_draw_minimap)
	_hud.add_child(_minimap)
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -120
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	bottom.add_theme_stylebox_override("panel", style)
	_hud.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)
	_sel_label = UiKit.label("Seçim yok", 18)
	_sel_label.custom_minimum_size = Vector2(180, 64)
	row.add_child(_sel_label)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bar)
	var menu := UiKit.button("Menü", 120)
	menu.pressed.connect(_toggle_pause)
	row.add_child(menu)
	_box_ui = Control.new()
	_box_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_ui.draw.connect(_draw_box)
	_hud.add_child(_box_ui)
	_rebuild_bar()


func _draw_minimap() -> void:
	var size := _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color("142018"))
	var scale := size.x / SimWorld.MAP_METERS
	for crystal in sim.crystals:
		_minimap.draw_circle(Vector2(float(crystal.x), float(crystal.y)) * scale, 2.0, Color("7EE0C8"))
	for e in sim.entity_list():
		var col := FactionDB.color_of(sim.factions[int(e.team)])
		_minimap.draw_circle(Vector2(float(e.x), float(e.y)) * scale, 3.0 if str(e.kind) == "building" else 2.0, col)
	var cam := view.camera.position / PPM * scale
	_minimap.draw_rect(Rect2(cam - Vector2(8, 6), Vector2(16, 12)), Color(1, 1, 1, 0.8), false, 1.0)


func _on_minimap(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var meters := Vector2(event.position.x, event.position.y) / (_minimap.size.x / SimWorld.MAP_METERS)
		view.camera.position = meters * PPM
		_clamp_camera()


func _refresh_hud() -> void:
	_res_label.text = "Cevher %d" % int(sim.resources[0])
	var xp := int(AppState.profile.get("xp", 0))
	var info := ProfileStore.bar_values(xp)
	_xp_label.text = "Deneyim %d" % xp
	_xp_bar.min_value = float(info.prev)
	_xp_bar.max_value = float(info.next)
	_xp_bar.value = float(info.value)
	if mode == "build":
		var m := view.screen_to_meters(get_viewport().get_mouse_position())
		view.ghost = m
		view.ghost_size = int(sim.stats_for(0, build_type).get("size", 2))
		view.show_ghost = true
	view.selection = selection


func _rebuild_bar() -> void:
	for child in _bar.get_children():
		child.queue_free()
	if selection.is_empty():
		_sel_label.text = "Seçim yok"
	else:
		var e: Dictionary = sim.entities.get(selection[0], {})
		var st := sim.stats_for(0, str(e.get("type", "")))
		_sel_label.text = "%s x%d" % [str(st.get("name", "Birim")), selection.size()]
		var stop := UiKit.button("Dur", 110)
		stop.pressed.connect(func() -> void:
			sim.enqueue({"op": "stop", "team": 0, "ids": selection.duplicate()})
		)
		var move := UiKit.button("Hareket", 140)
		move.pressed.connect(func() -> void:
			mode = "move"
			build_type = ""
			view.show_ghost = false
		)
		var attack := UiKit.button("Saldır", 140)
		attack.pressed.connect(func() -> void:
			mode = "attack"
			build_type = ""
			view.show_ghost = false
		)
		_bar.add_child(stop)
		_bar.add_child(move)
		_bar.add_child(attack)
		if str(e.get("kind", "")) == "building":
			var produces: Array = st.get("produces", [])
			for unit_id in produces:
				var ust := sim.stats_for(0, str(unit_id))
				var b := UiKit.button("%s %d" % [ust.get("name", unit_id), int(ust.get("cost", 0))], 170)
				b.pressed.connect(_produce.bind(int(e.id), str(unit_id)))
				_bar.add_child(b)
	for building_id in ["refinery", "barracks", "turret"]:
		var st := sim.stats_for(0, building_id)
		var b := UiKit.button("%s %d" % [st.get("name", building_id), int(st.get("cost", 0))], 160)
		b.pressed.connect(_arm_build.bind(building_id))
		_bar.add_child(b)


func _arm_build(type_id: String) -> void:
	mode = "build"
	build_type = type_id
	view.show_ghost = true


func _produce(building_id: int, unit_type: String) -> void:
	sim.enqueue({"op": "produce", "team": 0, "building": building_id, "type": unit_type})


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
		_save_match(false)
	)
	box.add_child(save)
	var load := UiKit.button("Yükle")
	load.pressed.connect(_load_match)
	box.add_child(load)
	var menu := UiKit.button("Ana menü")
	menu.pressed.connect(func() -> void:
		_save_match(false)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	box.add_child(menu)


func _toggle_pause() -> void:
	paused = not paused
	_pause_layer.visible = paused


func _save_match(clear_on_end: bool) -> void:
	if clear_on_end:
		AppState.profile["match"] = null
	else:
		AppState.profile["match"] = {
			"fresh": false,
			"level_id": _level_id,
			"faction": str(sim.factions[0].get("id", "")),
			"selection": selection.duplicate(),
			"sim": sim.snapshot(),
		}
	AppState.save()


func _load_match() -> void:
	var data = AppState.profile.get("match")
	if typeof(data) != TYPE_DICTIONARY or data.get("sim") == null:
		return
	sim.restore(data["sim"], AppState.factions, AppState.level_def(_level_id))
	selection = data.get("selection", [])
	view.selection = selection
	paused = false
	_pause_layer.visible = false
	_rebuild_bar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()


func _draw_box() -> void:
	if _box_ui == null or not _box_active or not _box_moved:
		return
	var a := _box_start
	var b := _box_end
	_box_ui.draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y))), Color(1, 1, 1, 0.9), false, 2.0)
