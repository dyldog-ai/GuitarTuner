#!/usr/bin/env bash
# testflight-upload.sh — Upload built artifacts to TestFlight via App Store Connect API.
#
# Usage:
#   testflight-upload.sh --platform ios|macos --notes-file NOTES_FILE
#
# Requires env vars:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64

set -euo pipefail

PLATFORM=""
NOTES_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --notes-file) NOTES_FILE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PLATFORM" || -z "$NOTES_FILE" ]]; then
  echo "ERROR: --platform and --notes-file are required." >&2
  exit 2
fi

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_P8_BASE64:-}" ]]; then
  echo "::warning::App Store Connect API key secrets are not configured — skipping TestFlight upload."
  echo "Add ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64 to enable automatic uploads."
  exit 0
fi

EXPORT_DIR="build/export/$PLATFORM"
if [[ ! -d "$EXPORT_DIR" ]]; then
  echo "ERROR: Export directory not found: $EXPORT_DIR" >&2
  exit 1
fi

# Decode the P8 key
KEY_PATH="/tmp/authkey_${ASC_KEY_ID}.p8"
echo "$ASC_KEY_P8_BASE64" | base64 --decode > "$KEY_PATH"
chmod 600 "$KEY_PATH"

# Build JWT token (valid for 20 minutes)
HEADER='{"alg":"ES256","kid":"'"$ASC_KEY_ID"'"}'
CLAIM='{"iss":"'"$ASC_ISSUER_ID"'","iat":'"$(date +%s)"',"exp":'"$(($(date +%s) + 1200))"',"aud":"appstoreconnect-v1"}'
B64_HEADER=$(echo -n "$HEADER" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
B64_CLAIM=$(echo -n "$CLAIM" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
SIGNATURE=$(printf "%s.%s" "$B64_HEADER" "$B64_CLAIM" | openssl dgst -sha256 -sign "$KEY_PATH" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
JWT="${B64_HEADER}.${B64_CLAIM}.${SIGNATURE}"

# Find the artifact to upload
if [[ "$PLATFORM" == "ios" ]]; then
  ARTIFACT=$(find "$EXPORT_DIR" -name "*.ipa" | head -1)
else
  ARTIFACT=$(find "$EXPORT_DIR" -name "*.pkg" | head -1)
fi

if [[ -z "$ARTIFACT" ]]; then
  echo "ERROR: No artifact found in $EXPORT_DIR" >&2
  exit 1
fi

echo "Uploading $ARTIFACT to TestFlight..."

# Upload using altool (or xcrun notarytool for macOS)
if [[ "$PLATFORM" == "ios" ]]; then
  xcrun altool --upload-app \
    --type ios \
    --file "$ARTIFACT" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
    --apiKeyPath "$KEY_PATH" \
    --verbose
else
  # For macOS, use notarytool + altool or transporter
  xcrun altool --upload-app \
    --type macos \
    --file "$ARTIFACT" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
    --apiKeyPath "$KEY_PATH" \
    --verbose
fi

echo "Upload complete!"