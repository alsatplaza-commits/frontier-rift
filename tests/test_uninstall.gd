extends RefCounted

static func run() -> String:
	var script = load("res://scripts/platform/windows/uninstall_launch.gd")
	var root := "user://uninstall_probe"
	DirAccess.make_dir_recursive_absolute(root)
	var exe := root.path_join("FrontierRift.exe")
	var uninstaller := root.path_join("unins000.exe")
	var hash_path := root.path_join("uninstall.sha256")
	var bytes := PackedByteArray([9, 8, 7, 6, 5, 4])
	var f := FileAccess.open(uninstaller, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var bad := FileAccess.open(hash_path, FileAccess.WRITE)
	bad.store_string("deadbeef")
	bad.close()
	var mismatch: Dictionary = script.verify(exe)
	if bool(mismatch.ok):
		return "mismatch was accepted"
	if not str(mismatch.message).contains("Uygulamalar"):
		return "mismatch message"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	var good := FileAccess.open(hash_path, FileAccess.WRITE)
	good.store_string(ctx.finish().hex_encode())
	good.close()
	var ok: Dictionary = script.verify(exe)
	if not bool(ok.ok):
		return "matching hash was refused"
	DirAccess.remove_absolute(hash_path)
	var missing: Dictionary = script.verify(exe)
	if bool(missing.ok) or not str(missing.message).contains("Uygulamalar"):
		return "missing hash was not refused"
	return ""
