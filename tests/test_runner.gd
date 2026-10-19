extends SceneTree

func _init() -> void:
	var failures: Array = []
	var scripts := [
		"res://tests/test_factions.gd",
		"res://tests/test_sim.gd",
		"res://tests/test_save.gd",
		"res://tests/test_uninstall.gd",
		"res://tests/test_pack.gd",
		"res://tests/test_offline.gd",
	]
	for path in scripts:
		var result: String = load(path).run()
		if result != "":
			failures.append(path + ": " + result)
			print("FAIL ", path, " ", result)
		else:
			print("OK ", path)
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("FAILED ", failures.size())
		quit(1)
