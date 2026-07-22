#!/usr/bin/env bash
# build.sh — Local build verification helper for GuitarTuner (macOS).
# Generates the Xcode project from Tuist and builds both the macOS and iOS app targets.
# The apps share a single codebase (Shared/) so there's nothing to resolve with SwiftPM.

set -euo pipefail

if ! command -v tuist &> /dev/null; then
  echo "!! tuist not found. Install with: curl -Ls https://install.tuist.io | bash" >&2
  exit 1
fi

echo "==> Tuist: generate project"
cd "$(dirname "$0")/.."
tuist generate

echo "==> xcodebuild: build macOS app scheme (Release)"
xcodebuild -project GuitarTuner.xcodeproj \
  -scheme GuitarTuner \
  -configuration Release \
  build

echo "==> xcodebuild: build iOS app scheme (Debug, simulator)"
xcodebuild -project GuitarTuner.xcodeproj \
  -scheme GuitarTuner-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build

echo "All build steps completed."