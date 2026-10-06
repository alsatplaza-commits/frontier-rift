#!/usr/bin/env bash
# Inspect an exported APK: INTERNET only, Windows uninstall code absent from assets,
# and the no-argument uninstall plugin present.
set -euo pipefail
APK="${1:?apk path}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
AAPT="$(find "$SDK" -type f -name aapt -perm -111 2>/dev/null | sort | tail -n 1)"
if [[ -z "$AAPT" ]]; then
  echo "aapt not found under ANDROID_SDK_ROOT"
  exit 1
fi
mapfile -t PERMS < <("$AAPT" dump permissions "$APK" | sed -n "s/.*name='\\([^']*\\)'.*/\\1/p" | sort -u)
printf 'permissions:\n'
printf '  %s\n' "${PERMS[@]:-}"
if [[ "${#PERMS[@]}" -ne 1 || "${PERMS[0]}" != "android.permission.INTERNET" ]]; then
  echo "APK permissions must be exactly android.permission.INTERNET"
  exit 1
fi
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
unzip -q "$APK" -d "$WORKDIR"
# Engine libraries expose the same method names. Game assets must not.
if grep -R -a -F "create_process" "$WORKDIR/assets" ; then
  echo "create_process leaked into APK assets"
  exit 1
fi
if grep -R -a -F "unins000" "$WORKDIR/assets" ; then
  echo "Windows uninstaller name leaked into APK assets"
  exit 1
fi
if grep -R -a -E "shell_open|execute_with_pipe|OS\\.execute" "$WORKDIR/assets"; then
  echo "forbidden process API leaked into APK assets"
  exit 1
fi
# Class names in the binary manifest are UTF-16. Dex stores them with slashes.
if ! "$AAPT" dump xmltree "$APK" AndroidManifest.xml | grep -F "com.frontierrift.uninstall.RiftUninstallPlugin" >/dev/null; then
  echo "uninstall plugin class missing from the manifest"
  exit 1
fi
if ! "$AAPT" dump xmltree "$APK" AndroidManifest.xml | grep -F "org.godotengine.plugin.v2.RiftUninstall" >/dev/null; then
  echo "uninstall plugin metadata missing from the manifest"
  exit 1
fi
if ! grep -R -a -F "openOwnAppSettings" "$WORKDIR" >/dev/null; then
  echo "uninstall plugin method missing from APK"
  exit 1
fi
echo "apk security ok"
