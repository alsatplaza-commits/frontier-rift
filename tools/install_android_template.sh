#!/usr/bin/env bash
# Unpack the official Godot Android gradle template into the project.
# The template is not committed. Godot checks android/.build_version before export.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="${1:-$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip}"
if [[ ! -f "$ZIP" ]]; then
  echo "android source template missing: $ZIP"
  exit 1
fi
rm -rf "$ROOT/android/build"
mkdir -p "$ROOT/android/build"
unzip -q "$ZIP" -d "$ROOT/android/build"
printf '%s\n' '4.7.2.stable' > "$ROOT/android/.build_version"
touch "$ROOT/android/build/.gdignore"
test -f "$ROOT/android/build/build.gradle"
echo "android build template installed"
