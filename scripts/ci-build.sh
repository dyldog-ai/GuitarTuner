#!/usr/bin/env bash
# ci-build.sh — build + archive a GuitarTuner scheme for CI.
#
# Used by .github/workflows/ci-build.yml on a macOS GitHub runner. It generates
# the Xcode project from Tuist, archives the requested scheme,
# and (when signing is enabled) exports a TestFlight-ready .ipa (iOS) / .pkg (macOS)
# using the matching export-options plist.
#
# Usage:
#   ci-build.sh --scheme SCHEME --destination DEST --config CONFIG \
#               --export-method METHOD --signing yes|no [--team TEAM_ID]
set -euo pipefail

SCHEME=""
DESTINATION=""
CONFIG="Release"
EXPORT_METHOD="app-store"
SIGNING="no"
TEAM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)        SCHEME="$2"; shift 2 ;;
    --destination)   DESTINATION="$2"; shift 2 ;;
    --config)        CONFIG="$2"; shift 2 ;;
    --export-method) EXPORT_METHOD="$2"; shift 2 ;;
    --signing)       SIGNING="$2"; shift 2 ;;
    --team)          TEAM="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SCHEME" || -z "$DESTINATION" ]]; then
  echo "ERROR: --scheme and --destination are required." >&2
  exit 2
fi

PLATFORM_LOWER=$(echo "$SCHEME" | tr '[:upper:]' '[:lower:]')
# Derive a stable artifact/platform label: "GuitarTuner-iOS" -> "ios", "GuitarTuner" -> "macos"
case "$SCHEME" in
  *-iOS) PLATFORM="ios" ;;
  *)     PLATFORM="macos" ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build/logs
LOG="$ROOT/build/logs/$SCHEME.log"

echo "==> Tuist: generate GuitarTuner.xcodeproj"
tuist generate 2>&1 | tee -a "$LOG"

ARCHIVE_PATH="build/$SCHEME.xcarchive"
EXPORT_PATH="build/export/$PLATFORM"

if [[ "$SIGNING" == "yes" ]]; then
  if [[ -z "$TEAM" ]]; then
    echo "ERROR: --signing yes requires --team (APPLE_TEAM_ID)." >&2
    exit 2
  fi
  SIGN_FLAGS=(
    CODE_SIGN_STYLE=Automatic
    DEVELOPMENT_TEAM="$TEAM"
    CODE_SIGNING_ALLOWED=YES
    CODE_SIGNING_REQUIRED=YES
    -allowProvisioningUpdates
  )
  # Archiving requires a signed product, which is only possible when signing
  # secrets are present.
  echo "==> xcodebuild: archive scheme $SCHEME ($CONFIG, $DESTINATION)"
  xcodebuild archive \
    -project GuitarTuner.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE_PATH" \
    "${SIGN_FLAGS[@]}" 2>&1 | tee -a "$LOG"
  echo "==> Archive produced: $ARCHIVE_PATH"
else
  echo "::warning::Building UNSIGNED — using 'xcodebuild build' (archiving needs a signed product). Not TestFlight-ready."
  SIGN_FLAGS=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
  )
  BUILD_DIR="$ROOT/build"
  echo "==> xcodebuild: build scheme $SCHEME ($CONFIG, $DESTINATION)"
  xcodebuild build \
    -project GuitarTuner.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "$DESTINATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/$PLATFORM" \
    "${SIGN_FLAGS[@]}" 2>&1 | tee -a "$LOG"
  # Synthesize an .xcarchive-shaped bundle so the upload artifact step resolves.
  echo "==> Producing unsigned .xcarchive bundle for artifact upload"
  mkdir -p "$ARCHIVE_PATH/Products/Applications"
  cp -R "$BUILD_DIR/$PLATFORM/"*.app "$ARCHIVE_PATH/Products/Applications/"
  echo "==> Unsigned product produced at: $ARCHIVE_PATH/Products/Applications"
  ls -la "$ARCHIVE_PATH/Products/Applications"
fi

if [[ "$SIGNING" == "yes" ]]; then
  EXPORT_PLIST="scripts/export-options-$PLATFORM.plist"
  if [[ ! -f "$EXPORT_PLIST" ]]; then
    echo "ERROR: export options plist not found: $EXPORT_PLIST" >&2
    exit 2
  fi
  echo "==> xcodebuild: export $PLATFORM ($EXPORT_METHOD)"
  rm -rf "$EXPORT_PATH"
  mkdir -p "$EXPORT_PATH"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates
  echo "==> Exported app artifacts:"
  find "$EXPORT_PATH" -maxdepth 2 -type f
fi

echo "Build & archive complete for $SCHEME."