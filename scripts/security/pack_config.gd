class_name PackConfig
extends RefCounted

## TEST public key only. The private key is not in this repository.
## DevOps replaces KEY_ID / PUBLIC_KEY_HEX and re-signs packs with tools/sign_pack.py
## using the GitHub secret RIFT_PACK_SIGNING_KEY. Never commit a private key.

const KEY_ID := "TEST"
const PUBLIC_KEY_HEX := "d319e5f84e69c07c01088a8fbadec0718aa19fe0775727d9ca6072aa229c9981"
const HOST := "raw.githubusercontent.com"
const PACK_URL := "https://raw.githubusercontent.com/alsatplaza-commits/frontier-rift/main/packs/smoke_test.pck"
const MANIFEST_URL := "https://raw.githubusercontent.com/alsatplaza-commits/frontier-rift/main/packs/smoke_test.manifest.json"
const EXPECTED_FILENAME := "smoke_test.pck"
const MAX_PACK_BYTES := 2000000


static func public_key_bytes() -> PackedByteArray:
	return PUBLIC_KEY_HEX.hex_decode()


static func is_allowed_url(url: String) -> bool:
	if not url.begins_with("https://"):
		return false
	if url.contains("@") or url.contains("\\") or url.contains(" "):
		return false
	var rest := url.substr(8)
	var host := rest.split("/")[0]
	if host.find(":") != -1:
		return false
	return host == HOST and (url == PACK_URL or url == MANIFEST_URL)
