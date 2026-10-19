#!/usr/bin/env python3
"""Sign packs/smoke_test.pck with Ed25519.

The private key is read from RIFT_PACK_SIGNING_KEY (hex or PEM). It is never
written into the repo. If the variable is unset, this script only checks that
the committed TEST manifest still matches packs/smoke_test.pck.

DevOps rotation:
  1. Generate an Ed25519 key locally. Do not commit it.
  2. Store the raw hex or PEM as the GitHub Actions secret RIFT_PACK_SIGNING_KEY.
  3. Put the raw public key hex into scripts/security/pack_config.gd (KEY_ID can leave TEST
     for the smoke pack, or change both together).
  4. Run this script and commit the manifest plus the public key only.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from cryptography.hazmat.primitives import serialization

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "packs" / "smoke_test.pck"
MANIFEST = ROOT / "packs" / "smoke_test.manifest.json"
CONFIG = ROOT / "scripts" / "security" / "pack_config.gd"


def canonical(manifest: dict) -> bytes:
    payload = {
        "filename": manifest["filename"],
        "pack_id": manifest["pack_id"],
        "sha256": manifest["sha256"],
        "version": int(manifest["version"]),
    }
    return json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")


def public_from_config() -> bytes:
    for line in CONFIG.read_text(encoding="utf-8").splitlines():
        if "PUBLIC_KEY_HEX" in line and '"' in line:
            return bytes.fromhex(line.split('"')[1])
    raise SystemExit("public key missing from pack_config.gd")


def load_private(raw: str) -> Ed25519PrivateKey:
    text = raw.strip()
    if "BEGIN" in text:
        return serialization.load_pem_private_key(text.encode(), password=None)
    return Ed25519PrivateKey.from_private_bytes(bytes.fromhex(text))


def main() -> None:
    if not PACK.exists():
        raise SystemExit(f"missing {PACK}")
    digest = hashlib.sha256(PACK.read_bytes()).hexdigest()
    body = {
        "filename": "smoke_test.pck",
        "pack_id": "rift_smoke",
        "sha256": digest,
        "version": 1,
    }
    secret = os.environ.get("RIFT_PACK_SIGNING_KEY", "").strip()
    if not secret:
        if not MANIFEST.exists():
            raise SystemExit("no manifest and RIFT_PACK_SIGNING_KEY is unset")
        wrapped = json.loads(MANIFEST.read_text(encoding="utf-8"))
        if wrapped["manifest"]["sha256"] != digest:
            raise SystemExit("committed manifest hash does not match the pack")
        pub = Ed25519PublicKey.from_public_bytes(public_from_config())
        pub.verify(__import__("base64").b64decode(wrapped["signature"]), canonical(wrapped["manifest"]))
        print("TEST manifest still matches the pack and embedded public key")
        return
    key = load_private(secret)
    pub = key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    embedded = public_from_config()
    if pub != embedded:
        raise SystemExit(
            "secret public key does not match pack_config.gd.\n"
            f"secret public hex: {pub.hex()}\n"
            "Update the embedded TEST/public key in a reviewable commit. Do not commit the secret."
        )
    signature = key.sign(canonical(body))
    wrapped = {
        "key_id": "TEST",
        "alg": "ed25519",
        "manifest": body,
        "signature": __import__("base64").b64encode(signature).decode("ascii"),
    }
    MANIFEST.write_text(json.dumps(wrapped, indent=2) + "\n", encoding="utf-8")
    print(f"signed {MANIFEST}")


if __name__ == "__main__":
    main()
