#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64

bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"
binary="${bin_dir}/ADB2WiFi"
app="dist/ADB2WiFi.app"

rm -rf "${app}"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"
cp "${binary}" "${app}/Contents/MacOS/ADB2WiFi"
cp Resources/Info.plist "${app}/Contents/Info.plist"
chmod +x "${app}/Contents/MacOS/ADB2WiFi"

echo "Packaged ${app}"
