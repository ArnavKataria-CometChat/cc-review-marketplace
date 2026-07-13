#!/usr/bin/env bash
#
# verify.sh — build gate for the iOS marketplace client.
#
# Builds the app for the iOS Simulator WITHOUT code-signing (no provisioning
# profile / developer account required) and exits non-zero on any failure.
# This is the native build gate a CI job runs for this component.
#
set -euo pipefail

cd "$(dirname "$0")"

SCHEME="Marketplace"
PROJECT="Marketplace.xcodeproj"

echo "==> Verifying iOS client: $SCHEME"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild not found. Install Xcode + command line tools." >&2
  exit 1
fi

xcodebuild -version

# Pick an available iOS Simulator runtime/device generically so this works on
# any machine (no hard-coded device name). Fall back to a plain generic dest.
DESTINATION="generic/platform=iOS Simulator"

echo "==> Building (simulator, no code-signing)"
set -x
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build
set +x

echo "==> iOS build succeeded."
