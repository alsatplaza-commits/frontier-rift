class_name WorldView
extends Node2D

const PPM := 4.0

var sim: SimWorld
var selection: Array = []
var show_ghost := false
var ghost := Vector2.ZERO
var ghost_size := 2
var camera: Camera2D
var _terrain: Sprite2D


func _ready() -> void:
	camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(0.42, 0.42)
	add_child(camera)
	_terrain = Sprite2D.new()
	_terrain.centered = false
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain)


func bind_sim(world: SimWorld) -> void:
	sim = world
	_bake_terrain()
	var cc := world._first(0, "command")
	if not cc.is_empty():
		camera.position = Vector2(float(cc.x), float(cc.y)) * PPM


func screen_to_meters(screen: Vector2) -> Vector2:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	return world / PPM


func _bake_terrain() -> void:
	var img := Image.create(SimWorld.MAP_TILES, SimWorld.MAP_TILES, false, Image.FORMAT_RGB8)
	var colors := {
		0: Color("3E6B45"),
		1: Color("234A32"),
		2: Color("6E675C"),
		3: Color("2A4E6B"),
	}
	for y in SimWorld.MAP_TILES:
		for x in SimWorld.MAP_TILES:
			var cell := int(sim.terrain[y * SimWorld.MAP_TILES + x])
			img.set_pixel(x, y, colors.get(cell, colors[0]))
	var tex := ImageTexture.create_from_image(img)
	_terrain.texture = tex
	_terrain.scale = Vector2(SimWorld.TILE * PPM, SimWorld.TILE * PPM)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	for crystal in sim.crystals:
		if float(crystal.amount) <= 1.0:
			continue
		var p := Vector2(float(crystal.x), float(crystal.y)) * PPM
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -10), p + Vector2(8, 0), p + Vector2(0, 10), p + Vector2(-8, 0)
		]), Color("7EE0C8"))
	for e in sim.entity_list():
		_draw_entity(e)
	if show_ghost:
		var s := float(ghost_size) * SimWorld.TILE * PPM
		var gp := ghost * PPM
		draw_rect(Rect2(gp - Vector2(s, s) * 0.5, Vector2(s, s)), Color(1, 1, 1, 0.35), false, 2.0)


func _draw_entity(e: Dictionary) -> void:
	var p := Vector2(float(e.x), float(e.y)) * PPM
	var col := FactionDB.color_of(sim.factions[int(e.team)])
	if int(e.construct_left) > 0:
		col.a = 0.55
	var selected := selection.has(int(e.id))
	if str(e.kind) == "building":
		var s := float(e.size) * SimWorld.TILE * PPM
		var rect := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
		draw_rect(rect, Color(col, 0.35), true)
		draw_rect(rect, col, false, 3.0)
	else:
		var r := float(e.radius) * PPM * 0.55
		var st: Dictionary = sim.stats_for(int(e.team), str(e.type))
		if bool(st.get("air", false)):
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)
			]), col)
		else:
			draw_circle(p, r, col)
	if selected:
		draw_arc(p, float(e.radius) * PPM * 0.8 + 6.0, 0, TAU, 24, Color("F2C14E"), 2.0)
	var hp := float(e.hp) / maxf(1.0, float(e.max_hp))
	var w := 28.0
	draw_rect(Rect2(p + Vector2(-w * 0.5, -float(e.radius) * PPM - 10), Vector2(w, 4)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(p + Vector2(-w * 0.5, -float(e.radius) * PPM - 10), Vector2(w * hp, 4)), Color("8DDE7A"), true)
