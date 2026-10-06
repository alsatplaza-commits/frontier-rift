class_name SimWorld
extends RefCounted

const HZ := 20
const DT := 1.0 / 20.0
const TILE := 32.0
const MAP_TILES := 64
const MAP_METERS := TILE * MAP_TILES

var tick := 0
var seed := 1
var rng := RandomNumberGenerator.new()
var resources := [0, 0]
var entities := {}
var next_id := 1
var crystals: Array = []
var terrain := PackedByteArray()
var winner := -1
var factions := [{}, {}]
var level := {}
var _queue: Array = []


func setup(level_def: Dictionary, faction_db: Dictionary, player_faction_id: String) -> void:
	level = level_def
	seed = int(level.get("seed", 1))
	rng.seed = seed
	tick = 0
	winner = -1
	next_id = 1
	entities.clear()
	crystals.clear()
	_queue.clear()
	var enemy_id := str(level.get("enemy_faction", "kok"))
	factions[0] = faction_db[player_faction_id]
	factions[1] = faction_db[enemy_id]
	resources[0] = int(level.get("starting_resources", 400))
	resources[1] = int(level.get("enemy_resources", 100))
	_gen_terrain()
	var p_tile: Array = level.get("player_tile", [12, 46])
	var e_tile: Array = level.get("enemy_tile", [40, 20])
	_clear_pad(int(p_tile[0]), int(p_tile[1]), 7)
	_clear_pad(int(e_tile[0]), int(e_tile[1]), 7)
	_spawn_base(0, int(p_tile[0]), int(p_tile[1]))
	_spawn_base(1, int(e_tile[0]), int(e_tile[1]))
	for building_id in level.get("enemy_buildings", ["command"]):
		if str(building_id) == "command":
			continue
		_ai_place(1, str(building_id), true)
	for unit_id in level.get("enemy_units", []):
		var home := _first(1, "barracks")
		if home.is_empty():
			home = _first(1, "command")
		if not home.is_empty():
			_spawn_unit(1, str(unit_id), float(home.x) + 40.0, float(home.y))
	_place_crystals(int(p_tile[0]), int(p_tile[1]), int(e_tile[0]), int(e_tile[1]))


func enqueue(cmd: Dictionary) -> void:
	_queue.append(cmd)


func step() -> void:
	if winner >= 0:
		return
	tick += 1
	var cmds := _queue.duplicate(true)
	_queue.clear()
	for cmd in cmds:
		_apply(cmd)
	var ids := _sorted_ids()
	for id in ids:
		var e: Dictionary = entities[id]
		if int(e.construct_left) > 0:
			e.construct_left = int(e.construct_left) - 1
	for id in ids:
		if not entities.has(id):
			continue
		var e: Dictionary = entities[id]
		if str(e.kind) == "building":
			_step_production(e)
			_step_turret(e)
		elif str(e.type) == "harvester":
			_step_harvester(e)
		else:
			_step_combat(e)
	_step_ai()
	_remove_dead()
	_check_victory()


func snapshot() -> Dictionary:
	var ents: Array = []
	for id in _sorted_ids():
		ents.append((entities[id] as Dictionary).duplicate(true))
	return {
		"tick": tick,
		"seed": seed,
		"rng_state": rng.state,
		"resources": [resources[0], resources[1]],
		"entities": ents,
		"next_id": next_id,
		"crystals": crystals.duplicate(true),
		"terrain_b64": Marshalls.raw_to_base64(terrain),
		"winner": winner,
		"faction_ids": [str(factions[0].get("id", "")), str(factions[1].get("id", ""))],
		"level_id": int(level.get("id", 0)),
		"queue": _queue.duplicate(true),
	}


