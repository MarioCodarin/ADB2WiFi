#!/usr/bin/env bash
# CLT SwiftPM does not pass -F for Testing.framework to the synthesized test runner.
# This wrapper applies the toolset so `import Testing` and test execution both work.
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift test --toolset Scripts/clt-testing.toolset.json "$@"
