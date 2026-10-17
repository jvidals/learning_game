#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
adb_bin="${ADB_BIN:-adb}"
apk_path="${APK_PATH:-artifacts/learning-corner.apk}"
if [[ ! -f "$apk_path" ]]; then
  printf 'Build first: ./tools/build_apk.sh\n' >&2
  exit 1
fi
# Pass a serial to choose a device. Otherwise adb requires one connected device.
device_args=()
if [[ $# -gt 0 ]]; then device_args=(-s "$1"); fi
"$adb_bin" "${device_args[@]}" install -r "$apk_path"
"$adb_bin" "${device_args[@]}" shell am start -n com.rainbowgarden.rainbow_garden/.MainActivity