func restore(data: Dictionary, faction_db: Dictionary, level_def: Dictionary) -> void:
	level = level_def
	seed = int(data.get("seed", 1))
	rng.seed = seed
	rng.state = int(data.get("rng_state", rng.state))
	tick = int(data.get("tick", 0))
	winner = int(data.get("winner", -1))
	next_id = int(data.get("next_id", 1))
	var res: Array = data.get("resources", [0, 0])
	resources = [int(res[0]), int(res[1])]
	var ids: Array = data.get("faction_ids", ["", ""])
	factions[0] = faction_db[str(ids[0])]
	factions[1] = faction_db[str(ids[1])]
	entities.clear()
	for e in data.get("entities", []):
		entities[int(e.id)] = (e as Dictionary).duplicate(true)
	crystals = data.get("crystals", []).duplicate(true)
	terrain = Marshalls.base64_to_raw(str(data.get("terrain_b64", "")))
	_queue = data.get("queue", []).duplicate(true)


func hash_state() -> String:
	var parts: PackedStringArray = []
	parts.append(str(tick))
	parts.append("%d,%d" % [resources[0], resources[1]])
	parts.append(str(winner))
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		parts.append("%s:%s:%s:%.2f:%.2f:%.1f:%s" % [id, e.team, e.type, e.x, e.y, e.hp, e.order])
	return "|".join(parts)


func entity_list() -> Array:
	var out: Array = []
	for id in _sorted_ids():
		out.append(entities[id])
	return out


func pick(team: int, x: float, y: float, radius: float) -> int:
	var best := -1
	var best_d := radius * radius
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if int(e.team) != team or float(e.hp) <= 0.0:
			continue
		var dx := float(e.x) - x
		var dy := float(e.y) - y
		var d := dx * dx + dy * dy
		var reach := maxf(radius, float(e.radius) + 6.0)
		if d <= reach * reach and d <= best_d:
			best = int(id)
			best_d = d
	return best


func enemies_in_rect(team: int, rect: Rect2) -> Array:
	var ids: Array = []
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if int(e.team) != team or float(e.hp) <= 0.0:
			continue
		if rect.has_point(Vector2(float(e.x), float(e.y))):
			ids.append(int(id))
	return ids


func stats_for(team: int, type_id: String) -> Dictionary:
	return _stats_of(team, type_id)


func _apply(cmd: Dictionary) -> void:
	var team := int(cmd.get("team", 0))
	match str(cmd.get("op", "")):
		"move":
			for id in cmd.get("ids", []):
				if _owned(team, int(id)):
					var e: Dictionary = entities[int(id)]
					e.order = "move"
					e.tx = float(cmd.x)
					e.ty = float(cmd.y)
					e.target = -1
		"attack":
			var target := int(cmd.get("target", -1))
			for id in cmd.get("ids", []):
				if _owned(team, int(id)):
					var e: Dictionary = entities[int(id)]
					e.order = "attack"
					e.target = target
		"attack_move":
			for id in cmd.get("ids", []):
				if _owned(team, int(id)):
					var e: Dictionary = entities[int(id)]
					e.order = "attack_move"
					e.tx = float(cmd.x)
					e.ty = float(cmd.y)
					e.target = -1
		"stop":
			for id in cmd.get("ids", []):
				if _owned(team, int(id)):
					var e: Dictionary = entities[int(id)]
					e.order = "harvest" if str(e.type) == "harvester" else "idle"
					e.target = -1
		"build":
			_try_build(team, str(cmd.get("type", "")), float(cmd.x), float(cmd.y))
		"produce":
			_try_produce_at(team, int(cmd.get("building", -1)), str(cmd.get("type", "")))


func _try_build(team: int, type_id: String, x: float, y: float) -> bool:
	var st := _stats_of(team, type_id)
	if st.is_empty() or not factions[team]["buildings"].has(type_id):
		return false
	var cost := int(st.get("cost", 0))
	if resources[team] < cost:
		return false
	var size := int(st.get("size", 1))
	if not _footprint_ok(x, y, size):
		return false
	resources[team] -= cost
	var e := _blank(team, "building", type_id, x, y)
	e.size = size
	e.radius = size * TILE * 0.45
	e.construct_left = int(round(float(st.get("time", 1)) * HZ))
	e.max_hp = float(st.get("hp", 100))
	e.hp = e.max_hp
	return true


