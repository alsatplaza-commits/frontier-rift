#!/usr/bin/env bash
# Player-facing text must not name the underlying engine.
# The license notice is the legal exception and is not scanned.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

files=()
if [[ -f README.md ]]; then files+=(README.md); fi
if [[ -f OYNA.md ]]; then files+=(OYNA.md); fi

roots=()
for dir in installer scenes scripts/ui scripts/match scripts/platform data locale translations; do
  if [[ -d "$dir" ]]; then
    roots+=("$dir")
  fi
done
if [[ ${#roots[@]} -gt 0 ]]; then
  while IFS= read -r -d '' path; do
    base="$(basename "$path")"
    case "$base" in
      THIRD_PARTY_LICENSES|THIRD_PARTY_LICENSES.txt|LICENSES|LICENSES.txt|LICENSES.md)
        continue
        ;;
    esac
    files+=("$path")
  done < <(find "${roots[@]}" -type f -print0)
fi

while IFS= read -r -d '' path; do
  files+=("$path")
done < <(find . -type f \( -name '*.po' -o -name '*.csv' -o -name '*.translation' \) \
  -not -path './.git/*' -not -path './.godot/*' -not -path './build/*' -print0 2>/dev/null || true)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "brand scan found no files"
  exit 1
fi

if grep -I -n -i 'godot' "${files[@]}"; then
  echo "player-facing text contains a forbidden engine name"
  exit 1
fi
echo "brand text ok"
