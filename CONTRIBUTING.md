# Contributing

Thanks for taking a look. ADB2WiFi is a small, dependency-free Swift package, and
the core is designed to be tested without a phone or AppKit.

## Setup

- macOS 14+
- Swift 6 toolchain (Xcode or Command Line Tools)
- `adb` on the Mac for manual testing (not needed for unit tests)

```sh
swift build
bash Scripts/test.sh
bash Scripts/install.sh
```

Use `bash Scripts/test.sh` when the active developer directory is Command Line
Tools only. CLT does not load the Testing macro plugin automatically; the script
does. With Xcode, `swift test` works too.

## What goes where

- **`Sources/ADB2WiFiCore`** must stay UI-free. Foundation and `os` only.
- **`Sources/ADB2WiFi`** is the AppKit/SwiftUI shell. Keep state mutations in
  `ConnectionCoordinator`, not in views.
- **`Tests/`** uses Swift Testing. Add a test for every parser, state transition,
  and failure mapping you change.

## Style

- Swift 6 language mode; prefer `let`, value types, and explicit `Sendable`.
- Keep functions small. Pure helpers (`Endpoint`, `TransportMerger`, parsers) are
  preferred over view-embedded logic.
- UI copy: short, active, and specific. "Allow USB debugging on your phone, then
  try again" beats "Error: unauthorized".
- No third-party dependencies without a discussion first. The app should stay
  auditable and small.

## Privacy rules

This is a public repository. Do not commit:

- Real device serial numbers, USB IDs, or IP addresses.
- API keys, tokens, `.env` files, or personal paths.
- Screenshots with a real phone, account, or network name.

Fixture devices use clearly synthetic serials (`TEST00000001`) and documentation
IP ranges (`192.0.2.x`, `198.51.100.x`, `203.0.113.x`).

Logs must interpolate serials, endpoints, paths, and error payloads as
`privacy: .private`. Diagnostics must go through `Diagnostics.summary`, which
redacts the home directory and never includes device identifiers.

## UI screenshots

The app has a debug-only fixture mode:

```sh
swift build
ADB2WIFI_FIXTURES=showcase ADB2WIFI_SHOW_POPOVER=1 .build/debug/ADB2WiFi
ADB2WIFI_SNAPSHOT=/tmp/adb2wifi.png .build/debug/ADB2WiFi
```

`ADB2WIFI_FIXTURES=1` shows the full state catalog; `showcase` shows the
three-card README set. These paths compile only under `#if DEBUG`.

## Pull requests

- Keep the diff focused; one problem per PR.
- Add or update tests.
- Run `bash Scripts/test.sh` and `bash Scripts/package-app.sh`.
- Note any user-visible change in `CHANGELOG.md`.
- Include a screenshot for UI changes, ideally with fixtures.

By contributing, you agree your work is licensed under the MIT License.
