class_name UninstallRouter
extends RefCounted

## Feature tag keeps the Windows launcher out of the Android call path.
## That script is also excluded from the Android export.


static func request(tree: SceneTree) -> String:
	if OS.has_feature("android") or OS.has_feature("android_mobile"):
		return AndroidUninstall.open_own_settings()
	if OS.has_feature("windows") or OS.has_feature("windows_desktop"):
		return _windows(tree)
	return "Bu sistemde kaldırma, cihaz ayarlarından yapılır."


static func _windows(tree: SceneTree) -> String:
	if not (OS.has_feature("windows") or OS.has_feature("windows_desktop")):
		return "Bu sistemde kaldırma, cihaz ayarlarından yapılır."
	var path := "res://scripts/platform/windows/uninstall_launch.gd"
	if not ResourceLoader.exists(path):
		return "Kaldırma dosyası doğrulanamadı. Windows Ayarlar > Uygulamalar bölümünden kaldırın."
	var script = load(path)
	return script.launch_verified_and_quit(tree, OS.get_executable_path())
