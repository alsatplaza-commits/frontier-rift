extends RefCounted

## Windows-only. Android export excludes this file.
## The uninstaller path is fixed. No arguments, no environment, no player input.

const UNINSTALLER_NAME := "unins000.exe"
const HASH_NAME := "uninstall.sha256"
const FAIL := "Kaldırma dosyası doğrulanamadı. Windows Ayarlar > Uygulamalar bölümünden kaldırın."


static func verify(exe_path: String) -> Dictionary:
	var dir := exe_path.get_base_dir()
	var uninstaller := dir.path_join(UNINSTALLER_NAME)
	var hash_path := dir.path_join(HASH_NAME)
	if not FileAccess.file_exists(uninstaller) or not FileAccess.file_exists(hash_path):
		return {"ok": false, "message": FAIL, "path": uninstaller}
	var expected := FileAccess.get_file_as_string(hash_path).strip_edges().to_lower().split(" ")[0].strip_edges()
	var actual := _sha256_file(uninstaller)
	if expected.is_empty() or actual != expected:
		return {"ok": false, "message": FAIL, "path": uninstaller}
	return {"ok": true, "message": "", "path": uninstaller}


static func launch_verified_and_quit(tree: SceneTree, exe_path: String) -> String:
	var result := verify(exe_path)
	if not result.ok:
		return str(result.message)
	OS.create_process(str(result.path), [])
	tree.quit()
	return ""


static func _sha256_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while not f.eof_reached():
		var chunk := f.get_buffer(65536)
		if chunk.is_empty():
			break
		ctx.update(chunk)
	f.close()
	return ctx.finish().hex_encode()
