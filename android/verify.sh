#!/usr/bin/env bash
# Build gate for the Android client. Runs the native debug build and fails
# (non-zero exit) on any error. ANDROID_HOME is expected to be set; JDK 17 is
# required (Android Studio's bundled JBR works).
set -euo pipefail

cd "$(dirname "$0")"

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ERROR: ANDROID_HOME (or ANDROID_SDK_ROOT) is not set." >&2
  exit 1
fi

# Ensure the SDK location is discoverable by the Android Gradle Plugin. If
# local.properties is absent (e.g. a fresh clone), derive it from the env.
if [[ ! -f local.properties ]]; then
  echo "sdk.dir=${ANDROID_HOME:-$ANDROID_SDK_ROOT}" > local.properties
fi

echo "==> Building Android debug APK (./gradlew assembleDebug)"
./gradlew --no-daemon :app:assembleDebug

echo "==> Android build OK"