func _try_produce_at(team: int, building_id: int, unit_type: String) -> bool:
	if not _owned(team, building_id):
		return false
	var b: Dictionary = entities[building_id]
	if str(b.kind) != "building" or int(b.construct_left) > 0:
		return false
	if str(b.prod_type) != "":
		return false
	var bst := _stats_of(team, str(b.type))
	var produces: Array = bst.get("produces", [])
	if not produces.has(unit_type):
		return false
	var st := _stats_of(team, unit_type)
	var cost := int(st.get("cost", 0))
	if resources[team] < cost:
		return false
	resources[team] -= cost
	b.prod_type = unit_type
	b.prod_left = int(round(float(st.get("time", 1)) * HZ))
	return true


func _step_production(b: Dictionary) -> void:
	if str(b.prod_type) == "" or int(b.construct_left) > 0:
		return
	b.prod_left = int(b.prod_left) - 1
	if int(b.prod_left) > 0:
		return
	var unit_type := str(b.prod_type)
	b.prod_type = ""
	b.prod_left = 0
	_spawn_unit(int(b.team), unit_type, float(b.x) + float(b.size) * TILE * 0.7, float(b.y) + 20.0)


func _step_turret(b: Dictionary) -> void:
	if int(b.construct_left) > 0 or float(b.hp) <= 0.0:
		return
	var st := _stats_of(int(b.team), str(b.type))
	if float(st.get("attack", 0)) <= 0.0:
		return
	if int(b.cooldown) > 0:
		b.cooldown = int(b.cooldown) - 1
	var target := _nearest_enemy(b, float(st.get("range", 0)))
	if not target.is_empty():
		_hit(b, st, target)


func _step_harvester(e: Dictionary) -> void:
	if float(e.hp) <= 0.0:
		return
	if str(e.order) == "move" or str(e.order) == "attack" or str(e.order) == "attack_move":
		_step_combat(e)
		return
	e.order = "harvest"
	var st := _stats_of(int(e.team), "harvester")
	var cargo := float(e.cargo)
	var cap := float(st.get("cargo", 40))
	if cargo >= cap - 0.1:
		var drop := _nearest_drop(int(e.team), e)
		if drop.is_empty():
			return
		if _dist(e, drop) < 28.0:
			resources[int(e.team)] += int(cargo)
			e.cargo = 0.0
		else:
			_approach(e, st, float(drop.x), float(drop.y), 8.0)
		return
	var crystal := _nearest_crystal(e)
	if crystal.is_empty():
		return
	if _dist_xy(e, float(crystal.x), float(crystal.y)) < 18.0:
		var take := minf(0.8, cap - cargo)
		take = minf(take, float(crystal.amount))
		crystal.amount = float(crystal.amount) - take
		e.cargo = cargo + take
	else:
		_approach(e, st, float(crystal.x), float(crystal.y), 6.0)


func _step_combat(e: Dictionary) -> void:
	if float(e.hp) <= 0.0:
		return
	var st := _stats_of(int(e.team), str(e.type))
	if int(e.cooldown) > 0:
		e.cooldown = int(e.cooldown) - 1
	var order := str(e.order)
	if order == "attack":
		var target := _living(int(e.target))
		if target.is_empty():
			e.order = "idle"
		else:
			_chase_or_hit(e, st, target)
			return
	if order == "move":
		if _approach(e, st, float(e.tx), float(e.ty), 4.0):
			e.order = "idle"
		return
	if order == "attack_move":
		var near := _nearest_enemy(e, float(st.get("range", 0.0)) + 40.0)
		if not near.is_empty() and float(st.get("attack", 0)) > 0.0:
			_chase_or_hit(e, st, near)
			return
		if _approach(e, st, float(e.tx), float(e.ty), 6.0):
			e.order = "idle"
		return
	if float(st.get("attack", 0)) > 0.0:
		var guard := _nearest_enemy(e, float(st.get("range", 0.0)))
		if not guard.is_empty():
			_hit(e, st, guard)


func _chase_or_hit(e: Dictionary, st: Dictionary, target: Dictionary) -> void:
	if _dist(e, target) <= float(st.get("range", 1.0)) + float(target.radius) * 0.2:
		_hit(e, st, target)
	else:
		_approach(e, st, float(target.x), float(target.y), 2.0)


