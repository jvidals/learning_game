#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_bin="${FLUTTER_BIN:-flutter}"
profile=false
case "${1:-}" in
  '') ;;
  --profile-companion) profile=true ;;
  *) printf 'Usage: %s [--profile-companion]\n' "$0" >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then printf 'Too many arguments\n' >&2; exit 2; fi
python3 tools/generate_audio.py --verify
python3 tools/export_foal.py --verify
"$flutter_bin" pub get
if $profile; then
  "$flutter_bin" build apk --release --target=tools/profile_companion.dart
  python3 tools/verify_apk_assets.py build/app/outputs/flutter-apk/app-release.apk --profiling-candidate
  destination=artifacts/companion-profile.apk
else
  "$flutter_bin" build apk --release
  python3 tools/verify_apk_assets.py build/app/outputs/flutter-apk/app-release.apk
  destination=artifacts/learning-corner.apk
fi
mkdir -p artifacts
cp build/app/outputs/flutter-apk/app-release.apk "$destination.tmp"
mv "$destination.tmp" "$destination"
sha256sum "$destination" > "$destination.sha256"
printf 'APK ready: %s/%s\n' "$PWD" "$destination"
