extends SceneTree

func _init() -> void:
	var out_path := ProjectSettings.globalize_path("res://packs/smoke_test.pck")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://packs"))
	var packer := PCKPacker.new()
	var err := packer.pck_start(out_path)
	if err != OK:
		print("pck_start ", err)
		quit(1)
		return
	err = packer.add_file("res://packs/smoke/note.txt", ProjectSettings.globalize_path("res://tests/fixtures/note.txt"))
	if err != OK:
		print("add ", err)
		quit(1)
		return
	err = packer.flush()
	if err != OK:
		print("flush ", err)
		quit(1)
		return
	print("wrote ", out_path)
	quit(0)