func _hit(attacker: Dictionary, st: Dictionary, target: Dictionary) -> void:
	if int(attacker.cooldown) > 0 or float(st.get("attack", 0)) <= 0.0:
		return
	var def_st := _stats_of(int(target.team), str(target.type))
	var mult := 1.0
	var counters: Array = factions[int(attacker.team)].get("counters", [])
	if counters.has(str(factions[int(target.team)].get("id", ""))):
		mult += float(factions[int(attacker.team)].get("counter_bonus", 0.0))
	if bool(def_st.get("air", false)):
		mult += float(st.get("bonus_vs_air", 0.0))
	var armor := float(def_st.get("armor", 0.0))
	var amount := float(st.get("attack", 0.0)) * mult * (20.0 / (20.0 + armor))
	if bool(def_st.get("forest_bonus", false)) and _terrain_at(float(target.x), float(target.y)) == 1:
		amount *= 0.7
	target.hp = maxf(0.0, float(target.hp) - amount)
	attacker.cooldown = maxi(1, int(round(float(st.get("cooldown", 1.0)) * HZ)))


func _approach(e: Dictionary, st: Dictionary, x: float, y: float, epsilon: float) -> bool:
	var dx := x - float(e.x)
	var dy := y - float(e.y)
	var dist := sqrt(dx * dx + dy * dy)
	if dist <= epsilon:
		return true
	var step := float(st.get("speed", 6.0)) * DT
	if step >= dist:
		e.x = x
		e.y = y
		return true
	var nx := float(e.x) + dx / dist * step
	var ny := float(e.y) + dy / dist * step
	if _walkable(nx, ny):
		e.x = nx
		e.y = ny
	elif _walkable(nx, float(e.y)):
		e.x = nx
	elif _walkable(float(e.x), ny):
		e.y = ny
	return false


func _step_ai() -> void:
	if tick % 20 != 0 or winner >= 0:
		return
	if _first(1, "command").is_empty():
		return
	var cc := _first(1, "command")
	if _first(1, "refinery").is_empty() and resources[1] >= int(_stats_of(1, "refinery").get("cost", 9999)):
		_ai_place(1, "refinery", false)
	elif _first(1, "barracks").is_empty() and resources[1] >= int(_stats_of(1, "barracks").get("cost", 9999)):
		_ai_place(1, "barracks", false)
	elif _count(1, "harvester") < 1:
		_ai_produce(1, "harvester")
	elif _count_combat(1) < int(level.get("ai_max_combat", 3)):
		var prefer := "heavy" if resources[1] >= int(_stats_of(1, "heavy").get("cost", 9999)) and tick % 80 == 0 else "infantry"
		_ai_produce(1, prefer)
	var every := maxi(1, int(level.get("ai_attack_every", 40))) * HZ
	if tick % every == 0:
		var player_cc := _first(0, "command")
		if not player_cc.is_empty():
			for id in _sorted_ids():
				var e: Dictionary = entities[id]
				if int(e.team) == 1 and str(e.kind) == "unit" and str(e.type) != "harvester" and float(e.hp) > 0.0:
					e.order = "attack"
					e.target = int(player_cc.id)


func _ai_produce(team: int, unit_type: String) -> void:
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if int(e.team) == team and str(e.type) == "barracks" and str(e.prod_type) == "":
			_try_produce_at(team, int(id), unit_type)
			return


func _ai_place(team: int, type_id: String, free: bool) -> bool:
	var cc := _first(team, "command")
	if cc.is_empty():
		return false
	var st := _stats_of(team, type_id)
	var size := int(st.get("size", 2))
	var base_tx := int(float(cc.x) / TILE)
	var base_ty := int(float(cc.y) / TILE)
	for ring in range(3, 12):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var tx := base_tx + dx
				var ty := base_ty + dy
				var x := (tx + size * 0.5) * TILE
				var y := (ty + size * 0.5) * TILE
				if free:
					if _footprint_ok(x, y, size):
						var e := _blank(team, "building", type_id, x, y)
						e.size = size
						e.radius = size * TILE * 0.45
						e.construct_left = 0
						e.max_hp = float(st.get("hp", 100))
						e.hp = e.max_hp
						return true
				elif _try_build(team, type_id, x, y):
					return true
	return false


