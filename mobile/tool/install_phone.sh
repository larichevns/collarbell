#!/bin/sh
# Builds the app for a real Android phone and installs it over USB.
#
# By default the app talks to the Collarbell server (deploy/README.md). To try it against the API on this Mac
# instead, pass the Mac's address in the home network, e.g. http://192.168.0.166:5080, and start the API in
# phone mode first:
#   dotnet run --project backend/src/Collarbell.AppHost --launch-profile phone
# The phone needs "USB debugging" on (Settings → Developer options) and a data cable to the Mac.
#
# Usage: sh mobile/tool/install_phone.sh [API address]
set -eu
cd "$(dirname "$0")/.."

API="${1:-https://collarbell.example.com}"

# adb from PATH, else from the Android SDK that Flutter uses.
ADB="${ADB:-$(command -v adb || true)}"
if [ -z "$ADB" ]; then
  SDK="${ANDROID_HOME:-$(flutter config --list 2>/dev/null | sed -n 's/^ *android-sdk: *//p')}"
  ADB="$SDK/platform-tools/adb"
fi
if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "No phone over USB: connect it with a data cable and allow USB debugging on its screen." >&2
  exit 1
fi

echo "Building for $API ..."
# Release mode signs in with Firebase. Only arm64: every current Android phone, and a third of the build time.
flutter build apk --release --target-platform android-arm64 \
  --dart-define=CB_API_BASE_URL="$API" \
  --dart-define=CB_AUTH_MODE=firebase

# -r keeps the app's data: the user stays signed in.
"$ADB" install -r build/app/outputs/flutter-apk/app-release.apk

# Gradle and the Kotlin compiler keep gigabytes after a build; give them back to the Mac.
(cd android && ./gradlew --stop >/dev/null 2>&1) || true
pkill -f KotlinCompileDaemon || true
echo "Installed. Open Collarbell on the phone."
