extends RefCounted

static func run() -> String:
	var files: Array = []
	_walk("res://scripts", files)
	_walk("res://scenes", files)
	_walk("res://addons", files)
	var http_ok := "res://scripts/security/pack_download.gd"
	var url_ok := "res://scripts/security/pack_config.gd"
	var once_name := "create_" + "process"
	var banned := ["OS." + "execute", "shell_" + "open", "execute_" + "with_pipe"]
	var once := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("HTTPRequest") and path != http_ok:
			return "unexpected HTTPRequest in " + path
		if text.contains("http://"):
			return "plain http in " + path
		if text.contains("https://") and path != url_ok:
			return "unexpected url in " + path
		once += text.count(once_name)
		for word in banned:
			if text.contains(word):
				return "banned api in " + path
	if once != 1:
		return "process launch count %d" % once
	if not PackConfig.is_allowed_url(PackConfig.PACK_URL):
		return "pack url not allowed"
	if not PackConfig.is_allowed_url(PackConfig.MANIFEST_URL):
		return "manifest url not allowed"
	if PackConfig.is_allowed_url("https://example.com/pack.pck"):
		return "foreign host allowed"
	if PackConfig.is_allowed_url("http://raw.githubusercontent.com/x"):
		return "http allowed"
	if PackConfig.PACK_URL.split("/")[2] != PackConfig.HOST:
		return "host mismatch"
	return ""


static func _walk(root: String, out: Array) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	for name in dir.get_directories():
		_walk(root.path_join(name), out)
	for name in dir.get_files():
		if str(name).ends_with(".gd") or str(name).ends_with(".tscn") or str(name).ends_with(".java"):
			out.append(root.path_join(name))
