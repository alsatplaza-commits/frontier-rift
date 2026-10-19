#!/usr/bin/env bash
# Two-pass per-user installer. The hash is computed while building.
# The installer copies uninstall.sha256 into place and does not run a shell.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p build/installer
rm -f build/installer/unins000-prebuilt.exe build/installer/unins000-pass1.exe build/installer/uninstall.sha256

makensis installer/frontier_rift.nsi
test -f build/installer/unins000-prebuilt.exe
sha256sum build/installer/unins000-prebuilt.exe | awk '{print $1}' > build/installer/uninstall.sha256
cp build/installer/unins000-prebuilt.exe build/installer/unins000-pass1.exe

makensis -DEMBED_HASH installer/frontier_rift.nsi
test -f build/installer/unins000-prebuilt.exe
test -f build/installer/FrontierRift-Setup.exe

pass1="$(sha256sum build/installer/unins000-pass1.exe | awk '{print $1}')"
pass2="$(sha256sum build/installer/unins000-prebuilt.exe | awk '{print $1}')"
embedded="$(tr -d '[:space:]' < build/installer/uninstall.sha256)"
if [[ "$pass1" != "$pass2" || "$pass1" != "$embedded" ]]; then
  echo "uninstaller hash mismatch"
  echo "pass1=$pass1"
  echo "pass2=$pass2"
  echo "embedded=$embedded"
  exit 1
fi
rm -f build/installer/unins000-pass1.exe build/installer/unins000-prebuilt.exe
echo "installer uninstaller hash matches $embedded"
