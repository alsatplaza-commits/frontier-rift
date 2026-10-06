#!/usr/bin/env python3
"""Fail if the Android export preset asks for anything beyond INTERNET."""
from pathlib import Path
import sys

text = Path("export_presets.cfg").read_text(encoding="utf-8")
chunks = text.split("[preset.")
blocks = []
current = None
for part in chunks[1:]:
    block = "[preset." + part
    header = block.split("]", 1)[0]
    if ".options" in header:
        if current is not None:
            current += block
    else:
        if current is not None:
            blocks.append(current)
        current = block
if current is not None:
    blocks.append(current)

android = ""
for block in blocks:
    if 'name="Android"' in block:
        android = block
        break
if not android:
    sys.exit("Android preset missing")


def value(key: str) -> str:
    needle = key + "="
    for line in android.splitlines():
        if line.startswith(needle):
            return line.split("=", 1)[1].strip()
    return ""


errors = []
if value("permissions/internet") not in ("true", "True"):
    errors.append("permissions/internet must be true")
if "PackedStringArray()" not in value("permissions/custom_permissions"):
    errors.append("custom_permissions must be empty")
for line in android.splitlines():
    if line.startswith("permissions/") and line.split("=", 1)[1].strip() in ("true", "True"):
        if not line.startswith("permissions/internet="):
            errors.append("extra permission enabled: " + line)
if value("architectures/arm64-v8a") not in ("true", "True"):
    errors.append("arm64-v8a must be enabled")
for abi in ("armeabi-v7a", "x86", "x86_64"):
    if value(f"architectures/{abi}") not in ("false", "False"):
        errors.append(f"{abi} must be disabled")
exclude = value("exclude_filter").strip('"')
if "platform/windows" not in exclude:
    errors.append("Android export must exclude scripts/platform/windows")
if value("package/unique_name").strip('"') != "com.frontierrift.game":
    errors.append("unexpected package name")
if value("keystore/debug").strip('"') or value("keystore/release").strip('"'):
    errors.append("keystore path must stay empty in the repo")
if value("gradle_build/use_gradle_build") not in ("true", "True"):
    errors.append("gradle build required for the uninstall plugin")
if "android_mobile" not in value("custom_features"):
    errors.append("android_mobile feature tag missing")
if errors:
    print("\n".join(errors))
    sys.exit(1)
print("android preset ok")
