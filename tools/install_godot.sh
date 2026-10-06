#!/usr/bin/env bash
# Install the official Godot 4.7.2 editor and export templates. No secrets.
set -euo pipefail
VERSION="4.7.2-stable"
ROOT="${RUNNER_TEMP:-/tmp}/godot-install"
mkdir -p "$HOME/godot" "$HOME/.local/share/godot/export_templates" "$ROOT"
if [[ ! -x "$HOME/godot/Godot_v${VERSION}_linux.x86_64" ]]; then
  if [[ ! -f "$ROOT/godot.zip" ]]; then
    curl -fsSL -o "$ROOT/godot.zip" "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
  fi
  unzip -qo "$ROOT/godot.zip" -d "$HOME/godot"
  chmod +x "$HOME/godot/Godot_v${VERSION}_linux.x86_64"
fi
if [[ ! -f "$HOME/.local/share/godot/export_templates/4.7.2.stable/linux_release.x86_64" ]]; then
  if [[ ! -f "$ROOT/templates.tpz" ]]; then
    curl -fsSL -o "$ROOT/templates.tpz" "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
  fi
  rm -rf /tmp/godot-tpl
  mkdir -p /tmp/godot-tpl
  unzip -qo "$ROOT/templates.tpz" -d /tmp/godot-tpl
  rm -rf "$HOME/.local/share/godot/export_templates/4.7.2.stable"
  mv /tmp/godot-tpl/templates "$HOME/.local/share/godot/export_templates/4.7.2.stable"
fi
test -x "$HOME/godot/Godot_v${VERSION}_linux.x86_64"
test -f "$HOME/.local/share/godot/export_templates/4.7.2.stable/windows_release_x86_64.exe"
test -f "$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip"
