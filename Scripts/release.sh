#!/usr/bin/env bash
# Builds a universal app and zips it for a GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."

bash Scripts/package-app.sh --universal
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/ADB2WiFi.app/Contents/Info.plist)"
zip="dist/ADB2WiFi-${version}.zip"
rm -f "${zip}"
ditto -c -k --keepParent "dist/ADB2WiFi.app" "${zip}"
echo "Created ${zip}"
shasum -a 256 "${zip}"