func _spawn_base(team: int, tx: int, ty: int) -> void:
	var st := _stats_of(team, "command")
	var size := int(st.get("size", 3))
	var x := (tx + size * 0.5) * TILE
	var y := (ty + size * 0.5) * TILE
	var e := _blank(team, "building", "command", x, y)
	e.size = size
	e.radius = size * TILE * 0.45
	e.max_hp = float(st.get("hp", 1000))
	e.hp = e.max_hp
	e.construct_left = 0
	if team == 0:
		_spawn_unit(0, "harvester", x + 70.0, y)


func _spawn_unit(team: int, type_id: String, x: float, y: float) -> void:
	var st := _stats_of(team, type_id)
	var e := _blank(team, "unit", type_id, x, y)
	e.radius = float(st.get("radius", 8))
	e.max_hp = float(st.get("hp", 100))
	e.hp = e.max_hp
	e.order = "harvest" if type_id == "harvester" else "idle"
	e.cargo = 0.0


func _blank(team: int, kind: String, type_id: String, x: float, y: float) -> Dictionary:
	var id := next_id
	next_id += 1
	var e := {
		"id": id,
		"team": team,
		"kind": kind,
		"type": type_id,
		"x": x,
		"y": y,
		"hp": 1.0,
		"max_hp": 1.0,
		"radius": 8.0,
		"size": 1,
		"order": "idle",
		"tx": x,
		"ty": y,
		"target": -1,
		"cooldown": 0,
		"cargo": 0.0,
		"construct_left": 0,
		"prod_type": "",
		"prod_left": 0,
	}
	entities[id] = e
	return e


func _place_crystals(px: int, py: int, ex: int, ey: int) -> void:
	var spots := [
		[px + 5, py + 1],
		[px + 2, py - 6],
		[ex - 5, ey + 2],
		[ex + 1, ey + 6],
		[int((px + ex) / 2), int((py + ey) / 2)],
	]
	for spot in spots:
		var x := (int(spot[0]) + 0.5) * TILE
		var y := (int(spot[1]) + 0.5) * TILE
		crystals.append({"id": next_id, "x": x, "y": y, "amount": 4000.0})
		next_id += 1


func _gen_terrain() -> void:
	terrain.resize(MAP_TILES * MAP_TILES)
	for i in terrain.size():
		terrain[i] = 0
	for _n in 16:
		var cx := rng.randi_range(2, MAP_TILES - 3)
		var cy := rng.randi_range(2, MAP_TILES - 3)
		var rad := rng.randi_range(2, 4)
		for y in range(cy - rad, cy + rad + 1):
			for x in range(cx - rad, cx + rad + 1):
				if _in_map(x, y) and (x - cx) * (x - cx) + (y - cy) * (y - cy) <= rad * rad:
					terrain[y * MAP_TILES + x] = 1
	for _n in 4:
		var cx := rng.randi_range(8, MAP_TILES - 9)
		var cy := rng.randi_range(8, MAP_TILES - 9)
		var rad := rng.randi_range(2, 3)
		for y in range(cy - rad, cy + rad + 1):
			for x in range(cx - rad, cx + rad + 1):
				if _in_map(x, y) and (x - cx) * (x - cx) + (y - cy) * (y - cy) <= rad * rad:
					terrain[y * MAP_TILES + x] = 3


func _clear_pad(tx: int, ty: int, rad: int) -> void:
	for y in range(ty - rad, ty + rad + 4):
		for x in range(tx - rad, tx + rad + 4):
			if _in_map(x, y):
				terrain[y * MAP_TILES + x] = 0


func _footprint_ok(x: float, y: float, size: int) -> bool:
	var tx := int(x / TILE) - int(size / 2)
	var ty := int(y / TILE) - int(size / 2)
	for dy in size:
		for dx in size:
			var gx := tx + dx
			var gy := ty + dy
			if not _in_map(gx, gy):
				return false
			var cell := int(terrain[gy * MAP_TILES + gx])
			if cell == 2 or cell == 3:
				return false
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if str(e.kind) != "building":
			continue
		var dx := float(e.x) - x
		var dy := float(e.y) - y
		var need := (float(e.size) + float(size)) * TILE * 0.5
		if dx * dx + dy * dy < need * need:
			return false
	return true


