extends RefCounted

static func run() -> String:
	var db := FactionDB.load_all()
	var levels := ContentDB.load_levels()
	var level: Dictionary = ContentDB.level_by_id(levels, 1)
	var a := SimWorld.new()
	var b := SimWorld.new()
	a.setup(level, db, "demir_pence")
	b.setup(level, db, "demir_pence")
	for _i in 40:
		a.step()
		b.step()
	if a.hash_state() != b.hash_state():
		return "sim diverged"
	var snap := a.snapshot()
	var c := SimWorld.new()
	c.restore(snap, db, level)
	if c.hash_state() != a.hash_state():
		return "restore mismatch"
	for _i in 20:
		a.step()
		c.step()
	if a.hash_state() != c.hash_state():
		return "restore diverged"
	var enemy := -1
	for e in a.entity_list():
		if int(e.team) == 1 and str(e.type) == "command":
			enemy = int(e.id)
			e.hp = 0
	if enemy < 0:
		return "no enemy command"
	a.step()
	if a.winner != 0:
		return "win condition failed"
	var built := SimWorld.new()
	built.setup(level, db, "kok")
	var before := int(built.resources[0])
	built.enqueue({"op": "build", "team": 0, "type": "barracks", "x": 700.0, "y": 1500.0})
	built.step()
	if int(built.resources[0]) >= before:
		return "build did not spend resources"
	var start_res := 520
	var farm := SimWorld.new()
	farm.setup(level, db, "demir_pence")
	for _i in 700:
		farm.step()
	if int(farm.resources[0]) <= start_res:
		return "harvester did not deliver, resources=%d" % int(farm.resources[0])
	return ""
