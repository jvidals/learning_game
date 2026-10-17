#!/usr/bin/env bash
# Run flutter or dart without writing outside the workspace (Codex sandbox).
# Usage: tools/sdk_direct.sh flutter <args...> | tools/sdk_direct.sh dart <args...>
# The SDK launcher scripts rewrite bin/cache/engine.stamp on every run, so this
# calls the cached Dart VM and flutter_tools snapshot directly instead.
# FLUTTER_ALREADY_LOCKED skips the SDK cache lockfile (the cache must already be
# populated; Flutter's harmless "failed to update its stamp file" notices about
# libimobiledevice/libusbmuxd are expected). --suppress-analytics avoids
# telemetry writes under ~/.dart-tool.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'Usage: %s flutter|dart <args...>\n' "$0" >&2; exit 2
fi
tool="$1"; shift
flutter_bin="${FLUTTER_BIN:-/home/jvidals/snap/flutter/common/flutter/bin/flutter}"
flutter_root="$(cd "$(dirname "$flutter_bin")/.." && pwd -P)"
dart_vm="$flutter_root/bin/cache/dart-sdk/bin/dart"

case "$tool" in
  flutter)
    FLUTTER_ROOT="$flutter_root" FLUTTER_ALREADY_LOCKED=true exec "$dart_vm" \
      --packages="$flutter_root/packages/flutter_tools/.dart_tool/package_config.json" \
      "$flutter_root/bin/cache/flutter_tools.snapshot" --suppress-analytics "$@" ;;
  dart)
    exec "$dart_vm" --suppress-analytics "$@" ;;
  *)
    printf 'Unknown tool %s; use flutter or dart\n' "$tool" >&2; exit 2 ;;
esac