func _walkable(x: float, y: float) -> bool:
	if x < 8.0 or y < 8.0 or x > MAP_METERS - 8.0 or y > MAP_METERS - 8.0:
		return false
	return _terrain_at(x, y) != 3


func _terrain_at(x: float, y: float) -> int:
	var tx := clampi(int(x / TILE), 0, MAP_TILES - 1)
	var ty := clampi(int(y / TILE), 0, MAP_TILES - 1)
	return int(terrain[ty * MAP_TILES + tx])


func _in_map(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < MAP_TILES and y < MAP_TILES


func _stats_of(team: int, type_id: String) -> Dictionary:
	var fac: Dictionary = factions[team]
	if fac["buildings"].has(type_id):
		return fac["buildings"][type_id]
	if fac["units"].has(type_id):
		return fac["units"][type_id]
	return {}


func _sorted_ids() -> Array:
	var ids: Array = entities.keys()
	ids.sort()
	return ids


func _owned(team: int, id: int) -> bool:
	return entities.has(id) and int(entities[id].team) == team and float(entities[id].hp) > 0.0


func _living(id: int) -> Dictionary:
	if id < 0 or not entities.has(id):
		return {}
	var e: Dictionary = entities[id]
	if float(e.hp) <= 0.0:
		return {}
	return e


func _first(team: int, type_id: String) -> Dictionary:
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if int(e.team) == team and str(e.type) == type_id and float(e.hp) > 0.0 and int(e.construct_left) == 0:
			return e
	return {}


func _count(team: int, type_id: String) -> int:
	var n := 0
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if int(e.team) == team and str(e.type) == type_id and float(e.hp) > 0.0:
			n += 1
	return n


func _count_combat(team: int) -> int:
	var n := 0
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if int(e.team) == team and str(e.kind) == "unit" and str(e.type) != "harvester" and float(e.hp) > 0.0:
			n += 1
	return n


func _nearest_enemy(e: Dictionary, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := reach * reach
	for id in _sorted_ids():
		var other: Dictionary = entities[id]
		if int(other.team) == int(e.team) or float(other.hp) <= 0.0:
			continue
		var dx := float(other.x) - float(e.x)
		var dy := float(other.y) - float(e.y)
		var d := dx * dx + dy * dy
		if d <= best_d:
			best_d = d
			best = other
	return best


func _nearest_drop(team: int, e: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1.0e18
	for id in _sorted_ids():
		var b: Dictionary = entities[id]
		if int(b.team) != team or str(b.kind) != "building" or float(b.hp) <= 0.0:
			continue
		if str(b.type) != "command" and str(b.type) != "refinery":
			continue
		if int(b.construct_left) > 0:
			continue
		var d := _dist(e, b)
		if d < best_d:
			best_d = d
			best = b
	return best


func _nearest_crystal(e: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1.0e18
	for c in crystals:
		if float(c.amount) <= 1.0:
			continue
		var dx := float(c.x) - float(e.x)
		var dy := float(c.y) - float(e.y)
		var d := dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best = c
	return best


func _dist(a: Dictionary, b: Dictionary) -> float:
	return _dist_xy(a, float(b.x), float(b.y))


func _dist_xy(a: Dictionary, x: float, y: float) -> float:
	var dx := float(a.x) - x
	var dy := float(a.y) - y
	return sqrt(dx * dx + dy * dy)


func _remove_dead() -> void:
	var dead: Array = []
	for id in _sorted_ids():
		if float(entities[id].hp) <= 0.0:
			dead.append(id)
	for id in dead:
		entities.erase(id)


func _check_victory() -> void:
	var player_cc := false
	var enemy_cc := false
	for id in _sorted_ids():
		var e: Dictionary = entities[id]
		if str(e.type) == "command" and float(e.hp) > 0.0:
			if int(e.team) == 0:
				player_cc = true
			else:
				enemy_cc = true
	if not player_cc:
		winner = 1
	elif not enemy_cc:
		winner = 0
