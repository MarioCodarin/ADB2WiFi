#!/usr/bin/env bash
# Builds a release .app bundle into dist/.
#
#   bash Scripts/package-app.sh              # arm64 (fast, local)
#   bash Scripts/package-app.sh --universal  # arm64 + x86_64 (GitHub release)
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the cross-compiled slice at the package minimum, not the host SDK version.
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

arch_flags=(--arch arm64)
if [[ "${1:-}" == "--universal" ]]; then
  arch_flags=(--arch arm64 --arch x86_64)
fi

swift build -c release "${arch_flags[@]}"

bin_dir="$(swift build -c release "${arch_flags[@]}" --show-bin-path)"
binary="${bin_dir}/ADB2WiFi"
app="dist/ADB2WiFi.app"

if [[ ! -f "${binary}" ]]; then
  echo "error: missing release binary ${binary}" >&2
  exit 1
fi
if [[ ! -f Resources/AppIcon.icns ]]; then
  echo "error: missing Resources/AppIcon.icns" >&2
  exit 1
fi

rm -rf "${app}"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"
cp "${binary}" "${app}/Contents/MacOS/ADB2WiFi"
strip -x "${app}/Contents/MacOS/ADB2WiFi"
cp Resources/Info.plist "${app}/Contents/Info.plist"
cp Resources/AppIcon.icns "${app}/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "${app}/Contents/PkgInfo"
chmod +x "${app}/Contents/MacOS/ADB2WiFi"

# Ad-hoc signature keeps the app stable across launches; it is not notarized.
codesign --force --sign - "${app}" >/dev/null 2>&1

lsuielement="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "${app}/Contents/Info.plist")"
if [[ "${lsuielement}" != "true" ]]; then
  echo "error: LSUIElement must be true so the app has no Dock icon" >&2
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app}/Contents/Info.plist")"
echo "Packaged ${app} (${version})"
lipo -info "${app}/Contents/MacOS/ADB2WiFi" 2>/dev/null || true
