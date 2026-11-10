#!/usr/bin/env bash
# Builds and installs ADB2WiFi into /Applications, then launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

bash Scripts/package-app.sh "$@"

target="/Applications/ADB2WiFi.app"
if [[ -d "${target}" ]]; then
  echo "Replacing ${target}"
  pkill -f "${target}/Contents/MacOS/ADB2WiFi" 2>/dev/null || true
  rm -rf "${target}"
fi
ditto "dist/ADB2WiFi.app" "${target}"
xattr -dr com.apple.quarantine "${target}" 2>/dev/null || true
open "${target}"

echo "Installed ${target}"
echo "Look for the ADB2WiFi icon in the menu bar."
