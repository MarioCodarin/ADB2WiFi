#!/usr/bin/env bash
# Swift Testing support for a Command Line Tools-only toolchain.
#
# CLT SwiftPM knows how to link Testing.framework but does not load the Testing macro
# plugin. Xcode toolchains handle this automatically; when CLT is active we load the
# plugin explicitly. This wrapper also applies the toolset that supplies the -F paths.
set -euo pipefail
cd "$(dirname "$0")/.."

args=(--toolset Scripts/clt-testing.toolset.json)
developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ "${developer_dir}" == *CommandLineTools* ]]; then
  plugin="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
  if [[ -f "${plugin}" ]]; then
    args+=(-Xswiftc -load-plugin-library -Xswiftc "${plugin}")
  else
    echo "warning: Testing macro plugin not found at ${plugin}" >&2
  fi
fi

exec swift test "${args[@]}" "$@"
