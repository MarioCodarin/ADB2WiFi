#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64

bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"
binary="${bin_dir}/ADB2WiFi"
app="dist/ADB2WiFi.app"

if [[ ! -f "${binary}" ]]; then
  echo "error: missing release binary ${binary}" >&2
  exit 1
fi

rm -rf "${app}"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"
cp "${binary}" "${app}/Contents/MacOS/ADB2WiFi"
strip -x "${app}/Contents/MacOS/ADB2WiFi"
cp Resources/Info.plist "${app}/Contents/Info.plist"
printf 'APPL????' > "${app}/Contents/PkgInfo"
chmod +x "${app}/Contents/MacOS/ADB2WiFi"

lsuielement="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "${app}/Contents/Info.plist")"
if [[ "${lsuielement}" != "true" ]]; then
  echo "error: LSUIElement must be true so the app has no Dock icon" >&2
  exit 1
fi

echo "Packaged ${app}"
