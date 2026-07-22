#!/usr/bin/env bash
# bump-version.sh — Stamp both Info.plists with a monotonic build number (the run number)
# so every TestFlight upload is unique, and capture a short changelog.

set -euo pipefail

BUILD_NUMBER=""
NOTES_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-number) BUILD_NUMBER="$2"; shift 2 ;;
    --notes-out)    NOTES_OUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "ERROR: --build-number is required." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACOS_PLIST="$ROOT/MacApp/Resources/Info.plist"
IOS_PLIST="$ROOT/iOSApp/Resources/Info.plist"

# Update CFBundleVersion in both Info.plists
for plist in "$MACOS_PLIST" "$IOS_PLIST"; do
  if [[ -f "$plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$plist"
    echo "Updated $plist CFBundleVersion -> $BUILD_NUMBER"
  else
    echo "WARNING: $plist not found" >&2
  fi
done

# Generate release notes
if [[ -n "$NOTES_OUT" ]]; then
  cat > "$NOTES_OUT" <<EOF
GuitarTuner Build $BUILD_NUMBER

- Precision guitar tuner with real-time pitch detection
- Multiple tuning presets: Standard, Drop D, Drop C, Open G, Open D, DADGAD, Half Step Down
- Visual tuning meter with cents accuracy
- Microphone-based pitch detection using autocorrelation
- Calibration adjustment (A4 = 415-466 Hz)

Built on $(date -u +"%Y-%m-%d %H:%M UTC")
EOF
  echo "Release notes written to $NOTES_OUT"
fi