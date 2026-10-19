class_name PackDownload
extends Node

## Created only after the player presses the pack button. No traffic before that.

signal finished(ok: bool, message: String)

var _step := 0
var _manifest: Dictionary = {}
var _signature := ""
var _http: HTTPRequest


func start() -> void:
	_step = 0
	_fetch(PackConfig.MANIFEST_URL)


func _fetch(url: String) -> void:
	if not PackConfig.is_allowed_url(url):
		_fail("Adres reddedildi.")
		return
	_http = HTTPRequest.new()
	_http.timeout = 20
	add_child(_http)
	_http.request_completed.connect(_on_done)
	var err := _http.request(url)
	if err != OK:
		_fail("İndirme başlamadı. Oyun paketsiz de oynanır.")


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http:
		_http.queue_free()
		_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("İndirme başarısız. İnternet yoksa da oyun oynanır.")
		return
	if body.size() > PackConfig.MAX_PACK_BYTES:
		_fail("Paket çok büyük.")
		return
	if _step == 0:
		_take_manifest(body)
	else:
		_take_pack(body)


func _take_manifest(body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Manifest okunamadı.")
		return
	if str(parsed.get("key_id", "")) != PackConfig.KEY_ID or str(parsed.get("alg", "")) != "ed25519":
		_fail("Manifest anahtarı reddedildi.")
		return
	_manifest = parsed.get("manifest", {})
	_signature = str(parsed.get("signature", ""))
	if typeof(_manifest) != TYPE_DICTIONARY or not Ed25519.verify(PackConfig.public_key_bytes(), Marshalls.base64_to_raw(_signature.strip_edges()), PackVerifier.canonical_manifest(_manifest)):
		_fail("İmza geçersiz.")
		return
	_step = 1
	_fetch(PackConfig.PACK_URL)


func _take_pack(body: PackedByteArray) -> void:
	var expected := str(_manifest.get("sha256", "")).to_lower()
	if PackVerifier.sha256_bytes(body) != expected:
		_fail("Paket özeti uyuşmuyor.")
		return
	var dir := "user://packs"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(PackConfig.EXPECTED_FILENAME)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("Paket kaydedilemedi.")
		return
	f.store_buffer(body)
	f.close()
	var checked := PackVerifier.verify_pack_file(path, _manifest, _signature)
	if not checked.ok:
		DirAccess.remove_absolute(path)
		_fail(str(checked.reason))
		return
	if not ProjectSettings.load_resource_pack(path, false):
		_fail("Paket yüklenemedi.")
		return
	var note := ""
	if FileAccess.file_exists("res://packs/smoke/note.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://packs/smoke/note.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			note = str(parsed.get("note", "")).strip_edges()
	finished.emit(true, note if note != "" else "Test paketi yüklendi.")
	queue_free()


func _fail(message: String) -> void:
	finished.emit(false, message)
	queue_free()
