extends RefCounted

static func run() -> String:
	var db := FactionDB.load_all()
	if db.size() != 3:
		return "expected 3 factions, got %d" % db.size()
	var expect := {
		"demir_pence": "#C45C26",
		"ruzgar": "#4AA3F0",
		"kok": "#5B8C5A",
	}
	var counters := {
		"demir_pence": "ruzgar",
		"ruzgar": "kok",
		"kok": "demir_pence",
	}
	for id in expect.keys():
		if not db.has(id):
			return "missing " + id
		var fac: Dictionary = db[id]
		if str(fac["color"]).to_upper() != str(expect[id]).to_upper():
			return id + " color"
		var c: Array = fac["counters"]
		if c.size() != 1 or str(c[0]) != str(counters[id]):
			return id + " counter"
		for kind in ["command", "refinery", "barracks", "turret"]:
			if not fac["buildings"].has(kind):
				return id + " missing building " + kind
		for kind in ["harvester", "infantry", "heavy"]:
			if not fac["units"].has(kind):
				return id + " missing unit " + kind
	var sim_text := FileAccess.get_file_as_string("res://scripts/sim/sim_world.gd")
	for id in expect.keys():
		if sim_text.contains(id):
			return "faction id is hard-coded in sim"
	return ""
