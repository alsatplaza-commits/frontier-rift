class_name PackVerifier
extends RefCounted

# Data files only. The signed manifest is JSON, so it is included here.
const ALLOWED_EXT := [
	".ctex", ".png", ".webp", ".oggvorbisstr", ".ogg", ".import", ".json",
]


static func canonical_manifest(manifest: Dictionary) -> PackedByteArray:
	var filename := str(manifest.get("filename", ""))
	var pack_id := str(manifest.get("pack_id", ""))
	var sha := str(manifest.get("sha256", "")).to_lower()
	var version := int(manifest.get("version", 0))
	var text := '{"filename":"%s","pack_id":"%s","sha256":"%s","version":%d}' % [filename, pack_id, sha, version]
	return text.to_utf8_buffer()


static func verify_signature(manifest: Dictionary, signature_b64: String) -> bool:
	var sig := Marshalls.base64_to_raw(signature_b64.strip_edges())
	if sig.size() != 64:
		return false
	return Ed25519.verify(PackConfig.public_key_bytes(), sig, canonical_manifest(manifest))


static func sha256_bytes(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


static func sha256_file(path: String) -> String:
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


static func verify_pack_file(path: String, manifest: Dictionary, signature_b64: String) -> Dictionary:
	if str(manifest.get("filename", "")) != PackConfig.EXPECTED_FILENAME:
		return _bad("Paket adı reddedildi.")
	if not verify_signature(manifest, signature_b64):
		return _bad("İmza geçersiz.")
	var actual := sha256_file(path)
	var expected := str(manifest.get("sha256", "")).to_lower()
	if actual.is_empty() or actual != expected:
		return _bad("Paket özeti uyuşmuyor.")
	var scan := scan_pck(path)
	if not scan.ok:
		return scan
	return {"ok": true, "reason": ""}


static func scan_pck(path: String) -> Dictionary:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		return _bad("Paket okunamadı.")
	var parsed := _parse_pck(data)
	if not parsed.ok:
		return _bad(str(parsed.reason))
	for entry in parsed.files:
		var reason := _reject_entry(entry)
		if reason != "":
			return _bad(reason)
	return {"ok": true, "reason": ""}


static func _reject_entry(entry: Dictionary) -> String:
	var path := str(entry.path).replace("\\", "/").to_lower()
	if path.contains("..") or path.begins_with("/") or path.contains(":/"):
		return "Paket yolu reddedildi."
	var flags := int(entry.flags)
	if (flags & 1) != 0 or (flags & 4) != 0:
		return "Şifreli paket reddedildi."
	if not _extension_allowed(path):
		return "Paket dosya türü reddedildi."
	return ""


static func _extension_allowed(path: String) -> bool:
	var base := path.get_file()
	if base == "smoke_test.manifest.json" or base.ends_with(".manifest.json"):
		return true
	for ext in ALLOWED_EXT:
		if path.ends_with(ext):
			return true
	return false


static func _parse_pck(data: PackedByteArray) -> Dictionary:
	if data.size() < 120:
		return {"ok": false, "reason": "Paket çok küçük.", "files": []}
	var magic := _u32(data, 0)
	if magic != 0x43504447:
		return {"ok": false, "reason": "Paket başlığı geçersiz.", "files": []}
	var version := _u32(data, 4)
	var flags := _u32(data, 20)
	if (flags & 1) != 0:
		return {"ok": false, "reason": "Şifreli paket reddedildi.", "files": []}
	var file_base := _u64(data, 24)
	var dir_off := 0
	if version == 3 or version == 4:
		dir_off = _u64(data, 32)
	elif version == 2:
		dir_off = 24 + 8 + 16 * 4
		if (flags & 2) == 0:
			file_base = _u64(data, 24)
	else:
		return {"ok": false, "reason": "Paket sürümü desteklenmiyor.", "files": []}
	if dir_off <= 0 or dir_off + 4 > data.size():
		return {"ok": false, "reason": "Paket dizini bozuk.", "files": []}
	var count := _u32(data, dir_off)
	var cursor := dir_off + 4
	var files: Array = []
	for _i in count:
		if cursor + 4 > data.size():
			return {"ok": false, "reason": "Paket dizini bozuk.", "files": []}
		var sl := _u32(data, cursor)
		cursor += 4
		if sl > 4096 or cursor + sl + 8 + 8 + 16 + 4 > data.size():
			return {"ok": false, "reason": "Paket dizini bozuk.", "files": []}
		var raw := data.slice(cursor, cursor + sl)
		cursor += sl
		var path := raw.get_string_from_utf8().replace("\u0000", "")
		var ofs := _u64(data, cursor)
		cursor += 8
		var size := _u64(data, cursor)
		cursor += 8
		cursor += 16
		var entry_flags := _u32(data, cursor)
		cursor += 4
		if size > PackConfig.MAX_PACK_BYTES:
			return {"ok": false, "reason": "Paket dosyası çok büyük.", "files": []}
		var abs_off := file_base + ofs
		var bytes := PackedByteArray()
		if (entry_flags & 2) == 0:
			if abs_off < 0 or abs_off + size > data.size():
				return {"ok": false, "reason": "Paket dosya aralığı bozuk.", "files": []}
			bytes = data.slice(abs_off, abs_off + size)
		files.append({"path": path, "flags": entry_flags, "bytes": bytes, "size": size})
	return {"ok": true, "reason": "", "files": files}


static func _bad(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _u32(data: PackedByteArray, pos: int) -> int:
	return int(data[pos]) | (int(data[pos + 1]) << 8) | (int(data[pos + 2]) << 16) | (int(data[pos + 3]) << 24)


static func _u64(data: PackedByteArray, pos: int) -> int:
	var lo := _u32(data, pos)
	var hi := _u32(data, pos + 4)
	return lo + (hi << 32)
