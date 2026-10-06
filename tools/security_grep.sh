#!/usr/bin/env bash
# Fails if the Windows uninstall launcher is not exactly one call site,
# or if forbidden process APIs appear in game code.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCAN=(scripts scenes addons android/plugin/src)
count="$(grep -R --include='*.gd' --include='*.tscn' --include='*.java' --include='*.kt' -o 'create_process' "${SCAN[@]}" | wc -l | tr -d ' ')"
if [[ "$count" != "1" ]]; then
  echo "create_process count is ${count}, expected 1"
  grep -R -n 'create_process' "${SCAN[@]}" || true
  exit 1
fi
if grep -R -n -E 'OS\.execute|shell_open|execute_with_pipe' "${SCAN[@]}"; then
  echo "forbidden process API in game code"
  exit 1
fi
if grep -R -n -E 'BEGIN (OPENSSH |RSA |EC )?PRIVATE KEY' scripts addons android/plugin/src packs data tests installer tools .github 2>/dev/null; then
  echo "private key material in the tree"
  exit 1
fi
if git ls-files | grep -Ei '(^|/)[^/]*\.(keystore|jks)$'; then
  echo "keystore must not be committed"
  exit 1
fi
echo "security grep ok"
