extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var scripts := [
		"res://tests/test_factions.gd",
		"res://tests/test_sim.gd",
		"res://tests/test_save.gd",
		"res://tests/test_uninstall.gd",
		"res://tests/test_pack.gd",
		"res://tests/test_offline.gd",
		"res://tests/test_roam.gd",
	]
	for path in scripts:
		var result: String = load(path).run()
		if result != "":
			failures.append(path + ": " + result)
			print("FAIL ", path, " ", result)
		else:
			print("OK ", path)
	var play = load("res://tests/test_roam_play.gd").new()
	var play_result = await play.run(self)
	if typeof(play_result) != TYPE_STRING or play_result != "":
		failures.append("res://tests/test_roam_play.gd: " + str(play_result))
		print("FAIL play ", play_result)
	else:
		print("OK play")
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("FAILED ", failures.size())
		quit(1)
