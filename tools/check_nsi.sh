#!/usr/bin/env bash
# Fail if an installer script can start a shell or an external process.
# "RequestExecutionLevel" contains the letters Exec and must stay allowed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pattern='powershell|_hash\.ps1|ExecutionPolicy|cmd\.exe|ExecWait|nsExec|(^|[^A-Za-z])Exec([^A-Za-z]|$)'

if echo 'RequestExecutionLevel user' | grep -E -i -q "$pattern"; then
  echo "nsi grep false-positive on RequestExecutionLevel"
  exit 1
fi
if ! echo 'nsExec::ExecToLog powershell.exe' | grep -E -i -q "$pattern"; then
  echo "nsi grep missed a shell invocation"
  exit 1
fi

shopt -s nullglob
files=(installer/*.nsi)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no installer scripts"
  exit 1
fi
if grep -n -E -i "$pattern" "${files[@]}"; then
  echo "installer script starts a shell or external process"
  exit 1
fi
echo "installer scripts ok"
