extends RefCounted

static func run() -> String:
	var sha_empty := Ed25519.sha512(PackedByteArray()).hex_encode()
	if sha_empty != "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e":
		return "sha512 empty"
	var pub := "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a".hex_decode()
	var sig := "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b".hex_decode()
	if not Ed25519.verify(pub, sig, PackedByteArray()):
		return "rfc vector rejected"
	sig[0] = int(sig[0]) ^ 1
	if Ed25519.verify(pub, sig, PackedByteArray()):
		return "bad rfc signature accepted"
	var pack_path := "res://packs/smoke_test.pck"
	var manifest_path := "res://packs/smoke_test.manifest.json"
	if not FileAccess.file_exists(pack_path):
		return "smoke pack missing"
	var wrapped = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(wrapped) != TYPE_DICTIONARY:
		return "manifest"
	var manifest: Dictionary = wrapped["manifest"]
	var signature := str(wrapped["signature"])
	var good := PackVerifier.verify_pack_file(pack_path, manifest, signature)
	if not good.ok:
		return "good pack rejected: " + str(good.reason)
	# Flip the signature text so verification fails without touching the pack.
	var flipped := signature
	var chars := flipped.to_ascii_buffer()
	if chars.size() > 4:
		chars[3] = chars[3] ^ 1
		flipped = chars.get_string_from_ascii()
	var bad := PackVerifier.verify_pack_file(pack_path, manifest, flipped)
	if bad.ok:
		return "bad signature accepted"
	var tampered := manifest.duplicate(true)
	tampered["sha256"] = "00"
	# Signature is over the original manifest, so a hash mismatch is reported after a failed signature
	# when the signed bytes changed. Check the file hash path with a copied pack and the original manifest.
	var copy_path := "user://packs/tampered.pck"
	DirAccess.make_dir_recursive_absolute("user://packs")
	var raw := FileAccess.get_file_as_bytes(pack_path)
	raw[raw.size() - 1] = int(raw[raw.size() - 1]) ^ 0x5A
	var out := FileAccess.open(copy_path, FileAccess.WRITE)
	out.store_buffer(raw)
	out.close()
	var bad_hash := PackVerifier.verify_pack_file(copy_path, manifest, signature)
	if bad_hash.ok or not str(bad_hash.reason).contains("özeti"):
		return "bad hash accepted: " + str(bad_hash.reason)
	var evil := "user://packs/evil.pck"
	var err := _write_pck(evil, "res://evil.gd", "extends Node\n".to_utf8_buffer())
	if err != "":
		return err
	var scan := PackVerifier.scan_pck(evil)
	if scan.ok:
		return "script pack accepted"
	var scene := "user://packs/scene.pck"
	var tscn := "[gd_scene]\n[ext_resource type=\"Script\" path=\"res://evil.gd\" id=\"1\"]\n".to_utf8_buffer()
	err = _write_pck(scene, "res://bad.tscn", tscn)
	if err != "":
		return err
	var scan_scene := PackVerifier.scan_pck(scene)
	if scan_scene.ok:
		return "script scene pack accepted"
	if FileAccess.file_exists("res://packs/smoke/note.txt"):
		return "note leaked before load"
	if not ProjectSettings.load_resource_pack(pack_path, false):
		return "load_resource_pack failed"
	if not FileAccess.file_exists("res://packs/smoke/note.txt"):
		return "note missing after load"
	return ""


static func _write_pck(path: String, target: String, data: PackedByteArray) -> String:
	var packer := PCKPacker.new()
	var err := packer.pck_start(ProjectSettings.globalize_path(path))
	if err != OK:
		return "pck_start %s" % err
	err = packer.add_file_from_buffer(target, data)
	if err != OK:
		return "add_file %s" % err
	err = packer.flush()
	if err != OK:
		return "flush %s" % err
	return ""
