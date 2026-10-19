#!/usr/bin/env bash
# Stamp Frontier Rift version resources onto the exported executable.
# The export already fills these fields when modify_resources is on.
# rcedit runs afterward so a template string cannot remain.
set -euo pipefail
EXE="${1:-build/windows/FrontierRift.exe}"
if [[ -z "${RCEDIT:-}" || ! -f "$RCEDIT" ]]; then
  echo "RCEDIT must point at rcedit-x64.exe"
  exit 1
fi
if [[ ! -f "$EXE" ]]; then
  echo "missing $EXE"
  exit 1
fi
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-rcedit}"
export WINEDEBUG=-all
xvfb-run -a wine "$RCEDIT" "$(realpath "$EXE")" \
  --set-file-version "0.1.0.0" \
  --set-product-version "0.1.0.0" \
  --set-version-string ProductName "Frontier Rift" \
  --set-version-string FileDescription "Frontier Rift" \
  --set-version-string CompanyName "alsatplaza-commits" \
  --set-version-string LegalCopyright "(c) 2026 Frontier Rift" \
  --set-version-string FileVersion "0.1.0.0" \
  --set-version-string ProductVersion "0.1.0.0" \
  --set-version-string InternalName "FrontierRift" \
  --set-version-string OriginalFilename "FrontierRift.exe" \
  --set-version-string LegalTrademarks "Frontier Rift" \
  --set-version-string Comments "Frontier Rift"
echo "version resources applied to $EXE"
