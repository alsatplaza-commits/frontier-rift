#!/usr/bin/env python3
"""Fail if a Windows version-info block contains 'godot' or an empty field."""
from __future__ import annotations

import sys
from pathlib import Path

import pefile

REQUIRED = {
    "ProductName": "Frontier Rift",
    "FileDescription": "Frontier Rift",
    "CompanyName": "alsatplaza-commits",
    "LegalCopyright": "(c) 2026 Frontier Rift",
    "FileVersion": "0.1.0.0",
    "ProductVersion": "0.1.0.0",
}


def _text(value: bytes | str) -> str:
    if isinstance(value, bytes):
        value = value.decode("utf-8", "replace")
    return value.replace("\x00", "").strip()


def string_fields(path: Path) -> dict[str, str]:
    pe = pefile.PE(str(path))
    found: dict[str, str] = {}
    if not hasattr(pe, "FileInfo"):
        raise SystemExit(f"{path}: no version resource")
    for fileinfo in pe.FileInfo:
        for entry in fileinfo:
            tables = getattr(entry, "StringTable", None)
            if not tables:
                continue
            for table in tables:
                for key, value in table.entries.items():
                    found[_text(key)] = _text(value)
    if not found:
        raise SystemExit(f"{path}: version resource has no string fields")
    return found


def check_pack_section(path: Path) -> None:
    pe = pefile.PE(str(path))
    data = path.read_bytes()
    for section in pe.sections:
        name = section.Name.rstrip(b"\x00")
        if name != b"pck":
            continue
        start = section.PointerToRawData
        magic = data[start : start + 4]
        if magic != b"GDPC":
            raise SystemExit(f"{path}: pack section is not intact after version edit")
        return
    raise SystemExit(f"{path}: embedded pack section missing")


def check(path: Path, require_pack: bool) -> None:
    fields = string_fields(path)
    print(f"{path}:")
    for key in sorted(fields):
        print(f"  {key}={fields[key]}")
    for key, value in fields.items():
        if value == "":
            raise SystemExit(f"{path}: version field {key} is empty")
        if "godot" in value.lower():
            raise SystemExit(f"{path}: version field {key} contains a forbidden engine name")
    for key, expected in REQUIRED.items():
        actual = fields.get(key, "")
        if actual != expected:
            raise SystemExit(f"{path}: {key} is {actual!r}, expected {expected!r}")
    if require_pack:
        check_pack_section(path)


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("usage: check_version_info.py <exe> [installer]")
    game = Path(sys.argv[1])
    check(game, require_pack=True)
    for extra in sys.argv[2:]:
        check(Path(extra), require_pack=False)
    print("version resources ok")


if __name__ == "__main__":
    main()
