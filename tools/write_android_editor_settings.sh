#!/usr/bin/env bash
# Point a fresh Godot editor at the CI Android SDK and a just-generated debug keystore.
set -euo pipefail
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
JAVA="${JAVA_HOME:-}"
KEYSTORE="${1:-${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}}"
if [[ -z "$SDK" || -z "$JAVA" || -z "$KEYSTORE" ]]; then
  echo "ANDROID_SDK_ROOT, JAVA_HOME, and a keystore path are required"
  exit 1
fi
if [[ ! -f "$KEYSTORE" ]]; then
  echo "keystore missing: $KEYSTORE"
  exit 1
fi
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.7.tres" << EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
echo "wrote $HOME/.config/godot/editor_settings-4.7.tres"
